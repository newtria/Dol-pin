import { errorResponse, jsonResponse, parseJsonBody } from "./http.ts";
import { ApiError } from "./errors.ts";
function assert(v: unknown, message: string) {
  if (!v) throw new Error(message);
}
Deno.test("errors have a safe shared contract without SQL/provider details", async () => {
  for (
    const [error, status, code] of [
      [{ code: "42501", message: "secret internal table" }, 403, "FORBIDDEN"],
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
    old.refunded === true && !JSON.stringify(old).includes("secret") &&
      !JSON.stringify(old).includes("raw"),
    "legacy unsafe",
  );
  const limited = jsonResponse(429, { retryAfter: 42 });
  assert(limited.headers.get("Retry-After") === "42", "missing retry delay");
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
