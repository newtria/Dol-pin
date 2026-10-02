import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import { jsonResponse } from "./http.ts";

export interface AuthenticatedUser {
  id: string;
  jwt: string;
}

export async function requireAuthenticatedUser(
  req: Request,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<AuthenticatedUser | Response> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return jsonResponse(401, { error: "Missing bearer token" });
  }

  const jwt = authHeader.slice("Bearer ".length).trim();
  if (!jwt) {
    return jsonResponse(401, { error: "Empty bearer token" });
  }

  const callerClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      headers: { Authorization: `Bearer ${jwt}` },
      fetch: (input, init) => fetch(input, { ...init, signal: AbortSignal.timeout(10_000) }),
    },
  });
  const { data, error } = await callerClient.auth.getUser(jwt);
  // An unavailable Auth service does not mean the customer's login expired.
  if (error && (!error.status || error.status >= 500 || error.status === 429)) {
    return jsonResponse(503, { code: "SERVICE_UNAVAILABLE" }, error);
  }
  if (error || !data?.user) {
    return jsonResponse(401, { error: "Invalid token" });
  }

  return { id: data.user.id, jwt };
}
