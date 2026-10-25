import { paymentProvider, tossProvider } from "./payment-provider.ts";
import { portOneCancel } from "./portone.ts";
function assert(v: unknown, message: string) {
  if (!v) throw new Error(message);
}
Deno.test("Toss adapter uses authoritative cancel amount, balance guard, operation key and terminal status mapping", async () => {
  const previousSecret = Deno.env.get("TOSS_SECRET_KEY");
  Deno.env.set("TOSS_SECRET_KEY", "test_sk_fixture");
  const original = globalThis.fetch;
  let status = "PARTIAL_CANCELED";
  globalThis.fetch = async (_input, init) => {
    if (init?.method === "POST") {
      const body = JSON.parse(String(init.body));
      assert(
        body.cancelAmount === 30000 && body.refundableAmount === 35000,
        "unsafe cancellation amounts",
      );
      assert(
        new Headers(init.headers).get("Idempotency-Key") === "operation-1",
        "missing stable key",
      );
    }
    return Response.json({
      paymentKey: "payment",
      orderId: "order",
      totalAmount: 35000,
      balanceAmount: status === "PARTIAL_CANCELED" ? 5000 : 35000,
      currency: "KRW",
      status,
    });
  };
  try {
    const provider = tossProvider();
    const p = await provider.cancel("payment", 30000, 35000, "operation-1");
    assert(p.refunded === 30000, "incorrect refunded amount");
    status = "ABORTED";
    assert(
      (await provider.lookup("payment")).status === "failed",
      "failed approval not terminal",
    );
    status = "EXPIRED";
    assert(
      (await provider.lookup("payment")).status === "failed",
      "expired approval not terminal",
    );
    globalThis.fetch = async () => Response.json({}, { status: 404 });
    assert(
      await provider.lookupOrder("missing") === null,
      "not-found lookup ambiguous",
    );
    globalThis.fetch = async () => Response.json({}, { status: 503 });
    let rejected = false;
    try {
      await provider.lookupOrder("unknown");
    } catch {
      rejected = true;
    }
    assert(rejected, "provider outage treated as unpaid");
  } finally {
    globalThis.fetch = original;
    if (previousSecret === undefined) Deno.env.delete("TOSS_SECRET_KEY");
    else Deno.env.set("TOSS_SECRET_KEY", previousSecret);
  }
});

Deno.test("PortOne adapter keeps its provider identity and partial cancellation contract", async () => {
  const original = globalThis.fetch;
  let called = false;
  globalThis.fetch = async (input, init) => {
    const url = String(input);
    assert(url.startsWith("https://api.iamport.kr/"), "wrong provider called");
    if (url.endsWith("/users/getToken")) {
      return Response.json({
        code: 0,
        response: {
          access_token: "fixture-token",
          expired_at: Date.now() / 1000 + 3600,
        },
      });
    }
    if (url.endsWith("/payments/cancel")) {
      const body = JSON.parse(String(init?.body));
      assert(
        body.imp_uid === "imp_fixture" && body.amount === 30000 &&
          body.checksum === 35000,
        "wrong PortOne refund or missing balance guard",
      );
      called = true;
    }
    return Response.json({
      code: 0,
      response: {
        imp_uid: "imp_fixture",
        merchant_uid: "dolpin_reservation_attempt",
        amount: 35000,
        cancel_amount: called ? 30000 : 0,
        currency: "KRW",
        status: "paid",
      },
    });
  };
  try {
    const provider = paymentProvider("portone");
    assert(
      (await provider.lookup("imp_fixture")).orderId === "reservation",
      "order binding lost",
    );
    assert(
      (await provider.cancel("imp_fixture", 30000, 35000, "op")).refunded ===
        30000,
      "partial amount lost",
    );
  } finally {
    globalThis.fetch = original;
  }
});

async function rejects(run: () => Promise<unknown>) {
  let rejected = false;
  try {
    await run();
  } catch {
    rejected = true;
  }
  assert(rejected, "unsafe provider call was accepted");
}

Deno.test("PortOne compares the expected balance on every partial cancellation and returns cumulative refunds", async () => {
  const original = globalThis.fetch;
  const checksums: number[] = [];
  let refunded = 0;
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
    assert(
      url === "https://api.iamport.kr/payments/cancel",
      "unexpected provider request",
    );
    const body = JSON.parse(String(init?.body));
    checksums.push(body.checksum);
    if (body.checksum !== 35000 - refunded) {
      return Response.json({ code: 1, message: "balance changed" });
    }
    refunded += body.amount;
    return Response.json({
      code: 0,
      response: {
        imp_uid: "imp_fixture",
        merchant_uid: "dolpin_reservation_attempt",
        amount: 35000,
        cancel_amount: refunded,
        currency: "KRW",
        status: refunded === 35000 ? "cancelled" : "paid",
      },
    });
  };
  try {
    const provider = paymentProvider("portone");
    assert(
      (await provider.cancel("imp_fixture", 10000, 35000, "first")).refunded ===
        10000,
      "first partial refund lost",
    );
    assert(
      (await provider.cancel("imp_fixture", 5000, 25000, "second")).refunded ===
        15000,
      "cumulative refunds replaced by the latest amount",
    );
    // An old caller snapshot must not spend the remaining balance after another refund.
    await rejects(() => provider.cancel("imp_fixture", 5000, 35000, "stale"));
    assert(refunded === 15000, "stale checksum caused another refund");
    const final = await provider.cancel("imp_fixture", 20000, 20000, "last");
    assert(
      final.refunded === 35000 && final.status === "cancelled",
      "full cumulative refund not preserved",
    );
    assert(
      JSON.stringify(checksums) === "[35000,25000,35000,20000]",
      "original total substituted for expected balance",
    );
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("invalid cancellation amounts never reach a provider, including direct PortOne requests", async () => {
  const original = globalThis.fetch;
  const previousSecret = Deno.env.get("TOSS_SECRET_KEY");
  Deno.env.set("TOSS_SECRET_KEY", "test_sk_fixture");
  let requests = 0;
  globalThis.fetch = () => {
    requests++;
    throw new Error("unexpected HTTP");
  };
  const cases: [number, number][] = [
    [0, 35000],
    [-1, 35000],
    [0.5, 35000],
    [NaN, 35000],
    [Infinity, 35000],
    [35001, 35000],
    [1, 0],
    [1, -1],
    [1, 35000.5],
    [1, NaN],
    [1, Infinity],
    [Number.MAX_SAFE_INTEGER + 1, Number.MAX_SAFE_INTEGER + 1],
    [undefined as unknown as number, 35000],
    [1, undefined as unknown as number],
  ];
  try {
    for (const [amount, balance] of cases) {
      for (const name of ["toss", "portone"]) {
        await rejects(() =>
          paymentProvider(name).cancel("payment", amount, balance, "operation")
        );
      }
      await rejects(() =>
        portOneCancel("fixture-token", {
          imp_uid: "imp_fixture",
          amount,
          checksum: balance,
          reason: "fixture",
        })
      );
    }
    assert(
      requests === 0,
      "invalid amount or omitted checksum reached the network",
    );
  } finally {
    globalThis.fetch = original;
    if (previousSecret === undefined) Deno.env.delete("TOSS_SECRET_KEY");
    else Deno.env.set("TOSS_SECRET_KEY", previousSecret);
  }
});

Deno.test("PortOne never treats an absent or malformed cumulative refund as zero", async () => {
  const original = globalThis.fetch;
  let cancelAmount: unknown;
  globalThis.fetch = async (input) => {
    if (String(input).endsWith("/users/getToken")) {
      return Response.json({
        code: 0,
        response: {
          access_token: "fixture-token",
          expired_at: Date.now() / 1000 + 3600,
        },
      });
    }
    assert(
      String(input).endsWith("/payments/imp_fixture"),
      "unexpected cancellation",
    );
    return Response.json({
      code: 0,
      response: {
        imp_uid: "imp_fixture",
        merchant_uid: "dolpin_reservation_attempt",
        amount: 35000,
        cancel_amount: cancelAmount,
        currency: "KRW",
        status: "paid",
      },
    });
  };
  try {
    const provider = paymentProvider("portone");
    for (cancelAmount of [undefined, null, "0", -1, 0.5, 35001]) {
      await rejects(() => provider.lookup("imp_fixture"));
    }
    cancelAmount = 0;
    assert(
      (await provider.lookup("imp_fixture")).refunded === 0,
      "explicit zero refund rejected",
    );
  } finally {
    globalThis.fetch = original;
  }
});
