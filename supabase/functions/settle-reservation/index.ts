// Supabase Edge Function: settle-reservation
//
// returned → settled. Refunds the deposit portion to the borrower via
// a PortOne partial cancel; leaves the rental_fee paid (it accrues to
// the lender's payout balance, settled out-of-band — v1 does not
// implement the lender payout API).
//
// Required secrets (set via `supabase secrets set ...`):
//   SUPABASE_URL                 — provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY    — provided by the platform
//   PORTONE_IMP_KEY              — PortOne REST API key
//   PORTONE_IMP_SECRET           — PortOne REST API secret (DO NOT expose)
//
// Flow:
//   1. Caller JWT must resolve to the lender of the reservation. The
//      borrower CANNOT trigger settlement — only the lender accepts
//      the return condition.
//   2. Caller sends `{reservation_id}`.
//   3. We load the reservation, verify status='returned' and caller=lender.
//   4. We mark the reservation `settle_pending` to block dispute races.
//   5. We call PortOne `/payments/cancel` for the `deposit` amount only.
//   6. We call `transition_reservation_status` RPC to advance returned →
//      settled.
//   7. If the RPC fails after PortOne succeeded, we return 500 with the
//      imp_uid so Ops can reconcile manually (matches the refund-payment
//      divergence handling).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  jsonResponse,
  optionsResponse,
  parseJsonBody,
} from "../_shared/http.ts";
import {
  fetchPortOnePayment,
  getPortOneAccessToken,
  portOneCancel,
  type PortOnePayment,
} from "../_shared/portone.ts";
import {
  beginReservationPaymentAction,
  clearReservationPaymentAction,
  paymentActionIsStale,
  transitionReservationStatus,
} from "../_shared/reservation-actions.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ---------------------------------------------------------------------------
// Request handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return optionsResponse();
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  try {
    const caller = await requireAuthenticatedUser(
      req,
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY,
    );
    if (caller instanceof Response) return caller;
    const callerId = caller.id;

    // Parse body.
    const body = await parseJsonBody<{ reservation_id?: unknown }>(req);
    if (body instanceof Response) return body;
    const reservationId = body.reservation_id;
    if (typeof reservationId !== "string" || reservationId.length === 0) {
      return jsonResponse(400, { error: "Missing reservation_id" });
    }

    // Load reservation via service-role.
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: reservation, error: resError } = await adminClient
      .from("reservations")
      .select(
        "id, borrower_id, lender_id, deposit, total_paid, currency, status, payment_id, payment_action, payment_action_started_at, payment_provider",
      )
      .eq("id", reservationId)
      .maybeSingle();

    if (resError || !reservation) {
      return jsonResponse(404, { error: "Reservation not found" });
    }

  if (reservation.payment_provider !== "portone") {
    return jsonResponse(409, {error: "Use the provider-aware rental-payment command"});
  }

    // Only the lender can settle. The borrower's authority ends at
    // `returned`; if the borrower wants money back they go through
    // dispute → admin resolved instead.
    if (reservation.lender_id !== callerId) {
      return jsonResponse(403, { error: "Only the lender may settle" });
    }
    if (reservation.status === "settled") {
      return jsonResponse(200, {
        reservation_id: reservation.id,
        imp_uid: reservation.payment_id,
        refunded_amount: reservation.deposit,
        lender_payout_pending: reservation.total_paid - reservation.deposit,
        status: "settled",
      });
    }
    if (reservation.status !== "returned") {
      return jsonResponse(409, {
        error: `Cannot settle a reservation in status '${reservation.status}'`,
      });
    }
    if (!reservation.payment_id) {
      // Should be impossible — `paid` requires payment_id to have been
      // stamped — but guard anyway.
      return jsonResponse(409, { error: "Reservation has no payment_id" });
    }
    if (reservation.deposit < 0) {
      return jsonResponse(409, { error: "Reservation deposit is invalid" });
    }

    if (reservation.payment_action === "settle_pending") {
      const actionIsStale = paymentActionIsStale(
        reservation.payment_action_started_at,
      );

      if (reservation.deposit === 0 && actionIsStale) {
        await clearReservationPaymentAction(adminClient, {
          reservationId: reservation.id,
          action: "settle_pending",
        });
      } else if (reservation.deposit === 0) {
        return jsonResponse(409, { error: "Settlement already in progress" });
      } else {
        let payment: PortOnePayment;
        try {
          const token = await getPortOneAccessToken();
          payment = await fetchPortOnePayment(reservation.payment_id, token);
        } catch (e) {
          console.error("PortOne lookup failed during settlement retry", e);
          return jsonResponse(502, { error: "PortOne lookup failed" });
        }

        if (payment.currency && payment.currency !== reservation.currency) {
          return jsonResponse(409, { error: "Currency mismatch" });
        }

        const refundedAmount = payment.cancel_amount ?? 0;
        if (refundedAmount < reservation.deposit) {
          return jsonResponse(409, {
            error: "Settlement outcome is unknown; provider reconciliation is required",
          });
        } else {
          const { data: retryTxResult, error: retryTxError } =
            await transitionReservationStatus(adminClient, {
              reservationId: reservation.id,
              target: "settled",
              actorKind: "system",
            });
          if (retryTxError || retryTxResult?.ok !== true) {
            console.error("settlement retry transition failed", {
              retryTxError,
              retryTxResult,
              reservationId: reservation.id,
            });
            return jsonResponse(500, {
              error:
                "Deposit already refunded at PortOne but state transition failed. Contact support.",
              imp_uid: reservation.payment_id,
            });
          }

          return jsonResponse(200, {
            reservation_id: reservation.id,
            imp_uid: reservation.payment_id,
            refunded_amount: refundedAmount,
            lender_payout_pending: reservation.total_paid - reservation.deposit,
            status: "settled",
          });
        }
      }
    }

    const { data: beginResult, error: beginError } =
      await beginReservationPaymentAction(adminClient, {
        reservationId: reservation.id,
        action: "settle_pending",
        paymentId: reservation.payment_id,
        actorId: callerId,
      });
    if (beginError || beginResult?.ok !== true) {
      console.error("begin settlement failed", { beginError, beginResult });
      return jsonResponse(409, {
        error: beginResult?.error ?? "Could not start settlement",
      });
    }

    // Refund the deposit portion via PortOne partial cancel. If the item had
    // no deposit, no external money movement is needed; the DB transition is
    // still protected by the same settle_pending lock.
    let cancelled: PortOnePayment | { cancel_amount: number; status: string };
    if (reservation.deposit === 0) {
      cancelled = { cancel_amount: 0, status: "settled" };
    } else {
      try {
        const token = await getPortOneAccessToken();
        cancelled = await portOneCancel(token, {
          imp_uid: reservation.payment_id,
          amount: reservation.deposit,
          reason: `Deposit refund — reservation ${reservation.id} settled`,
        });
      } catch (e) {
        console.error("PortOne cancel failed", e);
        return jsonResponse(502, {
          error:
            "PortOne cancel status is unknown. Retry will reconcile provider state before another cancel.",
        });
      }
    }

    // Advance state via the RPC. If this fails AFTER PortOne refunded
    // the deposit, we have state divergence — surface it with imp_uid
    // so Ops can mark the row manually.
    const { data: txResult, error: txError } =
      await transitionReservationStatus(adminClient, {
        reservationId: reservation.id,
        target: "settled",
        actorKind: "system",
      });
    if (txError || txResult?.ok !== true) {
      console.error(
        "transition failed AFTER PortOne settled deposit — STATE DIVERGENCE",
        {
          reservationId: reservation.id,
          imp_uid: reservation.payment_id,
          refunded_amount: cancelled.cancel_amount,
          txError,
          txResult,
        },
      );
      return jsonResponse(500, {
        error:
          "Deposit refunded at PortOne but state transition failed. Contact support.",
        imp_uid: reservation.payment_id,
      });
    }

    return jsonResponse(200, {
      reservation_id: reservation.id,
      imp_uid: reservation.payment_id,
      refunded_amount: cancelled.cancel_amount,
      lender_payout_pending: reservation.total_paid - reservation.deposit,
      status: "settled",
    });
  } catch (error) {
    console.error("settle-reservation handler error", error);
    return jsonResponse(500, { error: "Internal server error" });
  }
});
