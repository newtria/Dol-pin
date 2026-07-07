// Supabase Edge Function: resolve-dispute
//
// Operator-only path for disputed reservations. This is intentionally not
// exposed through the Flutter app because the app has no admin identity model.
// The function requires an out-of-band DOLPIN_ADMIN_ACTION_KEY header, writes
// an append-only resolution row, optionally refunds through PortOne, and then
// advances `disputed -> resolved` through the state-machine RPC.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const PORTONE_IMP_KEY = Deno.env.get('PORTONE_IMP_KEY')!
const PORTONE_IMP_SECRET = Deno.env.get('PORTONE_IMP_SECRET')!
const ADMIN_ACTION_KEY = Deno.env.get('DOLPIN_ADMIN_ACTION_KEY')

const PORTONE_API = 'https://api.iamport.kr'
const PORTONE_TIMEOUT_MS = 15_000

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
  cancel_amount?: number
  status: string
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
  params: { imp_uid: string; amount: number; reason: string },
): Promise<PortOnePayment> {
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
    return data.response as PortOnePayment
  } finally {
    clearTimeout(timer)
  }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-dolpin-admin-key',
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
  if (!ADMIN_ACTION_KEY) {
    return jsonResponse(500, { error: 'Admin action key is not configured' })
  }
  if (req.headers.get('x-dolpin-admin-key') !== ADMIN_ACTION_KEY) {
    return jsonResponse(401, { error: 'Unauthorized admin action' })
  }

  let body: {
    reservation_id?: unknown
    refund_amount?: unknown
    reason?: unknown
    idempotency_key?: unknown
  }
  try {
    body = await req.json()
  } catch {
    return jsonResponse(400, { error: 'Invalid JSON body' })
  }

  const reservationId = body.reservation_id
  const refundAmount = body.refund_amount
  const reason = body.reason
  const idempotencyKey = body.idempotency_key
  if (typeof reservationId !== 'string' || reservationId.length === 0) {
    return jsonResponse(400, { error: 'Missing reservation_id' })
  }
  if (
    typeof refundAmount !== 'number' ||
    !Number.isInteger(refundAmount) ||
    refundAmount < 0
  ) {
    return jsonResponse(400, { error: 'Invalid refund_amount' })
  }
  if (typeof reason !== 'string' || reason.trim().length === 0) {
    return jsonResponse(400, { error: 'Missing reason' })
  }
  if (typeof idempotencyKey !== 'string' || idempotencyKey.length === 0) {
    return jsonResponse(400, { error: 'Missing idempotency_key' })
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  const { data: reservation, error: resError } = await adminClient
    .from('reservations')
    .select(
      'id, total_paid, currency, status, payment_id, payment_action',
    )
    .eq('id', reservationId)
    .maybeSingle()

  if (resError || !reservation) {
    return jsonResponse(404, { error: 'Reservation not found' })
  }

  const { data: existing } = await adminClient
    .from('reservation_dispute_resolutions')
    .select('id, refund_amount, provider_refund_id, created_at')
    .eq('reservation_id', reservationId)
    .eq('idempotency_key', idempotencyKey)
    .maybeSingle()
  if (existing) {
    if (reservation.status === 'disputed') {
      const { data: retryTxResult, error: retryTxError } =
        await adminClient.rpc('transition_reservation_status', {
          p_reservation_id: reservationId,
          p_target: 'resolved',
          p_actor_kind: 'admin',
          p_reason: reason.trim(),
        })
      if (retryTxError || retryTxResult?.ok !== true) {
        console.error('dispute retry transition failed', {
          retryTxError,
          retryTxResult,
          reservationId,
          resolutionId: existing.id,
        })
        return jsonResponse(500, {
          error:
            'Dispute resolution ledger exists but reservation transition failed. Contact support.',
          resolution_id: existing.id,
        })
      }
      return jsonResponse(200, {
        already: true,
        retried_transition: true,
        status: 'resolved',
        resolution: existing,
      })
    }

    return jsonResponse(200, {
      already: true,
      status: reservation.status,
      resolution: existing,
    })
  }

  if (reservation.status !== 'disputed') {
    return jsonResponse(409, {
      error: `Cannot resolve a reservation in status '${reservation.status}'`,
    })
  }
  if (refundAmount > reservation.total_paid) {
    return jsonResponse(409, { error: 'refund_amount exceeds total_paid' })
  }
  if (!reservation.payment_id) {
    return jsonResponse(409, { error: 'Reservation has no payment_id' })
  }

  const normalizedRefundAmount = Math.floor(refundAmount)
  let providerRefundId: string | null = null
  let providerAlreadyRefunded = false

  if (
    reservation.payment_action === 'dispute_pending' &&
    normalizedRefundAmount > 0
  ) {
    try {
      const token = await getPortOneAccessToken()
      const payment = await fetchPortOnePayment(reservation.payment_id, token)
      const refundedAmount = payment.cancel_amount ?? 0
      if (refundedAmount >= normalizedRefundAmount) {
        providerAlreadyRefunded = true
        providerRefundId = payment.imp_uid
      }
    } catch (e) {
      console.error('PortOne lookup failed during dispute retry', {
        error: e,
        reservationId,
      })
      return jsonResponse(502, { error: 'PortOne lookup failed' })
    }
  }

  if (!providerAlreadyRefunded) {
    const { data: beginResult, error: beginError } = await adminClient.rpc(
      'begin_reservation_payment_action',
      {
        p_reservation_id: reservationId,
        p_action: 'dispute_pending',
        p_payment_id: reservation.payment_id,
        p_actor_id: null,
      },
    )
    if (beginError || beginResult?.ok !== true) {
      console.error('begin dispute resolution failed', {
        beginError,
        beginResult,
      })
      return jsonResponse(409, {
        error: beginResult?.error ?? 'Could not start dispute resolution',
      })
    }
  }

  if (normalizedRefundAmount > 0 && !providerAlreadyRefunded) {
    try {
      const token = await getPortOneAccessToken()
      const refunded = await portOneCancel(token, {
        imp_uid: reservation.payment_id,
        amount: normalizedRefundAmount,
        reason: reason.trim(),
      })
      providerRefundId = refunded.imp_uid
    } catch (e) {
      console.error('PortOne dispute refund failed', {
        error: e,
        reservationId,
      })
      return jsonResponse(502, {
        error:
          'PortOne dispute refund status is unknown. Retry will reconcile provider state before another cancel.',
      })
    }
  }

  const { data: resolution, error: resolutionError } = await adminClient
    .from('reservation_dispute_resolutions')
    .insert({
      reservation_id: reservationId,
      refund_amount: normalizedRefundAmount,
      reason: reason.trim(),
      idempotency_key: idempotencyKey,
      provider_refund_id: providerRefundId,
    })
    .select()
    .single()
  if (resolutionError || !resolution) {
    console.error('dispute resolution ledger insert failed', {
      resolutionError,
      reservationId,
    })
    if (normalizedRefundAmount === 0) {
      await adminClient.rpc('clear_reservation_payment_action', {
        p_reservation_id: reservationId,
        p_action: 'dispute_pending',
      })
    }
    return jsonResponse(500, { error: 'Could not write resolution ledger' })
  }

  const { data: txResult, error: txError } = await adminClient.rpc(
    'transition_reservation_status',
    {
      p_reservation_id: reservationId,
      p_target: 'resolved',
      p_actor_kind: 'admin',
      p_reason: reason.trim(),
    },
  )
  if (txError || txResult?.ok !== true) {
    console.error('dispute transition failed after ledger/provider action', {
      txError,
      txResult,
      reservationId,
      resolutionId: resolution.id,
    })
    return jsonResponse(500, {
      error:
        'Dispute resolution ledger was written but reservation transition failed. Contact support.',
      resolution_id: resolution.id,
    })
  }

  return jsonResponse(200, {
    reservation_id: reservationId,
    refund_amount: normalizedRefundAmount,
    idempotency_key: idempotencyKey,
    provider_refund_id: providerRefundId,
    status: 'resolved',
    resolution_id: resolution.id,
  })
})
