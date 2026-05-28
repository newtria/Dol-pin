// Supabase Edge Function: verify-payment
//
// Verifies a PortOne (Iamport) charge against our own reservations table so
// the client cannot fabricate a "paid" state. The imp_secret lives only in
// `_shared/portone.ts` module scope — never exposed to callers.
//
// Flow:
//   1. Caller JWT must resolve to a Supabase user.
//   2. Caller sends `{imp_uid}`.
//   3. We fetch the PortOne payment, recover the reservation id from
//      `merchant_uid`, and confirm the caller participates.
//   4. Amount must match `reservations.total_paid` (no tampering).
//   5. If still `pending`, advance to `confirmed` and stamp the provider id.
//      Idempotent on re-call.

import { createClient } from '@supabase/supabase-js'
import { requireUser } from '../_shared/auth.ts'
import { jsonResponse, preflightResponse } from '../_shared/cors.ts'
import {
  extractReservationId,
  getPayment,
  normalizeStatus,
  PortOnePayment,
} from '../_shared/portone.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return preflightResponse(req)
  const json = (status: number, body: unknown) => jsonResponse(req, status, body)

  try {
    if (req.method !== 'POST') {
      return json(405, { error: 'Method not allowed' })
    }

    const auth = await requireUser(req)
    if (!auth.ok) return json(auth.status, { error: auth.error })
    const callerId = auth.userId

    let rawBody: unknown
    try {
      rawBody = await req.json()
    } catch {
      return json(400, { error: 'Invalid JSON body' })
    }
    if (!rawBody || typeof rawBody !== 'object' || Array.isArray(rawBody)) {
      return json(400, { error: 'Body must be a JSON object' })
    }
    const impUid = (rawBody as { imp_uid?: unknown }).imp_uid
    if (typeof impUid !== 'string' || impUid.length === 0) {
      return json(400, { error: 'Missing imp_uid' })
    }

    let payment: PortOnePayment
    try {
      payment = await getPayment(impUid)
    } catch (e) {
      console.error('PortOne lookup failed', e)
      return json(502, { error: 'PortOne lookup failed' })
    }

    const reservationId = extractReservationId(payment.merchant_uid)
    if (!reservationId) {
      return json(400, { error: 'Unknown merchant_uid format' })
    }

    // Service-role read — bypasses RLS so we can verify participation
    // without granting the caller direct read on the row.
    const { data: reservation, error: resError } = await adminClient
      .from('reservations')
      .select(
        'id, borrower_id, lender_id, total_paid, currency, status, payment_id',
      )
      .eq('id', reservationId)
      .maybeSingle()

    if (resError || !reservation) {
      return json(404, { error: 'Reservation not found' })
    }

    const isParticipant =
      reservation.borrower_id === callerId ||
      reservation.lender_id === callerId
    if (!isParticipant) {
      return json(403, { error: 'Not a participant of this reservation' })
    }

    // Tampering check — the amount PortOne charged must equal what we asked
    // the user to pay when we created the reservation row.
    if (payment.amount !== reservation.total_paid) {
      console.error(
        'Amount mismatch',
        { portone: payment.amount, reservation: reservation.total_paid },
      )
      return json(409, { error: 'Amount mismatch' })
    }

    const normalized = normalizeStatus(payment.status)

    // Advance the reservation state once, idempotently.
    if (normalized === 'success' && reservation.status === 'pending') {
      const { error: updateError } = await adminClient
        .from('reservations')
        .update({
          payment_provider: 'portone',
          payment_id: impUid,
          status: 'confirmed',
        })
        .eq('id', reservationId)
      if (updateError) {
        console.error('reservation update failed', updateError)
        return json(500, { error: 'Failed to update reservation' })
      }
    }

    return json(200, {
      imp_uid: impUid,
      merchant_uid: payment.merchant_uid,
      status: normalized,
      amount: payment.amount,
      currency: payment.currency ?? 'KRW',
    })
  } catch (error) {
    console.error('verify-payment handler error', error)
    return json(500, { error: 'Internal server error' })
  }
})
