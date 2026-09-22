import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dolpin/core/constants/enums.dart';
import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/repositories/reservation_repository.dart';

import '../../helpers/postgrest_fakes.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder<PostgrestList> mockFilterBuilder;
  late ReservationRepository repository;

  final sampleReservation = {
    'id': 'res-1',
    'item_id': 'item-1',
    'borrower_id': 'user-2',
    'lender_id': 'user-1',
    'rental_date': '2026-04-01T00:00:00.000Z',
    'return_date': '2026-04-03T00:00:00.000Z',
    'rental_fee': 10000,
    'deposit': 50000,
    'total_paid': 60000,
    'currency': 'KRW',
    'status': 'pending',
    'created_at': '2026-03-28T12:00:00.000Z',
  };

  setUp(() {
    mockClient = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder<PostgrestList>();
    when(
      () => mockClient.from('reservations'),
    ).thenAnswer((_) => mockQueryBuilder);
    repository = ReservationRepository(mockClient);
  });

  group('create', () {
    test('returns Success with ReservationModel', () async {
      final input = {
        'item_id': 'item-1',
        'borrower_id': 'user-2',
        'lender_id': 'user-1',
        'rental_date': '2026-04-01T00:00:00.000Z',
        'return_date': '2026-04-03T00:00:00.000Z',
        'rental_fee': 10000,
        'deposit': 50000,
        'total_paid': 60000,
        'currency': 'KRW',
      };
      when(
        () => mockQueryBuilder.insert(input),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.select(),
      ).thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.single()).thenAnswer(
        (_) => FakePostgrestResponse<PostgrestMap>(sampleReservation),
      );

      final result = await repository.create(input);

      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'res-1');
      expect(result.value.borrowerId, 'user-2');
      expect(result.value.totalPaid, 60000);
    });

    test('returns Fail on insert error', () async {
      when(
        () => mockQueryBuilder.insert(any()),
      ).thenThrow(PostgrestException(message: 'insert failed', code: '500'));

      final result = await repository.create({'item_id': 'item-1'});

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('getById', () {
    test('returns Success with reservation data', () async {
      when(
        () => mockQueryBuilder.select(),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq('id', 'res-1'),
      ).thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.single()).thenAnswer(
        (_) => FakePostgrestResponse<PostgrestMap>(sampleReservation),
      );

      final result = await repository.getById('res-1');

      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'res-1');
      expect(result.value.status, 'pending');
    });

    test('returns Fail with NotFoundFailure when not found', () async {
      when(
        () => mockQueryBuilder.select(),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq('id', 'nonexistent'),
      ).thenThrow(PostgrestException(message: 'not found', code: 'PGRST116'));

      final result = await repository.getById('nonexistent');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });

  group('transition', () {
    test('returns resulting status from transition RPC', () async {
      when(
        () => mockClient.rpc(
          'transition_reservation_status',
          params: {
            'p_reservation_id': 'res-1',
            'p_target': 'picked_up',
            'p_reason': null,
          },
        ),
      ).thenAnswer(
        (_) =>
            FakePostgrestResponse<dynamic>({'ok': true, 'status': 'picked_up'}),
      );

      final result = await repository.transition(
        reservationId: 'res-1',
        target: ReservationStatus.pickedUp,
      );

      expect(result.isSuccess, isTrue);
      expect(result.value, ReservationStatus.pickedUp);
    });

    test('maps rejected transition RPC rows to ValidationFailure', () async {
      when(
        () => mockClient.rpc(
          'transition_reservation_status',
          params: {
            'p_reservation_id': 'res-1',
            'p_target': 'cancelled',
            'p_reason': 'too late',
          },
        ),
      ).thenAnswer(
        (_) => FakePostgrestResponse<dynamic>({
          'ok': false,
          'error': 'Transition rejected',
        }),
      );

      final result = await repository.transition(
        reservationId: 'res-1',
        target: ReservationStatus.cancelled,
        reason: 'too late',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());
    });
  });

  group('confirmPickup', () {
    test('delegates pickup confirmation to transition RPC', () async {
      when(
        () => mockClient.rpc(
          'transition_reservation_status',
          params: {
            'p_reservation_id': 'res-1',
            'p_target': 'picked_up',
            'p_reason': null,
          },
        ),
      ).thenAnswer(
        (_) =>
            FakePostgrestResponse<dynamic>({'ok': true, 'status': 'picked_up'}),
      );

      final result = await repository.confirmPickup('res-1');

      expect(result.isSuccess, isTrue);
      expect(result.value, ReservationStatus.pickedUp);
    });
  });

  group('confirmReturn', () {
    test('returns ValidationFailure without return photo', () async {
      final result = await repository.confirmReturn('res-1');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());
    });

    test('binds return photo through confirm return RPC', () async {
      when(
        () => mockClient.rpc(
          'confirm_reservation_return',
          params: {
            'p_reservation_id': 'res-1',
            'p_return_photo': 'https://example.com/return.jpg',
          },
        ),
      ).thenAnswer(
        (_) =>
            FakePostgrestResponse<dynamic>({'ok': true, 'status': 'returned'}),
      );

      final result = await repository.confirmReturn(
        'res-1',
        returnPhoto: 'https://example.com/return.jpg',
      );

      expect(result.isSuccess, isTrue);
      expect(result.value, ReservationStatus.returned);
    });
  });

  group('reservation SQL contract', () {
    late String migration;

    setUpAll(() {
      migration = File(
        'supabase/migrations/017_reservation_state_machine.sql',
      ).readAsStringSync();
    });

    test('blocks stale client-owned reservation writes', () {
      expect(
        migration,
        contains('DROP POLICY IF EXISTS "Borrowers can create reservations"'),
      );
      expect(
        migration,
        contains(
          'DROP POLICY IF EXISTS "Participants can update own reservations"',
        ),
      );
    });

    test(
      'creates reservation intents server-side from locked rental item data',
      () {
        expect(
          migration,
          contains('CREATE OR REPLACE FUNCTION create_reservation_intent'),
        );
        expect(migration, contains('FROM rental_items'));
        expect(migration, contains('FOR UPDATE'));
        expect(migration, contains('v_item.daily_price * v_days'));
        expect(
          migration,
          contains('(v_item.daily_price * v_days) + v_item.deposit'),
        );
      },
    );

    test('keeps money-moving transitions system-only', () {
      expect(migration, contains("('paid',      'cancelled', 'system')"));
      expect(migration, contains("('returned',  'settled',   'system')"));
      expect(
        migration,
        isNot(contains("('paid',      'cancelled', 'borrower')")),
      );
      expect(
        migration,
        isNot(contains("('returned',  'settled',   'lender')")),
      );
    });

    test('does not trust client-supplied actor kind', () {
      expect(migration, contains("v_role := current_setting('role', true);"));
      expect(migration, contains("IF v_role = 'service_role' THEN"));
      expect(migration, contains("service_role actor must be system or admin"));
    });

    test('authorizes actor before same-state idempotency return', () {
      final actorResolution = migration.indexOf('-- Resolve actor_kind');
      final idempotency = migration.indexOf(
        '-- Idempotency: same target is a no-op success, but only after actor',
      );

      expect(actorResolution, greaterThanOrEqualTo(0));
      expect(idempotency, greaterThan(actorResolution));
    });

    test('does not keep creation-time date checks on mutable rows', () {
      expect(
        migration,
        contains(
          'DROP CONSTRAINT IF EXISTS chk_reservations_rental_date_not_past',
        ),
      );
      expect(migration, contains('p_rental_date < CURRENT_DATE'));
    });

    test('can be re-applied after status was already converted to enum', () {
      expect(migration, contains('information_schema.columns'));
      expect(
        migration,
        contains("v_status_udt IS DISTINCT FROM 'reservation_status'"),
      );
      expect(
        migration,
        contains('ALTER COLUMN status TYPE reservation_status'),
      );
    });

    test(
      'recreates storage policies that depend on reservation status enum',
      () {
        final dropPolicy = migration.indexOf(
          'DROP POLICY IF EXISTS "rental_photos_insert_own"',
        );
        final alterStatus = migration.indexOf(
          'ALTER COLUMN status TYPE reservation_status',
        );
        final recreatePolicy = migration.indexOf(
          'CREATE POLICY "rental_photos_insert_own"',
        );

        expect(dropPolicy, greaterThanOrEqualTo(0));
        expect(alterStatus, greaterThan(dropPolicy));
        expect(recreatePolicy, greaterThan(alterStatus));
        expect(migration, contains("'picked_up'::reservation_status"));
      },
    );

    test('expires stale pending holds before creating a new intent', () {
      expect(
        migration,
        contains(
          'CREATE OR REPLACE FUNCTION expire_stale_pending_reservations',
        ),
      );
      expect(migration, contains("status = 'pending'"));
      expect(migration, contains("now() - interval '20 minutes'"));
      expect(
        migration,
        contains('PERFORM expire_stale_pending_reservations();'),
      );
      expect(migration, contains('payment_attempt_started_at IS NULL'));
      expect(migration, contains("now() - interval '30 minutes'"));
    });

    test('records active payment attempts before WebView capture', () {
      expect(migration, contains('payment_attempt_merchant_uid TEXT'));
      expect(
        migration,
        contains(
          'CREATE OR REPLACE FUNCTION start_reservation_payment_attempt',
        ),
      );
      expect(migration, contains('only borrower may start payment'));
      expect(migration, contains('merchant_uid mismatch'));
      expect(migration, contains('payment attempt already in progress'));
    });

    test('marks paid idempotently while binding one provider payment id', () {
      expect(
        migration,
        contains(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_reservations_payment_id_unique',
        ),
      );
      expect(
        migration,
        contains('CREATE OR REPLACE FUNCTION mark_reservation_paid'),
      );
      expect(
        migration,
        contains('reservation already has a different payment_id'),
      );
      expect(migration, contains('FOR UPDATE'));
      expect(
        migration,
        contains(
          'GRANT EXECUTE ON FUNCTION mark_reservation_paid(UUID, TEXT, TEXT) TO service_role',
        ),
      );
    });

    test('locks money-moving actions around external provider calls', () {
      expect(migration, contains('payment_action TEXT'));
      expect(migration, contains("'refund_pending', 'settle_pending'"));
      expect(
        migration,
        contains('CREATE OR REPLACE FUNCTION begin_reservation_payment_action'),
      );
      expect(
        migration,
        contains('CREATE OR REPLACE FUNCTION clear_reservation_payment_action'),
      );
      expect(migration, contains('payment action in progress'));
      expect(migration, contains('payment action already in progress'));
      expect(migration, contains('refund is already in progress'));
      expect(migration, contains('settlement is already in progress'));
      expect(migration, contains("now() - interval '10 minutes'"));
      expect(migration, contains('v_row.payment_action := NULL'));
    });

    test('confirms returns through one photo-binding RPC', () {
      expect(
        migration,
        contains('CREATE OR REPLACE FUNCTION confirm_reservation_return'),
      );
      expect(
        migration,
        contains('use confirm_reservation_return with return photo'),
      );
      expect(migration, contains('return photo is required'));
      expect(migration, contains('return photo object not found'));
      expect(migration, contains('storage.objects'));
      expect(migration, contains('only borrower may confirm return'));
      expect(migration, contains('return_photo = p_return_photo'));
      expect(
        migration,
        contains(
          'GRANT EXECUTE ON FUNCTION confirm_reservation_return(UUID, TEXT) TO authenticated',
        ),
      );
    });

    test('locks trust badge fields to service-role managed updates', () {
      expect(migration, contains('protect_user_trust_fields'));
      expect(migration, contains('trust fields are service-role managed'));
      expect(
        migration,
        contains(
          'NEW.identity_verified IS DISTINCT FROM OLD.identity_verified',
        ),
      );
      expect(
        migration,
        contains('NEW.lender_grade IS DISTINCT FROM OLD.lender_grade'),
      );
      expect(migration, contains('protect_rental_item_trust_fields'));
      expect(
        migration,
        contains('item verification fields are service-role managed'),
      );
      expect(
        migration,
        contains('NEW.bt_verified IS DISTINCT FROM OLD.bt_verified'),
      );
      expect(
        migration,
        contains('NEW.imei_verified IS DISTINCT FROM OLD.imei_verified'),
      );
    });

    test('keeps dispute resolutions in an append-only service ledger', () {
      expect(
        migration,
        contains('CREATE TABLE IF NOT EXISTS reservation_dispute_resolutions'),
      );
      expect(migration, contains('UNIQUE (reservation_id, idempotency_key)'));
      expect(migration, contains('Participants can read dispute resolutions'));
    });
  });
}
