import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('payment edge function contracts', () {
    late String verifyPayment;
    late String refundPayment;
    late String settleReservation;
    late String resolveDispute;
    late String reservationActions;

    setUpAll(() {
      verifyPayment = File(
        'supabase/functions/verify-payment/index.ts',
      ).readAsStringSync()._quoteNormalized();
      refundPayment = File(
        'supabase/functions/refund-payment/index.ts',
      ).readAsStringSync()._quoteNormalized();
      settleReservation = File(
        'supabase/functions/settle-reservation/index.ts',
      ).readAsStringSync()._quoteNormalized();
      resolveDispute = File(
        'supabase/functions/resolve-dispute/index.ts',
      ).readAsStringSync()._quoteNormalized();
      reservationActions = File(
        'supabase/functions/_shared/reservation-actions.ts',
      ).readAsStringSync()._quoteNormalized();
    });

    test(
      'verification binds exactly one PortOne imp_uid to the reservation',
      () {
        expect(verifyPayment, contains('status, payment_id'));
        expect(
          verifyPayment,
          contains(
            'reservation.payment_id && reservation.payment_id !== impUid',
          ),
        );
        expect(verifyPayment, contains('mark_reservation_paid'));
        expect(verifyPayment, isNot(contains("p_target: 'paid'")));
        expect(verifyPayment, contains('payment_attempt_merchant_uid'));
        expect(verifyPayment, contains('Captured payment was refunded'));
        expect(verifyPayment, contains('refundCapturedVerificationPayment'));
        expect(
          verifyPayment,
          contains('auto-refund failed after verification rejection'),
        );
        expect(
          verifyPayment,
          contains('Merchant UID does not match reservation attempt'),
        );
      },
    );

    test('refund verifies the reservation payment id before money moves', () {
      expect(refundPayment, contains('status, payment_id, payment_action'));
      expect(refundPayment, contains('payment_action_started_at'));
      expect(refundPayment, contains('reservation.payment_id !== impUid'));
      expect(
        refundPayment,
        contains('payment.amount !== reservation.total_paid'),
      );
      expect(
        refundPayment,
        contains(
          'payment.currency && payment.currency !== reservation.currency',
        ),
      );
      expect(
        refundPayment,
        contains('Only full reservation refunds are automated'),
      );
    });

    test(
      'refund opens a pending action before PortOne cancel and keeps ambiguous provider failures locked',
      () {
        final begin = refundPayment.indexOf('beginReservationPaymentAction');
        final cancel = refundPayment.indexOf('cancelled = await portOneCancel');
        final clear = refundPayment.indexOf('clearReservationPaymentAction');

        expect(begin, greaterThanOrEqualTo(0));
        expect(cancel, greaterThan(begin));
        expect(clear, greaterThan(begin));
        expect(
          reservationActions,
          contains("'begin_reservation_payment_action'"),
        );
        expect(
          reservationActions,
          contains("'clear_reservation_payment_action'"),
        );
        expect(
          refundPayment,
          contains(
            'Payment refunded at PortOne but reservation transition failed',
          ),
        );
        expect(
          refundPayment,
          contains(
            'Retry will reconcile provider state before another cancel.',
          ),
        );

        final providerCatch = refundPayment.substring(
          refundPayment.indexOf("console.error('PortOne cancel failed'"),
          refundPayment.indexOf('const { data: txResult'),
        );
        expect(providerCatch, isNot(contains('clearReservationPaymentAction')));
      },
    );

    test('settlement opens a pending action before partial deposit refund', () {
      final begin = settleReservation.indexOf('beginReservationPaymentAction');
      final cancel = settleReservation.indexOf(
        'cancelled = await portOneCancel',
      );

      expect(begin, greaterThanOrEqualTo(0));
      expect(cancel, greaterThan(begin));
      expect(settleReservation, contains("action: 'settle_pending'"));
      expect(settleReservation, contains('clearReservationPaymentAction'));
      expect(
        reservationActions,
        contains("'begin_reservation_payment_action'"),
      );
      expect(
        settleReservation,
        contains('Deposit refunded at PortOne but state transition failed'),
      );
      expect(
        settleReservation,
        contains('Retry will reconcile provider state before another cancel.'),
      );

      final providerCatch = settleReservation.substring(
        settleReservation.indexOf("console.error('PortOne cancel failed'"),
        settleReservation.indexOf('// Advance state via the RPC.'),
      );
      expect(providerCatch, isNot(contains('clearReservationPaymentAction')));
    });

    test(
      'settlement reconciles pending provider refunds and supports zero deposit',
      () {
        expect(settleReservation, contains('fetchPortOnePayment'));
        expect(
          settleReservation,
          contains("reservation.payment_action === 'settle_pending'"),
        );
        expect(
          settleReservation,
          contains('refundedAmount < reservation.deposit'),
        );
        expect(settleReservation, contains('actionIsStale'));
        expect(
          reservationActions,
          contains('PAYMENT_ACTION_STALE_MS = 10 * 60_000'),
        );
        expect(
          reservationActions,
          contains('now - actionStartedAt > PAYMENT_ACTION_STALE_MS'),
        );
        expect(settleReservation, contains('reservation.deposit === 0'));
        expect(
          settleReservation,
          contains("cancelled = { cancel_amount: 0, status: 'settled' }"),
        );
      },
    );

    test('operator dispute resolution is secret-gated and ledgered', () {
      expect(resolveDispute, contains('DOLPIN_ADMIN_ACTION_KEY'));
      expect(resolveDispute, contains('x-dolpin-admin-key'));
      expect(resolveDispute, contains('reservation_dispute_resolutions'));
      expect(resolveDispute, contains("reservation.status !== 'disputed'"));
      expect(resolveDispute, contains('refundAmount > reservation.total_paid'));
      expect(resolveDispute, contains("target: 'resolved'"));
      expect(resolveDispute, contains("actorKind: 'admin'"));
      expect(resolveDispute, contains('idempotency_key'));
      expect(resolveDispute, contains('retried_transition'));
      expect(resolveDispute, contains('providerAlreadyRefunded'));
      expect(
        resolveDispute,
        contains('Retry will reconcile provider state before another cancel.'),
      );

      final existingBranch = resolveDispute.substring(
        resolveDispute.indexOf('if (existing)'),
        resolveDispute.indexOf("if (reservation.status !== 'disputed')"),
      );
      expect(existingBranch, contains('transitionReservationStatus'));
      expect(reservationActions, contains("'transition_reservation_status'"));

      final providerCatch = resolveDispute.substring(
        resolveDispute.indexOf("console.error('PortOne dispute refund failed'"),
        resolveDispute.indexOf('const { data: resolution'),
      );
      expect(providerCatch, isNot(contains('clearReservationPaymentAction')));
    });
  });
}

extension on String {
  String _quoteNormalized() => replaceAll('"', "'");
}
