import { ApiError } from "./errors.ts";
import {
  type Payment,
  type PaymentProvider,
  paymentProvider,
} from "./payment-provider.ts";
import { reconcileMoney } from "./rental-finance.ts";

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

async function rejects(run: () => Promise<unknown>, code?: string) {
  try {
    await run();
  } catch (error) {
    if (code) {
      assert(
        error instanceof ApiError && error.code === code,
        "unexpected failure code",
      );
    }
    return;
  }
  throw new Error("unsafe reconciliation was accepted");
}

function ledger(amount = 20000, total = 100000) {
  const op = {
    id: "operation-fixture",
    reservation_id: "reservation-fixture",
    provider: "portone",
    payment_id: "imp_fixture",
    amount,
    total,
    kind: "settle",
    dispatched_at: null as string | null,
  };
  let completed = 0, dispatched = 0, released = 0;
  const attempts: Record<string, unknown>[] = [];
  const admin = {
    async rpc(name: string, args: Record<string, unknown>) {
      if (name === "claim_rental_money_operation") {
        return { data: { ...op }, error: null };
      }
      if (name === "dispatch_rental_money_operation") {
        op.dispatched_at ??= new Date().toISOString();
        dispatched++;
        return { data: true, error: null };
      }
      if (name === "finish_rental_money_operation") completed++;
      else if (name === "record_rental_recovery_attempt") attempts.push(args);
      else if (name === "release_rental_money_operation") released++;
      else throw new Error(`unexpected RPC ${name}`);
      return { data: null, error: null };
    },
  } as unknown as Parameters<typeof reconcileMoney>[0];
  return {
    admin,
    op,
    attempts,
    get completed() {
      return completed;
    },
    get dispatched() {
      return dispatched;
    },
    get released() {
      return released;
    },
  };
}

function captured(refunded = 0): Payment {
  return {
    id: "imp_fixture",
    orderId: "reservation-fixture",
    total: 100000,
    refunded,
    currency: "KRW",
    status: "paid",
  };
}

function stubProvider(
  overrides: Partial<PaymentProvider> = {},
): PaymentProvider {
  const unexpected = () =>
    Promise.reject(new Error("unexpected provider operation"));
  return {
    lookupOrder: unexpected,
    lookup: unexpected,
    confirm: unexpected,
    cancel: unexpected,
    ...overrides,
  };
}

Deno.test("PortOne external refund between lookup and cancellation is rejected without another debit", async () => {
  const l = ledger();
  const original = globalThis.fetch;
  let refunded = 0, cancelRequests = 0;
  globalThis.fetch = async (input, init) => {
    const url = String(input);
    if (url.endsWith("/users/getToken")) {
      return Response.json({
        code: 0,
        response: {
          access_token: "fixture-token",
          expired_at: Date.now() / 1000 + 3600,
        },
      });
    }
    const snapshot = () => ({
      imp_uid: "imp_fixture",
      merchant_uid: "dolpin_reservation-fixture_attempt",
      amount: 100000,
      cancel_amount: refunded,
      currency: "KRW",
      status: "paid",
    });
    if (url.endsWith("/payments/imp_fixture")) {
      const response = snapshot();
      // Two independent external partial refunds race with this captured snapshot.
      if (refunded === 0) {
        refunded += 4000;
        refunded += 6000;
      }
      return Response.json({ code: 0, response });
    }
    assert(url.endsWith("/payments/cancel"), "unexpected provider request");
    cancelRequests++;
    const body = JSON.parse(String(init?.body));
    assert(
      body.amount === 20000 && body.checksum === 100000,
      "wrong refund/balance sent to PortOne",
    );
    if (body.checksum !== 100000 - refunded) {
      return Response.json({ code: 1, message: "checksum mismatch" });
    }
    refunded += body.amount;
    return Response.json({ code: 0, response: snapshot() });
  };
  try {
    await rejects(
      () => reconcileMoney(l.admin, l.op.id, paymentProvider),
      "UPSTREAM_UNAVAILABLE",
    );
    await rejects(
      () => reconcileMoney(l.admin, l.op.id, paymentProvider),
      "PAYMENT_REVIEW_REQUIRED",
    );
    assert(
      cancelRequests === 1 && refunded === 10000,
      "recovery added to an external refund",
    );
    assert(
      l.completed === 0 && l.released === 2,
      "unconfirmed refund completed or lease not released",
    );
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("lost PortOne cancellation response is recovered only by cumulative lookup", async () => {
  const l = ledger();
  let refunded = 0, cancels = 0;
  const provider = stubProvider({
    lookup: async () => captured(refunded),
    cancel: async (_id, amount, expectedBalance) => {
      assert(
        amount === 20000 && expectedBalance === 100000,
        "wrong cancellation boundary",
      );
      cancels++;
      refunded = amount;
      throw new DOMException("response lost", "TimeoutError");
    },
  });
  await rejects(
    () => reconcileMoney(l.admin, l.op.id, () => provider),
    "REQUEST_TIMEOUT",
  );
  const result = await reconcileMoney(l.admin, l.op.id, () => provider);
  assert(
    result.status === "settled" && l.completed === 1 && cancels === 1,
    "successful cancellation was sent again",
  );
});

Deno.test("unknown or malformed PortOne outcome never permits a second cancellation", async () => {
  for (const outcome of ["timeout", "malformed", "wrong_amount"] as const) {
    const l = ledger();
    let cancels = 0;
    const provider = stubProvider({
      lookup: async () => captured(),
      cancel: async () => {
        cancels++;
        if (outcome === "timeout") {
          throw new DOMException("response lost", "TimeoutError");
        }
        return captured(outcome === "malformed" ? NaN : 30000);
      },
    });
    await rejects(() => reconcileMoney(l.admin, l.op.id, () => provider));
    await rejects(
      () => reconcileMoney(l.admin, l.op.id, () => provider),
      "PAYMENT_REVIEW_REQUIRED",
    );
    assert(
      cancels === 1 && l.completed === 0,
      "unknown cancellation was retried or completed",
    );
    assert(
      l.attempts.at(-1)?.p_review === true,
      "unknown outcome did not require review",
    );
  }
});

Deno.test("existing cumulative refunds are reconciled without topping up partial refunds", async () => {
  for (const refunded of [10000, 20000, 30000]) {
    const l = ledger();
    let cancels = 0;
    const provider = stubProvider({
      lookup: async () => captured(refunded),
      cancel: async () => {
        cancels++;
        return captured(20000);
      },
    });
    if (refunded === 20000) {
      assert(
        (await reconcileMoney(l.admin, l.op.id, () => provider)).status ===
          "settled",
        "matching cumulative refund not reconciled",
      );
    } else {
      await rejects(
        () => reconcileMoney(l.admin, l.op.id, () => provider),
        "PAYMENT_REVIEW_REQUIRED",
      );
    }
    assert(
      cancels === 0 && l.completed === (refunded === 20000 ? 1 : 0),
      "external partial refund was topped up",
    );
  }
});

Deno.test("invalid operation amounts stop before provider work and zero refunds remain read-only", async () => {
  for (
    const [amount, total] of [
      [-1, 100000],
      [1.5, 100000],
      [100001, 100000],
      [NaN, 100000],
      [1, NaN],
      [1, 0],
      [1, Infinity],
    ]
  ) {
    const l = ledger(amount, total);
    let calls = 0;
    await rejects(() =>
      reconcileMoney(l.admin, l.op.id, () => {
        calls++;
        return stubProvider();
      }), "PAYMENT_REVIEW_REQUIRED");
    assert(
      calls === 0 && l.dispatched === 0 && l.completed === 0,
      "invalid operation reached provider",
    );
  }
  const l = ledger(0);
  const provider = stubProvider({ lookup: async () => captured() });
  assert(
    (await reconcileMoney(l.admin, l.op.id, () => provider)).status ===
      "settled",
    "zero refund cannot settle",
  );
  assert(
    l.dispatched === 0 && l.completed === 1,
    "zero refund sent a cancellation",
  );
});
