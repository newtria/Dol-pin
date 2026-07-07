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

  group('updateStatus', () {
    test('returns Success on status update', () async {
      when(
        () => mockQueryBuilder.update({'status': 'accepted'}),
      ).thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'res-1')).thenAnswer(
        (_) => FakePostgrestResponse<PostgrestList>([sampleReservation]),
      );

      final result = await repository.updateStatus(
        'res-1',
        ReservationStatus.accepted,
      );
      expect(result.isSuccess, isTrue);
    });

    test('returns Fail on error', () async {
      when(
        () => mockQueryBuilder.update({'status': 'cancelled'}),
      ).thenThrow(PostgrestException(message: 'update error', code: '500'));

      final result = await repository.updateStatus(
        'res-1',
        ReservationStatus.cancelled,
      );
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('confirmPickup', () {
    test('returns Success on pickup confirmation', () async {
      when(
        () => mockQueryBuilder.update(any()),
      ).thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'res-1')).thenAnswer(
        (_) => FakePostgrestResponse<PostgrestList>([sampleReservation]),
      );

      final result = await repository.confirmPickup('res-1');
      expect(result.isSuccess, isTrue);
      verify(
        () => mockQueryBuilder.update(
          any(that: containsPair('status', 'picked_up')),
        ),
      ).called(1);
    });
  });

  group('confirmReturn', () {
    test('returns Success on return confirmation', () async {
      when(
        () => mockQueryBuilder.update(any()),
      ).thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'res-1')).thenAnswer(
        (_) => FakePostgrestResponse<PostgrestList>([sampleReservation]),
      );

      final result = await repository.confirmReturn(
        'res-1',
        returnPhoto: 'https://example.com/return.jpg',
      );
      expect(result.isSuccess, isTrue);
      verify(
        () => mockQueryBuilder.update(
          any(
            that: allOf(
              containsPair('status', 'returned'),
              containsPair('return_photo', 'https://example.com/return.jpg'),
            ),
          ),
        ),
      ).called(1);
    });

    test('returns Fail on error', () async {
      when(
        () => mockQueryBuilder.update(any()),
      ).thenThrow(PostgrestException(message: 'update failed', code: '500'));

      final result = await repository.confirmReturn('res-1');
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });
}
