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
    const body = rawBody as { imp_uid?: unknown; amount?: unknown; reason?: unknown }

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
      reservation.borrower_id === callerId ||
      reservation.lender_id === callerId
    if (!isParticipant) {
      return json(403, { error: 'Not a participant of this reservation' })
    }

    // PortOne sets payment.status='cancelled' after the FIRST cancel (even
    // partial), so a second partial refund must also be allowed against a
    // cancelled-but-not-fully-refunded payment. We compute the already-
    // refunded amount from payment.cancel_amount and require that the new
    // refund still fits inside the remaining balance.
    const alreadyRefunded = payment.cancel_amount ?? 0
    const remaining = payment.amount - alreadyRefunded
    if (remaining <= 0) {
      return json(409, { error: 'Payment is already fully refunded' })
    }
    if (payment.status !== 'paid' && payment.status !== 'cancelled') {
      return json(409, {
        error: `Cannot refund a payment with status '${payment.status}'`,
      })
    }
    if (refundAmount !== undefined && refundAmount > remaining) {
      return json(409, {
        error: `Refund amount ${refundAmount} exceeds remaining ${remaining}`,
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

    // Determine the new state from cumulative refunded amount, NOT just
    // this call's refundAmount — otherwise the final partial refund that
    // drains the balance gets mis-marked `refund_partial` forever.
    const totalRefunded = cancelled.cancel_amount ??
      alreadyRefunded + (refundAmount ?? remaining)
    const isFullyRefunded = totalRefunded >= reservation.total_paid
    const nextStatus = isFullyRefunded ? 'refunded' : 'refund_partial'

    const { error: updateError } = await adminClient
      .from('reservations')
      .update({ status: nextStatus })
      .eq('id', reservationId)
    if (updateError) {
      // PortOne already refunded the user's money. Returning 200 here
      // would tell the client the operation succeeded while the DB row
      // still reads `paid`/`confirmed` — escrow settlement would then
      // pay out a refunded reservation. Surface the divergence as 500
      // so Ops gets paged and the caller can manually reconcile.
      console.error(
        'reservation update FAILED after PortOne cancel succeeded — STATE DIVERGENCE',
        {
          reservationId,
          imp_uid: impUid,
          cancelled_amount: cancelled.cancel_amount,
          intended_status: nextStatus,
          error: updateError,
        },
      )
      return json(500, {
        error:
          'Refund processed at PortOne but reservation state update failed. Contact support with imp_uid.',
        imp_uid: impUid,
      })
    }

    return json(200, {
      imp_uid: impUid,
      merchant_uid: payment.merchant_uid,
      cancel_amount: cancelled.cancel_amount ?? refundAmount ?? payment.amount,
      status: cancelled.status,
      reservation_status: nextStatus,
    })
  } catch (error) {
    console.error('refund-payment handler error', error)
    return json(500, { error: 'Internal server error' })
  }
})
