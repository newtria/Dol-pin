// Legacy verification never refunds on a database error: a commit may have
// succeeded before its response was lost. Captures that do not reconcile enter
// the audited operator queue instead of triggering an unfenced PG cancellation.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireAuthenticatedUser } from "../_shared/auth.ts";
import { ApiError, providerCall } from "../_shared/errors.ts";
import { errorResponse, jsonResponse, optionsResponse, parseJsonBody } from "../_shared/http.ts";
import { errorDiagnostics } from "../_shared/telemetry.ts";
import { rpc } from "../_shared/rental-finance.ts";
import { extractReservationId, fetchPortOnePayment, getPortOneAccessToken, normalizePortOneStatus, type PortOnePayment } from "../_shared/portone.ts";

type Lookup = (id: string) => Promise<PortOnePayment>;
const lookupPayment: Lookup = async (id) => fetchPortOnePayment(id, await getPortOneAccessToken());
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const capturedStates = new Set(["paid", "picked_up", "returned", "disputed", "cancelled", "settled", "resolved"]);

export function createHandler(lookup: Lookup = lookupPayment) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return optionsResponse();
    if (req.method !== "POST") return jsonResponse(405, {});
    try {
      const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (!url || !key) throw new ApiError("SERVICE_UNAVAILABLE");
      const caller = await requireAuthenticatedUser(req, url, key);
      if (caller instanceof Response) return caller;
      const admin = createClient(url, key, { auth: { persistSession: false } });
      const { data: profile, error: profileError } = await admin.from("users").select("deleted_at").eq("id", caller.id).maybeSingle();
      if (profileError) throw profileError;
      if (!profile || profile.deleted_at) throw new ApiError("FORBIDDEN");
      // Suspended participants may still reconcile a charge already captured.
      // This endpoint cannot initiate a new charge or a refund.
      const body = await parseJsonBody<{ imp_uid?: unknown }>(req);
      if (body instanceof Response) return body;
      if (typeof body.imp_uid !== "string" || !body.imp_uid || body.imp_uid.length > 200) throw new ApiError("INVALID_REQUEST");
      const quota = await rpc<{ allowed: boolean; retryAfter?: number }>(admin, "consume_api_quota", { p_user_id: caller.id, p_feature: "payment-verify" });
      if (!quota.allowed) return jsonResponse(429, { code: "RATE_LIMITED", retryAfter: quota.retryAfter });
      const payment = await providerCall(() => lookup(body.imp_uid as string));
      if (typeof payment.merchant_uid !== "string" || payment.imp_uid !== body.imp_uid ||
        !Number.isSafeInteger(payment.amount) || payment.amount <= 0 || payment.amount > 2147483647 ||
        !Number.isSafeInteger(payment.cancel_amount ?? 0) || (payment.cancel_amount ?? 0) < 0 || (payment.cancel_amount ?? 0) > payment.amount ||
        typeof payment.currency !== "string" || !/^[A-Z]{3}$/.test(payment.currency) ||
        !["paid", "ready", "failed", "cancelled"].includes(payment.status)) throw new ApiError("UPSTREAM_UNAVAILABLE");
      const reservationId = extractReservationId(payment.merchant_uid);
      if (!reservationId || !uuid.test(reservationId)) throw new ApiError("INVALID_REQUEST");
      const readReservation = () => admin.from("reservations")
        .select("id,item_id,borrower_id,lender_id,total_paid,deposit,currency,status,payment_id,payment_provider,payment_attempt_merchant_uid")
        .eq("id", reservationId).maybeSingle();
      const { data: reservation, error } = await readReservation();
      if (error) throw error;
      if (!reservation) throw new ApiError("NOT_FOUND");
      if (![reservation.borrower_id, reservation.lender_id].includes(caller.id)) throw new ApiError("FORBIDDEN");
      const review = async (reason: string) => {
        await rpc(admin, "record_legacy_payment_review", {
          p_reservation_id: reservationId, p_actor: caller.id, p_payment_id: payment.imp_uid, p_amount: payment.amount,
          p_refunded: payment.cancel_amount ?? 0, p_currency: payment.currency, p_status: payment.status, p_reason: reason,
        });
        return jsonResponse(409, { code: "PAYMENT_REVIEW_REQUIRED", review_required: true });
      };
      if (payment.amount !== reservation.total_paid || payment.currency !== reservation.currency) return await review("amount_currency_mismatch");
      const normalized = normalizePortOneStatus(payment.status);
      let current = reservation;
      if (!current.payment_id && normalized === "success") {
        if (current.status !== "pending") return await review("verification_rejected");
        if (current.payment_attempt_merchant_uid && current.payment_attempt_merchant_uid !== payment.merchant_uid) return await review("different_attempt");
        if ((payment.cancel_amount ?? 0) !== 0) return await review("external_refund");
        const { data: paid, error: paidError } = await admin.rpc("mark_reservation_paid", {
          p_reservation_id: reservationId, p_payment_id: payment.imp_uid, p_provider: "portone",
        });
        // Re-read even after a successful RPC so every success response is based
        // on an allowed authoritative state and the expected cumulative refund.
        const { data: reread, error: readError } = await readReservation();
        if (readError) throw readError;
        if (!reread) throw new ApiError("NOT_FOUND");
        current = reread;
        if (paidError || paid?.ok !== true) {
          console.warn(JSON.stringify({ event: "legacy_payment_commit_recheck", diagnostics: errorDiagnostics(paidError) }));
        }
        if (!current.payment_id) return await review("verification_rejected");
      }
      let roomId: string | null = null;
      if (current.payment_id) {
        if (current.payment_id !== payment.imp_uid || current.payment_provider !== "portone") return await review("different_payment");
        if (!capturedStates.has(current.status)) return await review("verification_rejected");
        let expectedRefund = 0;
        if (current.status === "cancelled") expectedRefund = current.total_paid;
        else if (current.status === "settled") expectedRefund = current.deposit;
        else if (current.status === "resolved") {
          const { data: resolution, error: resolutionError } = await admin.from("reservation_dispute_resolutions")
            .select("refund_amount").eq("reservation_id", reservationId).order("created_at", { ascending: false }).order("id", { ascending: false }).limit(1).maybeSingle();
          if (resolutionError) throw resolutionError;
          if (!resolution) return await review("verification_rejected");
          expectedRefund = resolution.refund_amount;
        }
        const expectedStatus = expectedRefund === current.total_paid ? "cancelled" : "paid";
        if ((payment.cancel_amount ?? 0) !== expectedRefund || payment.status !== expectedStatus) return await review("external_refund");
        await rpc(admin, "resolve_legacy_payment_verification", { p_reservation_id: reservationId, p_payment_id: payment.imp_uid });
        const { data: room, error: roomError } = await admin.rpc("get_or_create_room", {
          user_a: current.borrower_id, user_b: current.lender_id,
          p_item_id: current.item_id, p_reservation_id: reservationId,
        });
        if (roomError) console.error(JSON.stringify({ event: "legacy_payment_chat_unavailable", diagnostics: errorDiagnostics(roomError) }));
        else roomId = room as string;
      }
      const response = jsonResponse(200, {
        reservation_id: reservationId, reservation_status: current.status, room_id: roomId, imp_uid: payment.imp_uid,
        merchant_uid: payment.merchant_uid, status: normalized, amount: payment.amount, currency: payment.currency,
      });
      response.headers.set("Cache-Control", "no-store");
      return response;
    } catch (error) {
      return errorResponse(error);
    }
  };
}
if (import.meta.main) Deno.serve(createHandler());
