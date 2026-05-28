// Per-user daily quota for cost-bearing Edge Functions (Gemini today,
// FCM once it goes live). Wraps the RPCs in migration 018 — the v1 RPC
// from 017 grew the counter past the cap; v2 gates the increment via an
// `ON CONFLICT DO UPDATE WHERE count < limit` and pairs with a
// `decrement_function_usage` so failed cost-bearing work can refund the
// slot.

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

/// Atomically increments today's counter for (userId, functionName) IFF
/// the new value would still be within `limit`. Rejects with 429 otherwise.
///
/// Wraps the RPC call in try/catch so a thrown promise (network reset,
/// pool exhaustion) becomes a structured 500 instead of an opaque
/// uncaught rejection that escapes the handler.
export async function checkAndIncrementQuota(
  userId: string,
  functionName: string,
  limit: number,
): Promise<QuotaResult> {
  let data: unknown
  try {
    const res = await adminClient.rpc('increment_function_usage', {
      p_user_id: userId,
      p_function_name: functionName,
      p_limit: limit,
    })
    if (res.error) {
      console.error('quota rpc failed', res.error)
      return { ok: false, status: 500, error: 'Quota check failed' }
    }
    data = res.data
  } catch (e) {
    console.error('quota rpc threw', e)
    return { ok: false, status: 500, error: 'Quota check failed' }
  }

  const row = data as { count: number; allowed: boolean } | null
  if (!row) {
    return { ok: false, status: 500, error: 'Quota response empty' }
  }
  if (!row.allowed) {
    return {
      ok: false,
      status: 429,
      error: `Daily limit of ${limit} for ${functionName} reached`,
      retryAfterSeconds: secondsUntilUtcMidnight(),
    }
  }
  return { ok: true, count: row.count, limit }
}

/// Refunds a previously-incremented quota slot. Call this on upstream-
/// failure paths (Gemini 5xx, fetch throw) so a failed cost-bearing call
/// does not drain the user's daily cap. Floors at 0 server-side; safe to
/// call more times than `checkAndIncrementQuota` (a double-refund is a
/// no-op, not a credit).
///
/// Best-effort: a refund failure is logged but never propagated to the
/// client — by the time we're refunding, the request has already failed,
/// and we should not turn one failure into two.
export async function refundQuotaSlot(
  userId: string,
  functionName: string,
): Promise<void> {
  try {
    const { error } = await adminClient.rpc('decrement_function_usage', {
      p_user_id: userId,
      p_function_name: functionName,
    })
    if (error) {
      console.error('quota refund failed', { userId, functionName }, error)
    }
  } catch (e) {
    console.error('quota refund threw', { userId, functionName }, e)
  }
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
