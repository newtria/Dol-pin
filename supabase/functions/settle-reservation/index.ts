// Supabase Edge Function: settle-reservation
//
// returned → settled. Refunds the deposit portion to the borrower via
// a PortOne partial cancel; leaves the rental_fee paid (it accrues to
// the lender's payout balance, settled out-of-band — v1 does not
// implement the lender payout API).
//
// Required secrets (set via `supabase secrets set ...`):
//   SUPABASE_URL                 — provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY    — provided by the platform
//   PORTONE_IMP_KEY              — PortOne REST API key
//   PORTONE_IMP_SECRET           — PortOne REST API secret (DO NOT expose)
//
// Flow:
//   1. Caller JWT must resolve to the lender of the reservation. The
//      borrower CANNOT trigger settlement — only the lender accepts
//      the return condition.
//   2. Caller sends `{reservation_id}`.
//   3. We load the reservation, verify status='returned' and caller=lender.
//   4. We call PortOne `/payments/cancel` for the `deposit` amount only.
//   5. We call `transition_reservation_status` RPC to advance returned →
//      settled.
//   6. If the RPC fails after PortOne succeeded, we return 500 with the
//      imp_uid so Ops can reconcile manually (matches the refund-payment
//      divergence handling).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const PORTONE_IMP_KEY = Deno.env.get('PORTONE_IMP_KEY')!
const PORTONE_IMP_SECRET = Deno.env.get('PORTONE_IMP_SECRET')!

const PORTONE_API = 'https://api.iamport.kr'
const PORTONE_TIMEOUT_MS = 15_000

// ---------------------------------------------------------------------------
// PortOne client (mirrors verify-payment / refund-payment until the
// `_shared/portone.ts` module from PR #20 lands on main).
// ---------------------------------------------------------------------------

let cachedPortOneToken: { value: string; expiresAt: number } | null = null

async function getPortOneAccessToken(): Promise<string> {
  const now = Date.now()
  if (cachedPortOneToken && cachedPortOneToken.expiresAt - 60_000 > now) {
    return cachedPortOneToken.value
  }

  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS)
  try {
    const res = await fetch(`${PORTONE_API}/users/getToken`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        imp_key: PORTONE_IMP_KEY,
        imp_secret: PORTONE_IMP_SECRET,
      }),
      signal: ctrl.signal,
    })
    if (!res.ok) throw new Error(`PortOne token HTTP ${res.status}`)
    const data = await res.json()
    if (data.code !== 0) {
      throw new Error(`PortOne token: ${data.message ?? 'unknown'}`)
    }
    const token = data.response.access_token as string
    const expiresAt = Number(data.response.expired_at) * 1000
    cachedPortOneToken = { value: token, expiresAt }
    return token
  } finally {
    clearTimeout(timer)
  }
}

async function portOneCancel(
  token: string,
  params: { imp_uid: string; amount: number; reason: string },
): Promise<{ cancel_amount: number; status: string }> {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS)
  try {
    const res = await fetch(`${PORTONE_API}/payments/cancel`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: token },
      body: JSON.stringify(params),
      signal: ctrl.signal,
    })
    if (!res.ok) throw new Error(`PortOne cancel HTTP ${res.status}`)
    const data = await res.json()
    if (data.code !== 0) {
      throw new Error(`PortOne cancel: ${data.message ?? 'unknown'}`)
    }
    return data.response
  } finally {
    clearTimeout(timer)
  }
}

// ---------------------------------------------------------------------------
// Request handler
// ---------------------------------------------------------------------------

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed' })
  }

  try {
    // JWT check.
    const authHeader = req.headers.get('Authorization') ?? ''
    if (!authHeader.toLowerCase().startsWith('bearer ')) {
      return jsonResponse(401, { error: 'Missing bearer token' })
    }
    const callerJwt = authHeader.slice('Bearer '.length).trim()
    if (!callerJwt) {
      return jsonResponse(401, { error: 'Empty bearer token' })
    }

    const callerClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: `Bearer ${callerJwt}` } },
    })
    const { data: userData, error: userError } =
      await callerClient.auth.getUser(callerJwt)
    if (userError || !userData?.user) {
      return jsonResponse(401, { error: 'Invalid token' })
    }
    const callerId = userData.user.id

    // Parse body.
    let body: { reservation_id?: unknown }
    try {
      body = await req.json()
    } catch {
      return jsonResponse(400, { error: 'Invalid JSON body' })
    }
    const reservationId = body.reservation_id
    if (typeof reservationId !== 'string' || reservationId.length === 0) {
      return jsonResponse(400, { error: 'Missing reservation_id' })
    }

    // Load reservation via service-role.
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const { data: reservation, error: resError } = await adminClient
      .from('reservations')
      .select(
        'id, borrower_id, lender_id, deposit, total_paid, status, payment_id',
      )
      .eq('id', reservationId)
      .maybeSingle()

    if (resError || !reservation) {
      return jsonResponse(404, { error: 'Reservation not found' })
    }

    // Only the lender can settle. The borrower's authority ends at
    // `returned`; if the borrower wants money back they go through
    // dispute → admin resolved instead.
    if (reservation.lender_id !== callerId) {
      return jsonResponse(403, { error: 'Only the lender may settle' })
    }
    if (reservation.status !== 'returned') {
      return jsonResponse(409, {
        error: `Cannot settle a reservation in status '${reservation.status}'`,
      })
    }
    if (!reservation.payment_id) {
      // Should be impossible — `paid` requires payment_id to have been
      // stamped — but guard anyway.
      return jsonResponse(409, { error: 'Reservation has no payment_id' })
    }
    if (reservation.deposit <= 0) {
      return jsonResponse(409, { error: 'Reservation has no deposit to refund' })
    }

    // Refund the deposit portion via PortOne partial cancel.
    let cancelled: { cancel_amount: number; status: string }
    try {
      const token = await getPortOneAccessToken()
      cancelled = await portOneCancel(token, {
        imp_uid: reservation.payment_id,
        amount: reservation.deposit,
        reason: `Deposit refund — reservation ${reservation.id} settled`,
      })
    } catch (e) {
      console.error('PortOne cancel failed', e)
      return jsonResponse(502, { error: 'PortOne cancel failed' })
    }

    // Advance state via the RPC. If this fails AFTER PortOne refunded
    // the deposit, we have state divergence — surface it with imp_uid
    // so Ops can mark the row manually.
    const { data: txResult, error: txError } = await adminClient.rpc(
      'transition_reservation_status',
      {
        p_reservation_id: reservation.id,
        p_target: 'settled',
        p_actor_kind: 'system',
      },
    )
    if (txError || txResult?.ok !== true) {
      console.error(
        'transition failed AFTER PortOne settled deposit — STATE DIVERGENCE',
        {
          reservationId: reservation.id,
          imp_uid: reservation.payment_id,
          refunded_amount: cancelled.cancel_amount,
          txError,
          txResult,
        },
      )
      return jsonResponse(500, {
        error:
          'Deposit refunded at PortOne but state transition failed. Contact support.',
        imp_uid: reservation.payment_id,
      })
    }

    return jsonResponse(200, {
      reservation_id: reservation.id,
      imp_uid: reservation.payment_id,
      refunded_amount: cancelled.cancel_amount,
      lender_payout_pending: reservation.total_paid - reservation.deposit,
      status: 'settled',
    })
  } catch (error) {
    console.error('settle-reservation handler error', error)
    return jsonResponse(500, { error: 'Internal server error' })
  }
})
