import { checked, fakeProvider, fixture, localSql } from "./fixture.ts";
import { createHandler as checkoutHandler } from "../../supabase/functions/toss-payment/index.ts";
import { createHandler as moneyHandler } from "../../supabase/functions/rental-payment/index.ts";
import { createHandler as recoveryHandler } from "../../supabase/functions/rental-recovery/index.ts";
function assert(v: unknown, message: string) {
  if (!v) throw new Error(message);
}
Deno.test("DB quota is atomic across concurrent requests, resets windows and cannot be bypassed by a client", async () => {
  const f = await fixture();
  const consume = () =>
    f.admin.rpc("consume_api_quota", {
      p_user_id: f.borrower.id,
      p_feature: "gemini-analyze",
    });
  try {
    const results = await Promise.all(Array.from({ length: 12 }, consume));
    assert(
      results.filter((r) => checked(r).allowed).length === 3,
      "concurrent minute budget exceeded",
    );
    assert(
      (await f.borrower.client.rpc("consume_api_quota", {
        p_user_id: f.borrower.id,
        p_feature: "gemini-analyze",
      })).error,
      "client may reset/consume arbitrary quota",
    );
    assert(
      (await f.borrower.client.from("api_usage_counters").select("*")).error,
      "usage counters exposed",
    );
    await localSql(
      `UPDATE public.api_usage_counters SET minute_start=now()-interval '2 minutes',day_count=29 WHERE user_id='${f.borrower.id}';`,
    );
    assert(checked(await consume()).allowed, "minute did not reset");
    const daily = checked(await consume());
    assert(!daily.allowed && daily.retryAfter > 0, "daily budget exceeded");
    await localSql(
      `UPDATE public.api_usage_counters SET day_start=CURRENT_DATE-1,minute_start=now()-interval '2 minutes' WHERE user_id='${f.borrower.id}';`,
    );
    assert(checked(await consume()).allowed, "daily budget did not reset");
  } finally {
    await f.cleanup();
  }
});

Deno.test("manual review retains financial holds; retry is private and reconciles without a second refund", async () => {
  const f = await fixture();
  const pg = fakeProvider();
  const checkout = checkoutHandler(pg.factory),
    money = moneyHandler(pg.factory);
  const call = async (
    handler: (r: Request) => Promise<Response>,
    body: unknown,
    token = f.borrower.session.access_token,
  ) => {
    const res = await handler(
      new Request("http://127.0.0.1/test", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
        body: JSON.stringify(body),
      }),
    );
    return { status: res.status, body: await res.json() };
  };
  try {
    const r = await f.rental();
    const prepared = await call(checkout, {
      action: "prepare",
      reservationId: r.id,
    });
    const q = new URLSearchParams(
      new URL(prepared.body.checkoutUrl).hash.slice(1),
    );
    const orderId = q.get("orderId")!;
    assert(
      (await call(checkout, {
        action: "confirm",
        orderId,
        token: q.get("token"),
        paymentKey: "qa-" + r.id,
        amount: r.total_paid,
      })).status === 200,
      "approval failed",
    );
    const op = checked(
      await f.admin.rpc("begin_rental_money_operation", {
        p_reservation_id: r.id,
        p_actor: f.borrower.id,
        p_kind: "refund",
      }),
    );
    await localSql(
      `UPDATE public.rental_money_operations SET dispatched_at=now()-interval '15 days' WHERE id='${op.id}';`,
    );
    const result = await call(money, { action: "refund", reservationId: r.id });
    assert(
      result.status === 409 && result.body.code === "PAYMENT_REVIEW_REQUIRED",
      "unknown refund was not escalated",
    );
    let row = checked(
      await f.admin.from("rental_money_operations").select("*").eq("id", op.id)
        .single(),
    );
    assert(
      row.review_required_at && row.status === "pending" &&
        row.last_error_code === "PAYMENT_REVIEW_REQUIRED",
      "review metadata missing",
    );
    const reservation = checked(
      await f.admin.from("reservations").select("*").eq("id", r.id).single(),
    );
    assert(
      reservation.status === "paid" &&
        reservation.payment_action === "refund_pending",
      "review cleared financial hold",
    );
    assert(
      !checked(
        await f.lender.client.rpc("transition_reservation_status", {
          p_reservation_id: r.id,
          p_target: "picked_up",
        }),
      ).ok,
      "review permitted pickup",
    );
    assert(
      (await f.outsider.client.rpc("retry_rental_recovery", {
        p_kind: "money",
        p_key: op.id,
      })).error,
      "outsider resumed recovery",
    );
    assert(
      (await f.outsider.client.from("rental_recovery_queue").select("*")).error,
      "review queue exposed",
    );
    const recovery = recoveryHandler(pg.factory, async () => [r.id]);
    assert(
      (await call(recovery, {}, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"))).body
        .checked === 0,
      "review was automatically retried",
    );
    // A stale worker cannot overwrite the persisted review.
    checked(
      await f.admin.rpc("record_rental_recovery_attempt", {
        p_kind: "money",
        p_key: op.id,
        p_lease: crypto.randomUUID(),
        p_code: "OUTCOME_PENDING",
        p_review: false,
        p_failed: false,
      }),
    );
    row = checked(
      await f.admin.from("rental_money_operations").select("*").eq("id", op.id)
        .single(),
    );
    assert(
      row.last_error_code === "PAYMENT_REVIEW_REQUIRED",
      "stale lease overwrote review",
    );
    const payment = pg.payments.get(orderId)!;
    payment.refunded = r.total_paid;
    payment.status = "cancelled";
    assert(
      checked(
        await f.admin.rpc("retry_rental_recovery", {
          p_kind: "money",
          p_key: op.id,
        }),
      ),
      "operator retry rejected",
    );
    assert(
      (await call(money, { action: "refund", reservationId: r.id })).body
        .status === "cancelled",
      "confirmed provider refund not reconciled",
    );
    assert(pg.cancelIds.length === 0, "operator retry sent a duplicate refund");
  } finally {
    await f.cleanup();
  }
});

Deno.test("transient recovery errors back off and escalate after eight failures", async () => {
  const f = await fixture();
  const pg = fakeProvider();
  const checkout = checkoutHandler(pg.factory);
  const call = async (
    handler: (r: Request) => Promise<Response>,
    body: unknown,
    token = f.borrower.session.access_token,
  ) => {
    const res = await handler(
      new Request("http://127.0.0.1/test", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
        body: JSON.stringify(body),
      }),
    );
    return { status: res.status, body: await res.json() };
  };
  try {
    const r = await f.rental();
    const prepared = await call(checkout, {
      action: "prepare",
      reservationId: r.id,
    });
    const q = new URLSearchParams(
      new URL(prepared.body.checkoutUrl).hash.slice(1),
    );
    await call(checkout, {
      action: "confirm",
      orderId: q.get("orderId"),
      token: q.get("token"),
      paymentKey: "qa-" + r.id,
      amount: r.total_paid,
    });
    let providerCalls = 0;
    const failing = () => ({
      ...pg.factory("toss"),
      async lookup() {
        providerCalls++;
        throw new Error("provider secret must not escape");
      },
    });
    const money = moneyHandler(failing);
    const recovery = recoveryHandler(failing, async () => [r.id]);
    const result = await call(money, { action: "refund", reservationId: r.id });
    assert(
      result.status === 502 && !JSON.stringify(result.body).includes("secret"),
      "unsafe failure response",
    );
    assert(
      (await call(recovery, {}, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"))).body
        .checked === 0,
      "backoff ignored",
    );
    assert(providerCalls === 1, "worker retried before due");
    const earlyRetries = await Promise.all(
      Array.from({ length: 4 }, () =>
        call(money, { action: "refund", reservationId: r.id })
      ),
    );
    assert(
      earlyRetries.every((retry) => retry.body.status === "processing") &&
        providerCalls === 1,
      "manual/concurrent retry bypassed database backoff",
    );
    for (let i = 1; i < 8; i++) {
      await localSql(
        `UPDATE public.rental_money_operations SET next_attempt_at=now()-interval '1 second' WHERE reservation_id='${r.id}';`,
      );
      await call(money, { action: "refund", reservationId: r.id });
    }
    const row = checked(
      await f.admin.from("rental_money_operations").select("*").eq(
        "reservation_id",
        r.id,
      ).single(),
    );
    assert(
      row.failure_count === 8 && row.review_required_at &&
        row.last_error_code === "UPSTREAM_UNAVAILABLE",
      "retries not escalated",
    );
    assert(
      (await call(money, { action: "refund", reservationId: r.id })).body
        .code === "PAYMENT_REVIEW_REQUIRED",
      "review permits further automatic calls",
    );
    assert(Number(providerCalls) === 8, "review called provider");
  } finally {
    await f.cleanup();
  }
});
