import { ApiError, errorCode, providerCall } from "./errors.ts";
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  type Payment,
  paymentProvider,
  type ProviderFactory,
} from "./payment-provider.ts";

export async function rpc<T = unknown>(
  admin: SupabaseClient,
  name: string,
  args: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await admin.rpc(name, args);
  if (error) throw error;
  return data as T;
}
function identity(p: Payment, id: string, total: number, orderId?: string) {
  if (
    p.id !== id || p.total !== total || p.currency !== "KRW" ||
    (orderId && p.orderId !== orderId)
  ) {
    throw new ApiError("PAYMENT_REVIEW_REQUIRED");
  }
}
export async function reconcileCheckout(
  admin: SupabaseClient,
  orderId: string,
  paymentKey?: string,
  providers: ProviderFactory = paymentProvider,
) {
  const lease = crypto.randomUUID();
  const claimed = await rpc<boolean>(admin, "claim_toss_confirmation", {
    p_order_id: orderId,
    p_lease: lease,
    p_payment_key: paymentKey ?? null,
  });
  if (!claimed) {
    const { data: checkout, error: checkoutError } = await admin.from("toss_checkouts")
      .select("reservation_id").eq("order_id", orderId).single();
    if (checkoutError) throw checkoutError;
    const { data: reservation, error } = await admin.from("reservations")
      .select("status").eq("id", checkout.reservation_id).single();
    if (error) throw error;
    return {
      status: reservation.status === "accepted" ? "processing" : reservation.status,
      reservationId: checkout.reservation_id,
    };
  }
  try {
    const { data: c, error } = await admin.from("toss_checkouts").select("*")
      .eq("order_id", orderId).single();
    if (error) throw error;
    const provider = providers("toss");
    let p = await providerCall(() => provider.lookupOrder(orderId));
    // Only a current browser confirmation may initiate approval; workers only look up.
    if (
      paymentKey && (!p || p.status === "unpaid") &&
      Date.now() < Date.parse(c.expires_at)
    ) {
      p = await providerCall(() =>
        provider.confirm(paymentKey, orderId, c.amount)
      );
    }
    if (!p) {
      if (!c.payment_key && Date.now() >= Date.parse(c.expires_at)) {
        const status = await rpc<string>(admin, "fail_toss_confirmation", {
          p_order_id: orderId,
          p_lease: lease,
        });
        return { status, reservationId: c.reservation_id };
      }
      if (c.payment_key && Date.now() > Date.parse(c.expires_at) + 86400000) {
        throw new ApiError("PAYMENT_REVIEW_REQUIRED");
      }
      await recordAttempt(
        admin,
        "checkout",
        orderId,
        lease,
        "OUTCOME_PENDING",
        false,
        false,
      );
      return { status: "processing", reservationId: c.reservation_id };
    }
    identity(p, c.payment_key ?? p.id, c.amount, orderId);
    if (p.status === "paid" && p.refunded === 0) {
      await rpc(admin, "finish_toss_confirmation", {
        p_order_id: orderId,
        p_payment_key: p.id,
        p_lease: lease,
      });
      return { status: "paid", reservationId: c.reservation_id };
    }
    if (p.status === "failed" || p.status === "cancelled") {
      const status = await rpc<string>(admin, "fail_toss_confirmation", {
        p_order_id: orderId,
        p_lease: lease,
      });
      return { status, reservationId: c.reservation_id };
    }
    if (Date.now() > Date.parse(c.expires_at) + 86400000) {
      throw new ApiError("PAYMENT_REVIEW_REQUIRED");
    }
    await recordAttempt(
      admin,
      "checkout",
      orderId,
      lease,
      "OUTCOME_PENDING",
      false,
      false,
    );
    return { status: "processing", reservationId: c.reservation_id };
  } catch (error) {
    await recordAttempt(
      admin,
      "checkout",
      orderId,
      lease,
      errorCode(error),
      errorCode(error) === "PAYMENT_REVIEW_REQUIRED",
    );
    throw error;
  } finally {
    await rpc(admin, "release_toss_confirmation", {
      p_order_id: orderId,
      p_lease: lease,
    });
  }
}

type Operation = {
  id: string;
  reservation_id: string;
  provider: string;
  payment_id: string;
  amount: number;
  total: number;
  kind: "refund" | "settle";
  dispatched_at: string | null;
};
export async function reconcileMoney(
  admin: SupabaseClient,
  id: string,
  providers: ProviderFactory = paymentProvider,
) {
  const lease = crypto.randomUUID();
  const op = await rpc<Operation | null>(
    admin,
    "claim_rental_money_operation",
    { p_id: id, p_lease: lease },
  );
  if (!op?.id) return { status: "processing" };
  try {
    if (op.amount > 0) {
      const provider = providers(op.provider);
      let p = await providerCall(() => provider.lookup(op.payment_id));
      const orderId = op.provider === "toss"
        ? `dolpin_${op.reservation_id.replaceAll("-", "")}`
        : op.reservation_id;
      identity(p, op.payment_id, op.total, orderId);
      if (p.refunded !== op.amount) {
        if (p.refunded !== 0 || p.status !== "paid") {
          throw new ApiError("PAYMENT_REVIEW_REQUIRED");
        }
        // PortOne V1 has no operation idempotency contract. Unknown requests are
        // reconciled by lookup only. Toss retries stay inside its retention window.
        if (
          op.dispatched_at &&
          (op.provider !== "toss" ||
            Date.now() - Date.parse(op.dispatched_at) > 14 * 86400000)
        ) {
          throw new ApiError("PAYMENT_REVIEW_REQUIRED");
        }
        const valid = await rpc<boolean>(
          admin,
          "dispatch_rental_money_operation",
          { p_id: id, p_lease: lease },
        );
        if (!valid) return { status: "processing" };
        p = await providerCall(() =>
          provider.cancel(op.payment_id, op.amount, op.total, op.id)
        );
        identity(p, op.payment_id, op.total, orderId);
        if (p.refunded !== op.amount) {
          throw new ApiError("PAYMENT_REVIEW_REQUIRED");
        }
      }
    }
    await rpc(admin, "finish_rental_money_operation", {
      p_id: id,
      p_lease: lease,
    });
    return {
      status: op.kind === "refund" ? "cancelled" : "settled",
      reservationId: op.reservation_id,
    };
  } catch (error) {
    await recordAttempt(
      admin,
      "money",
      id,
      lease,
      errorCode(error),
      errorCode(error) === "PAYMENT_REVIEW_REQUIRED",
    );
    throw error;
  } finally {
    await rpc(admin, "release_rental_money_operation", {
      p_id: id,
      p_lease: lease,
    });
  }
}

async function recordAttempt(
  admin: SupabaseClient,
  kind: "checkout" | "money",
  key: string,
  lease: string,
  code: string,
  review = false,
  failed = true,
) {
  await rpc(admin, "record_rental_recovery_attempt", {
    p_kind: kind,
    p_key: key,
    p_lease: lease,
    p_code: code,
    p_review: review,
    p_failed: failed,
  });
  console.warn(
    JSON.stringify({
      event: "rental_recovery_attempt",
      kind,
      key,
      code,
      review,
    }),
  );
}
