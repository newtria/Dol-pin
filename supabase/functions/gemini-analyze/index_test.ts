import { createHandler } from "./index.ts";
function assert(v: unknown, message: string) {
  if (!v) throw new Error(message);
}
Deno.test("AI quota is reserved for the authenticated actor before provider cost; denial fails closed", async () => {
  const keys = [
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
    "GEMINI_API_KEY",
    "GEMINI_MODEL",
  ];
  const previous = keys.map((key) => Deno.env.get(key));
  for (const key of keys) {
    Deno.env.set(
      key,
      key === "SUPABASE_URL" ? "https://supabase.invalid" : "fixture",
    );
  }
  Deno.env.set("GEMINI_MODEL", "gemini-3.6-flash");
  const original = globalThis.fetch;
  let allowed = false, broken = false, providerCalls = 0, quotaCalls = 0;
  let analysisText = "사진 분석 결과";
  globalThis.fetch = async (input, init) => {
    const url = input instanceof Request ? input.url : String(input);
    if (url.includes("/auth/v1/user")) {
      return Response.json({ id: "00000000-0000-4000-8000-000000000001" });
    }
    if (url.includes("/rpc/consume_api_quota")) {
      quotaCalls++;
      const body = JSON.parse(String(init?.body));
      assert(
        body.p_user_id === "00000000-0000-4000-8000-000000000001" &&
          body.p_feature === "gemini-analyze",
        "caller spoofed",
      );
      return broken
        ? Response.json({ message: "private schema failure" }, { status: 500 })
        : Response.json({ allowed, retryAfter: 31 });
    }
    if (url.startsWith("https://generativelanguage.googleapis.com/")) {
      assert(
        url.endsWith("/models/gemini-3.6-flash:generateContent") &&
          new Headers(init?.headers).get("x-goog-api-key") === "fixture",
        "model or credential transport incorrect",
      );
      providerCalls++;
      return Response.json({
        candidates: [{ content: { parts: [{ text: analysisText }] } }],
      });
    }
    throw new Error("Unexpected request");
  };
  const request = (body: unknown) =>
    new Request("https://test.invalid", {
      method: "POST",
      headers: { Authorization: "Bearer fixture" },
      body: JSON.stringify(body),
    });
  const input = {
    image: "aGVsbG8=",
    mimeType: "image/png",
    prompt: "물품 상태를 분석해 주세요.",
    userId: "spoof",
  };
  try {
    const handler = createHandler();
    let response = await handler(request(input));
    assert(
      response.status === 429 && response.headers.get("Retry-After") === "31",
      "quota not enforced",
    );
    await response.body?.cancel();
    assert(providerCalls === 0, "denied request incurred cost");
    broken = true;
    response = await handler(request(input));
    assert(response.status === 503, "quota failure did not fail closed");
    await response.body?.cancel();
    assert(providerCalls === 0, "quota outage incurred cost");
    broken = false;
    allowed = true;
    response = await handler(request(input));
    assert(
      response.status === 200 &&
        (await response.json()).result === "사진 분석 결과",
      "allowed request failed",
    );
    assert(Number(providerCalls) === 1, "provider count incorrect");
    analysisText = "";
    response = await handler(request(input));
    assert(
      response.status === 502 &&
        (await response.json()).code === "UPSTREAM_UNAVAILABLE",
      "empty provider output appeared successful",
    );
    const before = quotaCalls;
    response = await handler(
      request({ image: "x", prompt: "x", mimeType: "text/html" }),
    );
    assert(
      response.status === 415 && quotaCalls === before,
      "invalid request used quota",
    );
    await response.body?.cancel();
  } finally {
    globalThis.fetch = original;
    keys.forEach((key, i) =>
      previous[i] === undefined
        ? Deno.env.delete(key)
        : Deno.env.set(key, previous[i]!)
    );
  }
});
