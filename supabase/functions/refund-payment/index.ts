// Supabase Edge Function: refund-payment
//
// Issues a PortOne full cancellation for a reservation the caller participates
// in. Matches the shape of `verify-payment` so both share the same auth +
// merchant_uid parsing model.
//
// Required secrets (set via `supabase secrets set ...`):
//   SUPABASE_URL                 — provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY    — provided by the platform
//   PORTONE_IMP_KEY              — PortOne REST API key
//   PORTONE_IMP_SECRET           — PortOne REST API secret (DO NOT expose)
//
// Flow:
//   1. Caller must present a valid Supabase JWT.
//   2. Caller sends `{imp_uid, reason?}`. Partial amounts are rejected.
//   3. We load the PortOne payment to know the reservation id + current state.
//   4. We load the reservation via service-role and verify caller participates.
//   5. We mark the reservation `refund_pending` to block pickup races.
//   6. We call PortOne `/payments/cancel` with the imp_secret.
//   7. On success, we transition the reservation to `cancelled`.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const PORTONE_IMP_KEY = Deno.env.get('PORTONE_IMP_KEY')!
const PORTONE_IMP_SECRET = Deno.env.get('PORTONE_IMP_SECRET')!

const PORTONE_API = 'https://api.iamport.kr'
const PORTONE_TIMEOUT_MS = 15_000

// ---------------------------------------------------------------------------
// PortOne access token (cached in module scope while the worker is warm)
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

interface PortOnePayment {
  imp_uid: string
  merchant_uid: string
  amount: number
  cancel_amount?: number
  status: string
  currency?: string
}

async function fetchPortOnePayment(
  impUid: string,
  token: string,
): Promise<PortOnePayment> {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS)
  try {
    const res = await fetch(
      `${PORTONE_API}/payments/${encodeURIComponent(impUid)}`,
      {
        method: 'GET',
        headers: { Authorization: token },
        signal: ctrl.signal,
      },
    )
    if (!res.ok) throw new Error(`PortOne payment HTTP ${res.status}`)
    const data = await res.json()
    if (data.code !== 0) {
      throw new Error(`PortOne payment: ${data.message ?? 'unknown'}`)
    }
    return data.response as PortOnePayment
  } finally {
    clearTimeout(timer)
  }
}

async function portOneCancel(
  token: string,
  params: { imp_uid: string; amount?: number; reason: string },
): Promise<PortOnePayment> {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS)
  try {
    const res = await fetch(`${PORTONE_API}/payments/cancel`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: token,
      },
      body: JSON.stringify(params),
      signal: ctrl.signal,
    })
    if (!res.ok) throw new Error(`PortOne cancel HTTP ${res.status}`)
    const data = await res.json()
    if (data.code !== 0) {
      throw new Error(`PortOne cancel: ${data.message ?? 'unknown'}`)
    }
    return data.response as PortOnePayment
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

function extractReservationId(merchantUid: string): string | null {
  if (!merchantUid.startsWith('dolpin_')) return null
  const parts = merchantUid.split('_')
  if (parts.length !== 3) return null
  return parts[1]
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed' })
  }

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
  const { data: userData, error: userError } = await callerClient.auth.getUser(
    callerJwt,
  )
  if (userError || !userData?.user) {
    return jsonResponse(401, { error: 'Invalid token' })
  }
  const callerId = userData.user.id

  // Parse body.
  let body: { imp_uid?: unknown; amount?: unknown; reason?: unknown }
  try {
    body = await req.json()
  } catch {
    return jsonResponse(400, { error: 'Invalid JSON body' })
  }
  const impUid = body.imp_uid
  if (typeof impUid !== 'string' || impUid.length === 0) {
    return jsonResponse(400, { error: 'Missing imp_uid' })
  }
  const refundAmount =
    typeof body.amount === 'number' && body.amount > 0
      ? Math.floor(body.amount)
      : undefined
  const reason =
    typeof body.reason === 'string' && body.reason.length > 0
      ? body.reason
      : 'User requested refund'

  // Load PortOne payment to discover reservation id and current amount.
  let payment: PortOnePayment
  try {
    const token = await getPortOneAccessToken()
    payment = await fetchPortOnePayment(impUid, token)
  } catch (e) {
    console.error('PortOne lookup failed', e)
    return jsonResponse(502, { error: 'PortOne lookup failed' })
  }

  const reservationId = extractReservationId(payment.merchant_uid)
  if (!reservationId) {
    return jsonResponse(400, { error: 'Unknown merchant_uid format' })
  }

  // Load the reservation, verify caller participates.
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const { data: reservation, error: resError } = await adminClient
    .from('reservations')
    .select(
      'id, borrower_id, lender_id, total_paid, currency, status, payment_id, payment_action, payment_action_started_at',
    )
    .eq('id', reservationId)
    .maybeSingle()

  if (resError || !reservation) {
    return jsonResponse(404, { error: 'Reservation not found' })
  }
  const isParticipant =
    reservation.borrower_id === callerId || reservation.lender_id === callerId
  if (!isParticipant) {
    return jsonResponse(403, {
      error: 'Not a participant of this reservation',
    })
  }
  if (reservation.payment_id !== impUid) {
    return jsonResponse(409, { error: 'Payment id does not match reservation' })
  }
  if (payment.amount !== reservation.total_paid) {
    return jsonResponse(409, { error: 'Amount mismatch' })
  }
  if (payment.currency && payment.currency !== reservation.currency) {
    return jsonResponse(409, { error: 'Currency mismatch' })
  }
  if (reservation.status === 'cancelled' && payment.status === 'cancelled') {
    return jsonResponse(200, {
      imp_uid: impUid,
      merchant_uid: payment.merchant_uid,
      cancel_amount: payment.cancel_amount ?? payment.amount,
      status: 'cancelled',
      reservation_status: 'cancelled',
    })
  }
  if (
    reservation.status === 'paid' &&
    reservation.payment_action === 'refund_pending' &&
    payment.status === 'cancelled'
  ) {
    const { data: retryTxResult, error: retryTxError } = await adminClient.rpc(
      'transition_reservation_status',
      {
        p_reservation_id: reservationId,
        p_target: 'cancelled',
        p_actor_kind: 'system',
        p_reason: reason,
      },
    )
    if (retryTxError || retryTxResult?.ok !== true) {
      console.error('refund retry transition failed', {
        retryTxError,
        retryTxResult,
        reservationId,
      })
      return jsonResponse(500, {
        error:
          'Payment already refunded at PortOne but reservation transition failed. Contact support.',
        imp_uid: impUid,
      })
    }
    return jsonResponse(200, {
      imp_uid: impUid,
      merchant_uid: payment.merchant_uid,
      cancel_amount: payment.cancel_amount ?? payment.amount,
      status: 'cancelled',
      reservation_status: 'cancelled',
    })
  }
  if (reservation.status !== 'paid') {
    return jsonResponse(409, {
      error: `Cannot refund a reservation in status '${reservation.status}'`,
    })
  }
  if (refundAmount !== undefined && refundAmount !== reservation.total_paid) {
    return jsonResponse(409, {
      error: 'Only full reservation refunds are automated',
    })
  }

  const { data: beginResult, error: beginError } = await adminClient.rpc(
    'begin_reservation_payment_action',
    {
      p_reservation_id: reservationId,
      p_action: 'refund_pending',
      p_payment_id: impUid,
      p_actor_id: callerId,
    },
  )
  if (beginError || beginResult?.ok !== true) {
    console.error('begin refund failed', { beginError, beginResult })
    return jsonResponse(409, {
      error: beginResult?.error ?? 'Could not start refund',
    })
  }

  // Don't try to cancel something that isn't actually paid yet, or that
  // PortOne already marked as cancelled.
  if (payment.status !== 'paid') {
    await adminClient.rpc('clear_reservation_payment_action', {
      p_reservation_id: reservationId,
      p_action: 'refund_pending',
    })
    return jsonResponse(409, {
      error: `Cannot refund a payment with status '${payment.status}'`,
    })
  }

  // Issue the cancel.
  let cancelled: PortOnePayment
  try {
    const token = await getPortOneAccessToken()
    cancelled = await portOneCancel(token, {
      imp_uid: impUid,
      amount: refundAmount,
      reason,
    })
  } catch (e) {
    console.error('PortOne cancel failed', e)
    return jsonResponse(502, {
      error:
        'PortOne cancel status is unknown. Retry will reconcile provider state before another cancel.',
    })
  }

  const { data: txResult, error: txError } = await adminClient.rpc(
    'transition_reservation_status',
    {
      p_reservation_id: reservationId,
      p_target: 'cancelled',
      p_actor_kind: 'system',
      p_reason: reason,
    },
  )
  if (txError || txResult?.ok !== true) {
    console.error('reservation transition failed after refund', {
      txError,
      txResult,
      reservationId,
    })
    return jsonResponse(500, {
      error:
        'Payment refunded at PortOne but reservation transition failed. Contact support.',
      imp_uid: impUid,
    })
  }

  return jsonResponse(200, {
    imp_uid: impUid,
    merchant_uid: payment.merchant_uid,
    cancel_amount: cancelled.cancel_amount ?? refundAmount ?? payment.amount,
    status: cancelled.status,
    reservation_status: 'cancelled',
  })
})
