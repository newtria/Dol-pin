// Supabase Edge Function: refund-payment
//
// Issues a PortOne cancellation (full or partial refund) for a reservation
// the caller participates in. The imp_secret stays in `_shared/portone.ts`.
//
// Flow:
//   1. Caller JWT must resolve to a Supabase user.
//   2. Caller sends `{imp_uid, amount?, reason?}`.
//   3. We GET the PortOne payment to learn the reservation id + state.
//   4. We verify the caller participates in that reservation.
//   5. We POST `/payments/cancel`. On success, mark the reservation
//      `refunded` (full) or `refund_partial` (partial).

import { createClient } from '@supabase/supabase-js'
import { requireUser } from '../_shared/auth.ts'
import { jsonResponse, preflightResponse } from '../_shared/cors.ts'
import {
  cancelPayment,
  extractReservationId,
  getPayment,
  PortOnePayment,
} from '../_shared/portone.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return preflightResponse(req)
  if (req.method !== 'POST') {
    return jsonResponse(req, 405, { error: 'Method not allowed' })
  }
  const json = (status: number, body: unknown) => jsonResponse(req, status, body)

  const auth = await requireUser(req)
  if (!auth.ok) return json(auth.status, { error: auth.error })
  const callerId = auth.userId

  let body: { imp_uid?: unknown; amount?: unknown; reason?: unknown }
  try {
    body = await req.json()
  } catch {
    return json(400, { error: 'Invalid JSON body' })
  }
  const impUid = body.imp_uid
  if (typeof impUid !== 'string' || impUid.length === 0) {
    return json(400, { error: 'Missing imp_uid' })
  }
  const refundAmount =
    typeof body.amount === 'number' && body.amount > 0
      ? Math.floor(body.amount)
      : undefined
  const reason =
    typeof body.reason === 'string' && body.reason.length > 0
      ? body.reason
      : 'User requested refund'

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

  const { data: reservation, error: resError } = await adminClient
    .from('reservations')
    .select('id, borrower_id, lender_id, total_paid, status')
    .eq('id', reservationId)
    .maybeSingle()

  if (resError || !reservation) {
    return json(404, { error: 'Reservation not found' })
  }
  const isParticipant =
    reservation.borrower_id === callerId || reservation.lender_id === callerId
  if (!isParticipant) {
    return json(403, { error: 'Not a participant of this reservation' })
  }

  // Refusing anything that isn't currently `paid` keeps the operation
  // idempotent against double-clicks and surfaces PortOne-side state drift
  // (already-cancelled, never-confirmed) as a 409 rather than a silent retry.
  if (payment.status !== 'paid') {
    return json(409, {
      error: `Cannot refund a payment with status '${payment.status}'`,
    })
  }

  let cancelled: PortOnePayment
  try {
    cancelled = await cancelPayment({
      imp_uid: impUid,
      amount: refundAmount,
      reason,
    })
  } catch (e) {
    console.error('PortOne cancel failed', e)
    return json(502, { error: 'PortOne cancel failed' })
  }

  // Reservation status column is free-form text until the escrow state
  // machine lands (see TODO.md). `refunded` / `refund_partial` are the
  // values the Flutter side already reads.
  const isFullRefund =
    refundAmount === undefined || refundAmount >= reservation.total_paid
  const nextStatus = isFullRefund ? 'refunded' : 'refund_partial'

  const { error: updateError } = await adminClient
    .from('reservations')
    .update({ status: nextStatus })
    .eq('id', reservationId)
  if (updateError) {
    // PortOne already cancelled — don't signal total failure.
    console.error('reservation update failed', updateError)
  }

  return json(200, {
    imp_uid: impUid,
    merchant_uid: payment.merchant_uid,
    cancel_amount: cancelled.cancel_amount ?? refundAmount ?? payment.amount,
    status: cancelled.status,
  })
})
