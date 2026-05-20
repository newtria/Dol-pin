// Per-user daily quota for cost-bearing Edge Functions (Gemini today, FCM
// once it goes live). Implemented as an atomic RPC against the
// `function_usage_quota` table; see migration 017.
//
// Each (user_id, function_name, day) row holds a `count` that we increment
// before serving the request. If the increment would exceed the configured
// daily limit we reject with 429.

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

export interface QuotaOk {
  ok: true
  count: number
  limit: number
}
export interface QuotaExceeded {
  ok: false
  status: 429
  error: string
  retryAfterSeconds: number
}
export interface QuotaError {
  ok: false
  status: 500
  error: string
}

export type QuotaResult = QuotaOk | QuotaExceeded | QuotaError

/// Atomically increments today's counter for (userId, functionName) and
/// returns the new value. Rejects with 429 once the value exceeds `limit`.
///
/// The RPC is idempotent over a single request — callers must call this
/// exactly once per request, before doing the cost-bearing work.
export async function checkAndIncrementQuota(
  userId: string,
  functionName: string,
  limit: number,
): Promise<QuotaResult> {
  const { data, error } = await adminClient.rpc('increment_function_usage', {
    p_user_id: userId,
    p_function_name: functionName,
    p_limit: limit,
  })
  if (error) {
    console.error('quota rpc failed', error)
    return { ok: false, status: 500, error: 'Quota check failed' }
  }

  // The RPC returns `{count, allowed}`. When `allowed` is false the count
  // already exceeds the limit and we should reject.
  const row = data as { count: number; allowed: boolean } | null
  if (!row) {
    return { ok: false, status: 500, error: 'Quota response empty' }
  }
  if (!row.allowed) {
    const secondsUntilMidnightUtc = secondsUntilUtcMidnight()
    return {
      ok: false,
      status: 429,
      error: `Daily limit of ${limit} for ${functionName} reached`,
      retryAfterSeconds: secondsUntilMidnightUtc,
    }
  }
  return { ok: true, count: row.count, limit }
}

function secondsUntilUtcMidnight(): number {
  const now = new Date()
  const next = new Date(
    Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + 1,
      0,
      0,
      0,
      0,
    ),
  )
  return Math.max(1, Math.ceil((next.getTime() - now.getTime()) / 1000))
}
