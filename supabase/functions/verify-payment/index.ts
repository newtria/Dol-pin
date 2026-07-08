// Supabase Edge Function: verify-payment
//
// Verifies a PortOne (Iamport) charge against our own reservations table so
// the client cannot fabricate a "paid" state. The imp_secret is held only in
// Supabase Function secrets — it must never leave the server.
//
// Required secrets (set via `supabase secrets set ...`):
//   SUPABASE_URL                 — provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY    — provided by the platform
//   PORTONE_IMP_KEY              — PortOne REST API key
//   PORTONE_IMP_SECRET           — PortOne REST API secret (DO NOT expose)
//
// Flow:
//   1. Caller must present a valid Supabase JWT.
//   2. Caller sends `{imp_uid: "<portone-transaction-id>"}`.
//   3. We exchange imp_key+imp_secret for a PortOne access token (cached).
//   4. We GET /payments/{imp_uid} on PortOne and learn the real merchant_uid,
//      amount, status, and currency of the charge.
//   5. We parse the merchant_uid (format: `dolpin_<reservationId>_<epoch>`)
//      to recover the reservation id that originally produced this charge.
//   6. We load the reservation row via the service-role client and verify:
//        - caller is a participant (borrower or lender),
//        - the amount matches `reservations.total_paid` exactly (no tampering),
//        - the payment status is PortOne's `paid`.
//   7. If the reservation is still `pending`, we advance it to `paid`
//      and stamp `payment_provider`, `payment_id`. Idempotent on re-call.
//   8. Return the normalized status + amount to the client.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  jsonResponse,
  optionsResponse,
  parseJsonBody,
} from "../_shared/http.ts";
import {
  extractReservationId,
  fetchPortOnePayment,
  getPortOneAccessToken,
  normalizePortOneStatus,
  portOneCancel,
  type PortOnePayment,
} from "../_shared/portone.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ---------------------------------------------------------------------------
// Request handler
// ---------------------------------------------------------------------------

async function refundCapturedVerificationPayment(
  impUid: string,
  amount: number,
  merchantUid: string,
  reservationStatus: string,
  reason: string,
): Promise<Response> {
  try {
    const token = await getPortOneAccessToken();
    const refunded = await portOneCancel(token, {
      imp_uid: impUid,
      amount,
      reason,
    });
    return jsonResponse(409, {
      error: `${reason}. Captured payment was refunded.`,
      refunded: true,
      imp_uid: impUid,
      merchant_uid: merchantUid,
      cancel_amount: refunded.cancel_amount ?? amount,
      reservation_status: reservationStatus,
    });
  } catch (refundError) {
    console.error("auto-refund failed after verification rejection", {
      refundError,
      impUid,
      merchantUid,
    });
    return jsonResponse(500, {
      error:
        "Payment captured but verification rejected it and auto-refund failed. Contact support.",
      imp_uid: impUid,
      merchant_uid: merchantUid,
      reservation_status: reservationStatus,
    });
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return optionsResponse();
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  const caller = await requireAuthenticatedUser(
    req,
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );
  if (caller instanceof Response) return caller;
  const callerId = caller.id;

  // Parse body.
  const body = await parseJsonBody<{ imp_uid?: unknown }>(req);
  if (body instanceof Response) return body;
  const impUid = body.imp_uid;
  if (typeof impUid !== "string" || impUid.length === 0) {
    return jsonResponse(400, { error: "Missing imp_uid" });
  }

  // Look up payment at PortOne.
  let payment: PortOnePayment;
  try {
    const token = await getPortOneAccessToken();
    payment = await fetchPortOnePayment(impUid, token);
  } catch (e) {
    console.error("PortOne lookup failed", e);
    return jsonResponse(502, { error: "PortOne lookup failed" });
  }

  const reservationId = extractReservationId(payment.merchant_uid);
  if (!reservationId) {
    return jsonResponse(400, { error: "Unknown merchant_uid format" });
  }

  // Load the reservation via the service-role client (RLS-bypassing, trusted).
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: reservation, error: resError } = await adminClient
    .from("reservations")
    .select(
      "id, item_id, borrower_id, lender_id, total_paid, currency, status, payment_id, payment_attempt_merchant_uid",
    )
    .eq("id", reservationId)
    .maybeSingle();

  if (resError || !reservation) {
    return jsonResponse(404, { error: "Reservation not found" });
  }

  const isParticipant = reservation.borrower_id === callerId ||
    reservation.lender_id === callerId;
  if (!isParticipant) {
    return jsonResponse(403, {
      error: "Not a participant of this reservation",
    });
  }

  // Tampering check — the amount PortOne charged must equal what we asked
  // the user to pay when we created the reservation row.
  if (payment.amount !== reservation.total_paid) {
    console.error(
      "Amount mismatch",
      { portone: payment.amount, reservation: reservation.total_paid },
    );
    return jsonResponse(409, { error: "Amount mismatch" });
  }
  if (payment.currency && payment.currency !== reservation.currency) {
    console.error("Currency mismatch", {
      portone: payment.currency,
      reservation: reservation.currency,
    });
    return jsonResponse(409, { error: "Currency mismatch" });
  }

  const normalized = normalizePortOneStatus(payment.status);
  let roomId: string | null = null;

  // Advance the reservation state once, idempotently. This RPC locks the row
  // and refuses a second/different imp_uid for the same reservation.
  if (normalized === "success") {
    if (reservation.payment_id && reservation.payment_id !== impUid) {
      return await refundCapturedVerificationPayment(
        impUid,
        payment.amount,
        payment.merchant_uid,
        reservation.status,
        "Reservation already has a different payment_id",
      );
    }
    if (
      reservation.payment_attempt_merchant_uid &&
      reservation.payment_attempt_merchant_uid !== payment.merchant_uid
    ) {
      return await refundCapturedVerificationPayment(
        impUid,
        payment.amount,
        payment.merchant_uid,
        reservation.status,
        "Merchant UID does not match reservation attempt",
      );
    }

    const { data: paidResult, error: paidError } = await adminClient.rpc(
      "mark_reservation_paid",
      {
        p_reservation_id: reservationId,
        p_payment_id: impUid,
        p_provider: "portone",
      },
    );
    if (paidError || paidResult?.ok !== true) {
      console.error("reservation paid mark failed", { paidError, paidResult });
      return await refundCapturedVerificationPayment(
        impUid,
        payment.amount,
        payment.merchant_uid,
        reservation.status,
        "Reservation was no longer payable when payment verification completed",
      );
    }
  }

  if (normalized === "success") {
    const { data: roomData, error: roomError } = await adminClient.rpc(
      "get_or_create_room",
      {
        user_a: reservation.borrower_id,
        user_b: reservation.lender_id,
        p_item_id: reservation.item_id,
        p_reservation_id: reservation.id,
      },
    );
    if (roomError) {
      console.error("chat room creation failed after payment verification", {
        roomError,
        reservationId: reservation.id,
      });
    } else {
      roomId = roomData as string;
    }
  }

  return jsonResponse(200, {
    reservation_id: reservation.id,
    room_id: roomId,
    imp_uid: impUid,
    merchant_uid: payment.merchant_uid,
    status: normalized,
    amount: payment.amount,
    currency: payment.currency ?? "KRW",
  });
});
