import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ApiError } from "../_shared/errors.ts";
import { errorResponse, jsonResponse, optionsResponse, parseJsonBody } from "../_shared/http.ts";
import { paymentProvider, type ProviderFactory } from "../_shared/payment-provider.ts";
import { reconcileMoney, rpc, verifyPendingPayout } from "../_shared/rental-finance.ts";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function identifier(value: unknown): string {
  if (typeof value !== "string" || !uuid.test(value)) throw new ApiError("INVALID_REQUEST");
  return value;
}
function note(value: unknown, max = 2000): string {
  if (typeof value !== "string" || value.trim().length < 5 || value.trim().length > max) {
    throw new ApiError("INVALID_REQUEST");
  }
  return value.trim();
}

export function createHandler(providers: ProviderFactory = paymentProvider) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return optionsResponse();
    if (req.method !== "POST") return jsonResponse(405, {});
    try {
      const url = Deno.env.get("SUPABASE_URL");
      const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (!url || !key) throw new ApiError("SERVICE_UNAVAILABLE");
      const token = req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
      if (!token) throw new ApiError("AUTH_REQUIRED");
      const admin = createClient(url, key, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { fetch: (input, init) => fetch(input, { ...init, signal: AbortSignal.timeout(10_000) }) },
      });
      // Auth verifies current privileges; user_metadata is never authority.
      const { data: identity, error: identityError } = await admin.auth.getUser(token);
      if (identityError && (!identityError.status || identityError.status >= 500 || identityError.status === 429)) {
        throw new ApiError("SERVICE_UNAVAILABLE", identityError);
      }
      if (identityError || !identity.user) throw new ApiError("AUTH_REQUIRED");
      if (identity.user.app_metadata?.dolpin_operator !== true) throw new ApiError("FORBIDDEN");
      const actor = identity.user.id;
      await rpc(admin, "assert_finance_operator", { p_actor: actor });
      const body = await parseJsonBody<Record<string, unknown>>(req);
      if (body instanceof Response) return body;
      let result: unknown;
      if (body.action === "queue") {
        const offset = body.offset ?? 0;
        if (typeof offset !== "number" || !Number.isSafeInteger(offset) || offset < 0 || offset > 100000) throw new ApiError("INVALID_REQUEST");
        await rpc(admin, "refresh_rental_operator_reviews", {});
        const [payouts, disputes, reviews, recovery] = await Promise.all([
          admin.from("rental_payouts").select("id,reservation_id,lender_id,amount,fee_amount,net_amount,currency,status,claimed_by,claimed_at,paid_at,created_at")
            .neq("status", "paid").order("created_at").order("id").range(offset, offset + 100),
          admin.from("rental_disputes").select("*").is("resolved_at", null).order("created_at").order("id").range(offset, offset + 100),
          admin.from("rental_operator_reviews").select("*").is("closed_at", null).order("created_at").order("id").range(offset, offset + 100),
          admin.from("rental_recovery_queue").select("kind,key,reservation_id,attempt_count,failure_count,next_attempt_at,last_error_code,review_required_at,created_at")
            .order("created_at").order("key").range(offset, offset + 100),
        ]);
        for (const page of [payouts, disputes, reviews, recovery]) if (page.error) throw page.error;
        const ids = [...new Set([...(payouts.data ?? []), ...(disputes.data ?? []), ...(reviews.data ?? []), ...(recovery.data ?? [])]
          .map((row) => row.reservation_id))];
        // Send the bounded ID set as a POST body, not a potentially >8KB URL.
        const rentals = ids.length ? await rpc(admin, "finance_reservation_summaries", { p_ids: ids }) : [];
        result = { payouts: payouts.data?.slice(0, 100), disputes: disputes.data?.slice(0, 100), reviews: reviews.data?.slice(0, 100),
          recovery: recovery.data?.slice(0, 100), reservations: rentals,
          hasMore: [payouts, disputes, reviews, recovery].some((page) => (page.data?.length ?? 0) > 100) };
      } else if (body.action === "rental") {
        const cursor = body.messageBefore;
        let before: string | null = null, beforeId: string | null = null;
        if (cursor !== undefined) {
          if (!cursor || typeof cursor !== "object" || Array.isArray(cursor)) throw new ApiError("INVALID_REQUEST");
          const c = cursor as Record<string, unknown>;
          if (typeof c.createdAt !== "string" || c.createdAt.length > 40 || !Number.isFinite(Date.parse(c.createdAt))) throw new ApiError("INVALID_REQUEST");
          before = c.createdAt;
          beforeId = identifier(c.id);
        }
        result = await rpc(admin, "finance_rental_detail", {
          p_reservation_id: identifier(body.reservationId), p_actor: actor, p_before: before, p_before_id: beforeId,
        });
      } else if (body.action === "claimPayout") {
        const id = identifier(body.id);
        await verifyPendingPayout(admin, id, providers);
        result = await rpc(admin, "claim_rental_payout", { p_id: id, p_actor: actor });
      } else if (body.action === "completePayout") {
        if (typeof body.transferReference !== "string" || body.transferReference.trim().length < 4 || body.transferReference.trim().length > 160) {
          throw new ApiError("INVALID_REQUEST");
        }
        result = await rpc(admin, "finish_rental_payout", {
          p_id: identifier(body.id), p_actor: actor, p_claim_token: identifier(body.claimToken), p_reference: body.transferReference.trim(),
        });
      } else if (body.action === "failPayout") {
        result = await rpc(admin, "fail_rental_payout", {
          p_id: identifier(body.id), p_actor: actor, p_claim_token: identifier(body.claimToken), p_reason: note(body.reason, 1000),
        });
      } else if (body.action === "retryPayout") {
        if (body.verifiedNotSent !== true) throw new ApiError("INVALID_REQUEST");
        if (body.claimedAt !== null && (typeof body.claimedAt !== "string" || body.claimedAt.length > 40 || !Number.isFinite(Date.parse(body.claimedAt)))) throw new ApiError("INVALID_REQUEST");
        // Older clients may retain this action name; it must not bypass the
        // current claim fence or reset a newly reassigned bank transfer.
        await rpc(admin, "reconcile_rental_payout", {
          p_id: identifier(body.id), p_actor: actor, p_claimed_at: body.claimedAt, p_outcome: "not_sent",
          p_reason: note(body.reason, 1000), p_reference: null,
        });
        result = { ok: true };
      } else if (body.action === "reconcilePayout") {
        if (body.outcome !== "paid" && body.outcome !== "not_sent") throw new ApiError("INVALID_REQUEST");
        if (body.claimedAt !== null && (typeof body.claimedAt !== "string" || body.claimedAt.length > 40 || !Number.isFinite(Date.parse(body.claimedAt)))) throw new ApiError("INVALID_REQUEST");
        if (body.outcome === "paid" && (typeof body.transferReference !== "string" || body.transferReference.trim().length < 4 || body.transferReference.trim().length > 160)) throw new ApiError("INVALID_REQUEST");
        result = await rpc(admin, "reconcile_rental_payout", {
          p_id: identifier(body.id), p_actor: actor, p_claimed_at: body.claimedAt, p_outcome: body.outcome,
          p_reason: note(body.reason, 1000), p_reference: body.outcome === "paid" ? String(body.transferReference).trim() : null,
        });
      } else if (body.action === "resolveDispute") {
        if (typeof body.refundAmount !== "number" || !Number.isSafeInteger(body.refundAmount) || body.refundAmount < 0 || body.refundAmount > 2147483647) {
          throw new ApiError("INVALID_REQUEST");
        }
        const op = await rpc<{ id: string; status: string }>(admin, "begin_rental_dispute_resolution", {
          p_reservation_id: identifier(body.reservationId), p_actor: actor, p_refund_amount: body.refundAmount, p_reason: note(body.reason),
        });
        result = op.status === "complete" ? { status: "resolved" } : await reconcileMoney(admin, op.id, providers);
      } else if (body.action === "retryRecovery") {
        if (!["money", "checkout"].includes(String(body.kind)) || typeof body.key !== "string" || body.key.length > 160) {
          throw new ApiError("INVALID_REQUEST");
        }
        if (body.kind === "money") identifier(body.key);
        const changed = await rpc<boolean>(admin, "retry_rental_recovery_as_operator", { p_kind: body.kind, p_key: body.key, p_actor: actor });
        if (!changed) throw new ApiError("STATE_CONFLICT");
        result = { ok: true };
      } else if (body.action === "closeReview") {
        await rpc(admin, "close_rental_operator_review", { p_id: identifier(body.id), p_actor: actor, p_note: note(body.note, 1000) });
        result = { ok: true };
      } else if (body.action === "escalateReview") {
        await rpc(admin, "escalate_rental_operator_review", { p_id: identifier(body.id), p_actor: actor, p_note: note(body.note) });
        result = { ok: true };
      } else if (body.action === "evidenceUrl") {
        if (typeof body.path !== "string" || body.path.length > 500) throw new ApiError("INVALID_REQUEST");
        const reservationId = identifier(body.path.split("/")[0]);
        await rpc(admin, "finance_evidence_access", { p_reservation_id: reservationId, p_actor: actor, p_kind: "dispute", p_path: body.path });
        const { data, error } = await admin.storage.from("dispute-evidence").createSignedUrl(body.path, 300);
        if (error) throw error;
        result = { url: data.signedUrl };
      } else if (body.action === "returnPhotoUrl") {
        const path = await rpc<string>(admin, "finance_evidence_access", {
          p_reservation_id: identifier(body.reservationId), p_actor: actor, p_kind: "return", p_path: null,
        });
        const { data, error } = await admin.storage.from("rental-evidence").createSignedUrl(path, 300);
        if (error) throw error;
        result = { url: data.signedUrl };
      } else {
        throw new ApiError("INVALID_REQUEST");
      }
      const response = jsonResponse(200, result);
      response.headers.set("Cache-Control", "no-store");
      return response;
    } catch (error) {
      return errorResponse(error);
    }
  };
}
if (import.meta.main) Deno.serve(createHandler());
