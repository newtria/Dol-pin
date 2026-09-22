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
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data, error } = await callerClient.auth.getUser(jwt);
  if (error || !data?.user) {
    return jsonResponse(401, { error: "Invalid token" });
  }

  return { id: data.user.id, jwt };
}
