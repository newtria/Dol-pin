import { errorResponse, jsonResponse, parseJsonBody } from "./http.ts";
import { ApiError } from "./errors.ts";
import { errorDiagnostics } from "./telemetry.ts";
function assert(v: unknown, message: string) {
  if (!v) throw new Error(message);
}
Deno.test("diagnostics retain safe source locations without customer data", () => {
  const cause = {
    name: "TypeError", code: "53300", message: "token=secret account=123456",
    stack: "TypeError: private@example.com\n at caller (file:///private/user/supabase/functions/_shared/rental-finance.ts:42:7)\n at fetch (https://secret.invalid/customer.ts:1:2)",
    cause: { name: "private@example.com", code: "Bearer private-secret", details: "SQL customer data" },
  };
  const diagnostics = errorDiagnostics(cause);
  const serialized = JSON.stringify(diagnostics);
  assert(serialized.includes("rental-finance.ts:42:7") && serialized.includes("53300"), "safe diagnosis lost");
  assert(!/secret|private|123456|customer|Bearer/.test(serialized), "sensitive diagnosis leaked");
  const circular: { cause?: unknown } = {};
  circular.cause = circular;
  assert(errorDiagnostics(circular).length === 1, "circular cause not bounded");
});
Deno.test("errors have a safe shared contract without SQL/provider details", async () => {
  for (
    const [error, status, code] of [
      [{ code: "42501", message: "secret internal table" }, 403, "FORBIDDEN"],
      [{ code: "P0002", message: "private missing row" }, 404, "NOT_FOUND"],
      [
        { code: "P0001", message: "private SQL details" },
        409,
        "STATE_CONFLICT",
      ],
      [
        { code: "22P02", message: "invalid uuid with input" },
        400,
        "INVALID_REQUEST",
      ],
      [new Error("token=secret stacktrace"), 500, "INTERNAL_ERROR"],
      [new ApiError("UPSTREAM_UNAVAILABLE"), 502, "UPSTREAM_UNAVAILABLE"],
      [
        new DOMException("private host", "TimeoutError"),
        504,
        "REQUEST_TIMEOUT",
      ],
    ] as const
  ) {
    const response = errorResponse(error);
    const body = await response.json();
    assert(response.headers.get("Cache-Control") === "no-store", "error response may be cached");
    assert(
      response.status === status && body.code === code,
      "wrong classification",
    );
    assert(
      typeof body.retryable === "boolean" &&
        body.requestId === response.headers.get("X-Request-Id"),
      "missing metadata",
    );
    assert(
      !JSON.stringify(body).match(/secret|private|stacktrace/),
      "internal error leaked",
    );
  }
  const old = await jsonResponse(409, {
    error: "internal raw legacy exception",
    refunded: true,
    details: "secret",
  }).json();
  assert(
    old.code === "STATE_CONFLICT" && old.refunded === true && !JSON.stringify(old).includes("secret") &&
      !JSON.stringify(old).includes("raw"),
    "legacy unsafe",
  );
  const limited = jsonResponse(429, { retryAfter: 42 });
  assert(limited.headers.get("Retry-After") === "42", "missing retry delay");
  assert(jsonResponse(200, { ok: true }).headers.get("Cache-Control") === "no-store", "private success response may be cached");
});
Deno.test("JSON parser bounds streamed bodies and rejects null/array payloads", async () => {
  for (const body of ["null", "[]", '"text"']) {
    const result = await parseJsonBody(
      new Request("https://test.invalid", { method: "POST", body }),
    );
    assert(
      result instanceof Response && result.status === 400,
      "non-object accepted",
    );
  }
  const result = await parseJsonBody(
    new Request("https://test.invalid", {
      method: "POST",
      body: JSON.stringify({ text: "x".repeat(100) }),
    }),
    32,
  );
  assert(
    result instanceof Response && result.status === 413,
    "body limit bypassed",
  );
});
