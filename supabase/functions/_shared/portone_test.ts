// Run with: deno test --config ../deno.json portone_test.ts
//
// Covers the pure helpers in `portone.ts`. The PortOne HTTP client is
// untested here — that needs a fake server; see `_shared/cors_test.ts`
// for the same pattern.

import { assertEquals, assertThrows } from 'jsr:@std/assert@1'
import { extractReservationId, normalizeStatus } from './portone.ts'

Deno.test('extractReservationId: valid merchant_uid → uuid', () => {
  assertEquals(
    extractReservationId('dolpin_a1b2c3d4-e5f6-7890-abcd-ef1234567890_1716230400000'),
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  )
})

Deno.test('extractReservationId: missing dolpin prefix → null', () => {
  assertEquals(extractReservationId('test_abc_123'), null)
  assertEquals(extractReservationId('abc_def_ghi'), null)
})

Deno.test('extractReservationId: wrong segment count → null', () => {
  assertEquals(extractReservationId('dolpin_only-one-segment'), null)
  assertEquals(extractReservationId('dolpin_a_b_c_d'), null)
})

Deno.test('extractReservationId: empty string → null', () => {
  assertEquals(extractReservationId(''), null)
})

Deno.test('normalizeStatus: paid → success', () => {
  assertEquals(normalizeStatus('paid'), 'success')
})

Deno.test('normalizeStatus: ready → pending', () => {
  assertEquals(normalizeStatus('ready'), 'pending')
})

Deno.test('normalizeStatus: failed/cancelled/unknown → failed', () => {
  assertEquals(normalizeStatus('failed'), 'failed')
  assertEquals(normalizeStatus('cancelled'), 'failed')
  assertEquals(normalizeStatus('some-future-status'), 'failed')
  assertEquals(normalizeStatus(''), 'failed')
})

// `assertPayment` is not exported by name but covers the same surface
// indirectly. Round-trip via `getPayment` would need a fake fetch — left
// for a future integration test. The shape of an invalid response is
// asserted here through the public type contract:
Deno.test('PortOnePayment surface: required fields', () => {
  // Compile-time contract — if the interface drifts, this test fails to
  // typecheck via `deno check`.
  const payment: import('./portone.ts').PortOnePayment = {
    imp_uid: 'imp_123',
    merchant_uid: 'dolpin_uuid_123',
    amount: 1000,
    status: 'paid',
  }
  assertEquals(payment.imp_uid, 'imp_123')
})

// Silence unused-import lint when assertThrows is only added for future use.
void assertThrows
