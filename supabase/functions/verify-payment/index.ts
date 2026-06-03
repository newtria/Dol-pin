// Supabase Edge Function: verify-payment
//
// Verifies a PortOne (Iamport) charge against our own reservations table so
// the client cannot fabricate a "paid" state. The imp_secret is held only in
// Supabase Function secrets — it must never leave the server.
//
// Required secrets (set via `supabase secrets set ...`):
//   SUPABASE_URL                 — provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY    — provided by the platform
//   PORTONE_IMP_KEY              — PortOne REST API key
//   PORTONE_IMP_SECRET           — PortOne REST API secret (DO NOT expose)
//
// Flow:
//   1. Caller must present a valid Supabase JWT.
//   2. Caller sends `{imp_uid: "<portone-transaction-id>"}`.
//   3. We exchange imp_key+imp_secret for a PortOne access token (cached).
//   4. We GET /payments/{imp_uid} on PortOne and learn the real merchant_uid,
//      amount, status, and currency of the charge.
//   5. We parse the merchant_uid (format: `dolpin_<reservationId>_<epoch>`)
//      to recover the reservation id that originally produced this charge.
//   6. We load the reservation row via the service-role client and verify:
//        - caller is a participant (borrower or lender),
//        - the amount matches `reservations.total_paid` exactly (no tampering),
//        - the payment status is PortOne's `paid`.
//   7. If the reservation is still `pending`, we advance it to `confirmed`
//      and stamp `payment_provider`, `payment_id`. Idempotent on re-call.
//   8. Return the normalized status + amount to the client.

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
    if (!res.ok) {
      throw new Error(`PortOne token HTTP ${res.status}`)
    }
    const data = await res.json()
    if (data.code !== 0) {
      throw new Error(`PortOne token: ${data.message ?? 'unknown'}`)
    }
    const token = data.response.access_token as string
    // PortOne returns `expired_at` as unix seconds.
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
  status: string // 'ready' | 'paid' | 'failed' | 'cancelled'
  currency?: string
  pg_provider?: string
  pay_method?: string
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
    if (!res.ok) {
      throw new Error(`PortOne payment HTTP ${res.status}`)
    }
    const data = await res.json()
    if (data.code !== 0) {
      throw new Error(`PortOne payment: ${data.message ?? 'unknown'}`)
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

/// Normalizes PortOne's status vocabulary to the app's PaymentStatus enum.
function normalizeStatus(portOneStatus: string): string {
  switch (portOneStatus) {
    case 'paid':
      return 'success'
    case 'ready':
      return 'pending'
    case 'failed':
    case 'cancelled':
    default:
      return 'failed'
  }
}

/// Extracts the reservation UUID from a `dolpin_<uuid>_<epoch>` merchant_uid.
/// Returns null if the string does not match the expected shape.
function extractReservationId(merchantUid: string): string | null {
  // `dolpin` prefix + UUID (no underscores inside) + `_` + epoch-ms.
  // Splitting on `_` gives [dolpin, uuid, epoch].
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

  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return jsonResponse(401, { error: 'Missing bearer token' })
  }
  const callerJwt = authHeader.slice('Bearer '.length).trim()
  if (!callerJwt) {
    return jsonResponse(401, { error: 'Empty bearer token' })
  }

  // Resolve the authenticated caller from their JWT.
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
  let body: { imp_uid?: unknown }
  try {
    body = await req.json()
  } catch {
    return jsonResponse(400, { error: 'Invalid JSON body' })
  }
  const impUid = body.imp_uid
  if (typeof impUid !== 'string' || impUid.length === 0) {
    return jsonResponse(400, { error: 'Missing imp_uid' })
  }

  // Look up payment at PortOne.
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

  // Load the reservation via the service-role client (RLS-bypassing, trusted).
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const { data: reservation, error: resError } = await adminClient
    .from('reservations')
    .select(
      'id, borrower_id, lender_id, total_paid, currency, status, payment_id',
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

  // Tampering check — the amount PortOne charged must equal what we asked
  // the user to pay when we created the reservation row.
  if (payment.amount !== reservation.total_paid) {
    console.error(
      'Amount mismatch',
      { portone: payment.amount, reservation: reservation.total_paid },
    )
    return jsonResponse(409, { error: 'Amount mismatch' })
  }

  const normalized = normalizeStatus(payment.status)

  // Advance the reservation state once, idempotently. The status column
  // is gated by a trigger (migration 017); only the `transition_reservation_status`
  // RPC may move it. We stamp the payment_provider / payment_id columns
  // directly because those evidence-fields are not gated.
  if (normalized === 'success' && reservation.status === 'pending') {
    const { error: stampError } = await adminClient
      .from('reservations')
      .update({
        payment_provider: 'portone',
        payment_id: impUid,
      })
      .eq('id', reservationId)
    if (stampError) {
      console.error('reservation stamp failed', stampError)
      return jsonResponse(500, { error: 'Failed to update reservation' })
    }
    const { data: txResult, error: txError } = await adminClient.rpc(
      'transition_reservation_status',
      {
        p_reservation_id: reservationId,
        p_target: 'paid',
        p_actor_kind: 'system',
      },
    )
    if (txError || txResult?.ok !== true) {
      console.error('reservation transition failed', { txError, txResult })
      return jsonResponse(500, { error: 'Failed to transition reservation' })
    }
  }

  return jsonResponse(200, {
    imp_uid: impUid,
    merchant_uid: payment.merchant_uid,
    status: normalized,
    amount: payment.amount,
    currency: payment.currency ?? 'KRW',
  })
})
