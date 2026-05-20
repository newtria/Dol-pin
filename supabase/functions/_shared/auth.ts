// Shared JWT auth helper for Edge Functions.
//
// Centralises the bearer-token parsing + Supabase `getUser()` call that was
// duplicated across verify-payment / refund-payment / push-notification.
// gemini-analyze previously skipped this step entirely — see `_shared/quota.ts`
// for the per-user quota built on top.

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// `auth.getUser(jwt)` takes the token as an argument and validates the
// signature server-side, so one shared admin client suffices — the caller's
// JWT does not need to be attached as a default header. Module-scope reuse
// avoids reconstructing the client per request.
const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

export interface AuthSuccess {
  ok: true
  userId: string
  jwt: string
}

export interface AuthFailure {
  ok: false
  status: number
  error: string
}

export type AuthResult = AuthSuccess | AuthFailure

/// Parses the `Authorization: Bearer …` header and returns the resolved
/// caller's Supabase user id. Does not validate row-level access — that is
/// the caller's responsibility once it knows `userId`.
export async function requireUser(req: Request): Promise<AuthResult> {
  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return { ok: false, status: 401, error: 'Missing bearer token' }
  }
  const jwt = authHeader.slice('Bearer '.length).trim()
  if (!jwt) {
    return { ok: false, status: 401, error: 'Empty bearer token' }
  }

  const { data, error } = await adminClient.auth.getUser(jwt)
  if (error || !data?.user) {
    return { ok: false, status: 401, error: 'Invalid token' }
  }
  return { ok: true, userId: data.user.id, jwt }
}
