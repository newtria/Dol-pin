import { requireAuthenticatedUser } from "./auth.ts";

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

Deno.test("Auth outages remain retryable instead of expiring a valid login", async () => {
  const originalFetch = globalThis.fetch;
  try {
    for (const status of [401, 429, 503]) {
      globalThis.fetch = (_input, init) => {
        assert(init?.signal instanceof AbortSignal, "Auth request has no deadline");
        return Promise.resolve(Response.json({ message: "private auth diagnostics" }, { status }));
      };
      const response = await requireAuthenticatedUser(
        new Request("https://app.invalid", { headers: { Authorization: "Bearer test-token" } }),
        "https://project.supabase.co",
        "server-test-key",
      );
      assert(response instanceof Response, "Auth failure accepted as a user");
      const body = await response.json();
      assert(response.status === (status === 401 ? 401 : 503), "Auth outage incorrectly signs the user out");
      assert(body.code === (status === 401 ? "AUTH_REQUIRED" : "SERVICE_UNAVAILABLE"), "Wrong error contract");
      assert(!JSON.stringify(body).includes("private"), "Raw Auth error exposed");
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});
