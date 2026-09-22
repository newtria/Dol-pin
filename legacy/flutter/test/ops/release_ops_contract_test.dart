import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release ops contracts', () {
    late String preflight;
    late String disputeCli;
    late String runbook;
    late String migration;
    late String resolveDispute;
    late String reservationActions;
    late String envExample;
    late String readme;
    late String supabaseConfig;
    late String ciWorkflow;
    late String publicProfilesMigration;
    late String reservationCheckoutController;

    setUpAll(() {
      preflight = File('scripts/release-preflight.mjs').readAsStringSync();
      disputeCli = File('scripts/resolve-dispute.mjs').readAsStringSync();
      runbook = File('docs/ops-runbook.md').readAsStringSync();
      migration = File(
        'supabase/migrations/017_reservation_state_machine.sql',
      ).readAsStringSync();
      resolveDispute = File(
        'supabase/functions/resolve-dispute/index.ts',
      ).readAsStringSync()._quoteNormalized();
      reservationActions = File(
        'supabase/functions/_shared/reservation-actions.ts',
      ).readAsStringSync()._quoteNormalized();
      envExample = File('.env.example').readAsStringSync();
      readme = File('README.md').readAsStringSync();
      supabaseConfig = File('supabase/config.toml').readAsStringSync();
      ciWorkflow = File('.github/workflows/ci.yml').readAsStringSync();
      publicProfilesMigration = File(
        'supabase/migrations/018_public_user_profiles.sql',
      ).readAsStringSync();
      reservationCheckoutController = File(
        'lib/features/reservation/application/reservation_checkout_controller.dart',
      ).readAsStringSync();
    });

    test('preflight covers release app env and Edge secrets', () {
      for (final key in [
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'PORTONE_IMP_CODE',
        'SENTRY_DSN',
        'SUPABASE_SERVICE_ROLE_KEY',
        'PORTONE_IMP_KEY',
        'PORTONE_IMP_SECRET',
        'DOLPIN_ADMIN_ACTION_KEY',
        'GEMINI_API_KEY',
        'FCM_PROJECT_ID',
        'FCM_SERVICE_ACCOUNT_JSON',
      ]) {
        expect(preflight, contains(key));
        expect(envExample, contains('$key='));
      }
      expect(preflight, contains('--structure-only'));
      expect(preflight, contains('release preflight: ok'));
      expect(preflight, contains('node syntax check'));
      expect(preflight, contains('deno check'));
      expect(runbook, contains('node scripts/release-preflight.mjs'));
      expect(preflight, contains('supabase/functions/gemini-analyze/index.ts'));
      expect(
        preflight,
        contains('supabase/functions/push-notification/index.ts'),
      );
    });

    test('CI checks release structure and every Edge Function', () {
      expect(ciWorkflow, contains('denoland/setup-deno'));
      expect(
        ciWorkflow,
        contains('node scripts/release-preflight.mjs --structure-only'),
      );
      expect(ciWorkflow, contains('for fn in supabase/functions/*/index.ts'));
      expect(ciWorkflow, contains('deno check "\$fn"'));
    });

    test(
      'public profile reads use a sanitized view instead of users table RLS',
      () {
        expect(publicProfilesMigration, contains('public_user_profiles'));
        expect(
          publicProfilesMigration,
          contains(
            'DROP POLICY IF EXISTS "Public can read active user profiles"',
          ),
        );
        expect(
          publicProfilesMigration,
          contains(
            'DROP POLICY IF EXISTS "Public can read active lenders and reservation partners"',
          ),
        );
        final viewSql = publicProfilesMigration.substring(
          publicProfilesMigration.indexOf('CREATE OR REPLACE VIEW'),
        );
        expect(viewSql, isNot(contains('phone')));
        expect(viewSql, isNot(contains('fcm_token')));
        expect(viewSql, isNot(contains('fav_groups')));
      },
    );

    test(
      'successful payment callback without provider id does not cancel hold',
      () {
        expect(
          reservationCheckoutController,
          contains('paymentResult.status != PaymentStatus.success'),
        );
        expect(
          reservationCheckoutController,
          contains('impUid == null || impUid.isEmpty'),
        );
        final missingImpUidBranch = reservationCheckoutController.substring(
          reservationCheckoutController.indexOf(
            'impUid == null || impUid.isEmpty',
          ),
          reservationCheckoutController.indexOf(
            'final gateway =',
            reservationCheckoutController.indexOf(
              'impUid == null || impUid.isEmpty',
            ),
          ),
        );
        expect(missingImpUidBranch, isNot(contains('.cancel(reservation.id)')));
      },
    );

    test('resolve-dispute gateway auth matches the operator CLI contract', () {
      expect(supabaseConfig, contains('[functions.resolve-dispute]'));
      expect(supabaseConfig, contains('verify_jwt = false'));
      expect(disputeCli, contains('x-dolpin-admin-key'));
      expect(disputeCli, isNot(contains('Authorization')));
      expect(runbook, contains('verify_jwt = false'));
    });

    test('manual dispute CLI is dry-run by default and confirm-gated', () {
      expect(disputeCli, contains('dryRun'));
      expect(disputeCli, contains("!confirm"));
      expect(disputeCli, contains('real calls require --idempotency-key'));
      expect(disputeCli, contains('DOLPIN_ADMIN_ACTION_KEY'));
      expect(disputeCli, contains('/functions/v1/resolve-dispute'));
      expect(runbook, contains('node scripts/resolve-dispute.mjs'));
      expect(runbook, contains('--confirm'));
    });

    test('dispute resolution is protected by the shared payment-action lock', () {
      expect(migration, contains('dispute_pending'));
      expect(
        migration,
        contains(
          "payment_action IN ('refund_pending', 'settle_pending', 'dispute_pending')",
        ),
      );
      expect(resolveDispute, contains('beginReservationPaymentAction'));
      expect(resolveDispute, contains("action: 'dispute_pending'"));
      expect(resolveDispute, contains('clearReservationPaymentAction'));
      expect(
        reservationActions,
        contains("'begin_reservation_payment_action'"),
      );
      expect(
        reservationActions,
        contains("'clear_reservation_payment_action'"),
      );
      expect(resolveDispute, contains('fetchPortOnePayment'));
      expect(resolveDispute, contains('providerAlreadyRefunded'));
      expect(resolveDispute, contains('retried_transition'));
      expect(
        resolveDispute,
        contains('Retry will reconcile provider state before another cancel.'),
      );

      final begin = resolveDispute.indexOf('beginReservationPaymentAction');
      final cancel = resolveDispute.indexOf('await portOneCancel');
      expect(begin, greaterThanOrEqualTo(0));
      expect(cancel, greaterThan(begin));
    });

    test('README keeps launch claims aligned with implemented scope', () {
      expect(readme, contains('KRW'));
      expect(readme, contains('운영자 분쟁 해결'));
      expect(readme, isNot(contains('대여 전/후 사진 비교')));
      expect(readme, isNot(contains('Phase 1: Korea + Indonesia + Japan')));
    });
  });
}

extension on String {
  String _quoteNormalized() => replaceAll('"', "'");
}
