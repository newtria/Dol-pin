// Supabase Edge Function: refund-payment
//
// Issues a PortOne cancellation (full or partial refund) for a reservation
// the caller participates in. Matches the shape of `verify-payment` so both
// share the same auth + merchant_uid parsing model.
//
// Required secrets (set via `supabase secrets set ...`):
//   SUPABASE_URL                 — provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY    — provided by the platform
//   PORTONE_IMP_KEY              — PortOne REST API key
//   PORTONE_IMP_SECRET           — PortOne REST API secret (DO NOT expose)
//
// Flow:
//   1. Caller must present a valid Supabase JWT.
//   2. Caller sends `{imp_uid, amount?, reason?}`.
//   3. We load the PortOne payment to know the reservation id + current state.
//   4. We load the reservation via service-role and verify caller participates.
//   5. We call PortOne `/payments/cancel` with the imp_secret.
//   6. On success, we update the reservation row to reflect the refund.

import { createClient } from '@supabase/supabase-js'
import { requireUser } from '../_shared/auth.ts'
import { jsonResponse, preflightResponse } from '../_shared/cors.ts'

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

function extractReservationId(merchantUid: string): string | null {
  if (!merchantUid.startsWith('dolpin_')) return null
  const parts = merchantUid.split('_')
  if (parts.length !== 3) return null
  return parts[1]
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return preflightResponse(req)
  }
  if (req.method !== 'POST') {
    return jsonResponse(req, 405, { error: 'Method not allowed' })
  }

  const auth = await requireUser(req)
  if (!auth.ok) {
    return jsonResponse(req, auth.status, { error: auth.error })
  }
  const callerId = auth.userId

  // Parse body.
  let body: { imp_uid?: unknown; amount?: unknown; reason?: unknown }
  try {
    body = await req.json()
  } catch {
    return jsonResponse(req, 400, { error: 'Invalid JSON body' })
  }
  const impUid = body.imp_uid
  if (typeof impUid !== 'string' || impUid.length === 0) {
    return jsonResponse(req, 400, { error: 'Missing imp_uid' })
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
    return jsonResponse(req, 502, { error: 'PortOne lookup failed' })
  }

  const reservationId = extractReservationId(payment.merchant_uid)
  if (!reservationId) {
    return jsonResponse(req, 400, { error: 'Unknown merchant_uid format' })
  }

  // Load the reservation, verify caller participates.
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const { data: reservation, error: resError } = await adminClient
    .from('reservations')
    .select('id, borrower_id, lender_id, total_paid, status')
    .eq('id', reservationId)
    .maybeSingle()

  if (resError || !reservation) {
    return jsonResponse(req, 404, { error: 'Reservation not found' })
  }
  const isParticipant =
    reservation.borrower_id === callerId || reservation.lender_id === callerId
  if (!isParticipant) {
    return jsonResponse(req, 403, {
      error: 'Not a participant of this reservation',
    })
  }

  // Don't try to cancel something that isn't actually paid yet, or that
  // PortOne already marked as cancelled.
  if (payment.status !== 'paid') {
    return jsonResponse(req, 409, {
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
    return jsonResponse(req, 502, { error: 'PortOne cancel failed' })
  }

  // Reflect the refund in our own reservation state. If a partial refund,
  // keep status as 'refund_pending' for a human to resolve; if full, mark
  // 'refunded'. These status values should match the reservation state
  // machine once it lands; for now the column is a free-form text.
  const isFullRefund =
    refundAmount === undefined || refundAmount >= reservation.total_paid
  const nextStatus = isFullRefund ? 'refunded' : 'refund_partial'

  const { error: updateError } = await adminClient
    .from('reservations')
    .update({ status: nextStatus })
    .eq('id', reservationId)
  if (updateError) {
    console.error('reservation update failed', updateError)
    // PortOne already cancelled — don't signal total failure.
  }

  return jsonResponse(req, 200, {
    imp_uid: impUid,
    merchant_uid: payment.merchant_uid,
    cancel_amount: cancelled.cancel_amount ?? refundAmount ?? payment.amount,
    status: cancelled.status,
  })
})
