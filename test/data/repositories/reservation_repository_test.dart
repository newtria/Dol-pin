import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dolpin/core/constants/enums.dart';
import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/repositories/reservation_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
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
    when(() => mockClient.from('reservations')).thenReturn(mockQueryBuilder);
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
      final mockFilter = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.insert(input)).thenReturn(mockFilter);
      when(() => mockFilter.select()).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.single())
          .thenAnswer((_) async => sampleReservation);

      final result = await repository.create(input);
      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'res-1');
      expect(result.value.borrowerId, 'user-2');
      expect(result.value.totalPaid, 60000);
    });

    test('returns Fail on insert error', () async {
      when(() => mockQueryBuilder.insert(any()))
          .thenThrow(PostgrestException(message: 'insert failed', code: '500'));

      final result = await repository.create({'item_id': 'item-1'});
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('getById', () {
    test('returns Success with reservation data', () async {
      final mockFilter = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.eq('id', 'res-1')).thenReturn(mockFilter);
      when(() => mockFilter.single())
          .thenAnswer((_) async => sampleReservation);

      final result = await repository.getById('res-1');
      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'res-1');
      expect(result.value.status, 'pending');
    });

    test('returns Fail with NotFoundFailure when not found', () async {
      when(() => mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.eq('id', 'nonexistent')).thenThrow(
        PostgrestException(message: 'not found', code: 'PGRST116'),
      );

      final result = await repository.getById('nonexistent');
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });

  group('updateStatus', () {
    test('returns Success on status update', () async {
      final mockFilter = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.update({'status': 'accepted'}))
          .thenReturn(mockFilter);
      when(() => mockFilter.eq('id', 'res-1'))
          .thenAnswer((_) async => [sampleReservation]);

      final result = await repository.updateStatus(
          'res-1', ReservationStatus.accepted);
      expect(result.isSuccess, isTrue);
    });

    test('returns Fail on error', () async {
      when(() => mockQueryBuilder.update({'status': 'cancelled'}))
          .thenThrow(PostgrestException(message: 'update error', code: '500'));

      final result = await repository.updateStatus(
          'res-1', ReservationStatus.cancelled);
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('confirmPickup', () {
    test('returns Success on pickup confirmation', () async {
      final mockFilter = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.update(any())).thenReturn(mockFilter);
      when(() => mockFilter.eq('id', 'res-1'))
          .thenAnswer((_) async => [sampleReservation]);

      final result = await repository.confirmPickup('res-1');
      expect(result.isSuccess, isTrue);
      verify(() => mockQueryBuilder.update(any(
            that: containsPair('status', 'picked_up'),
          ))).called(1);
    });
  });

  group('confirmReturn', () {
    test('returns Success on return confirmation', () async {
      final mockFilter = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.update(any())).thenReturn(mockFilter);
      when(() => mockFilter.eq('id', 'res-1'))
          .thenAnswer((_) async => [sampleReservation]);

      final result = await repository.confirmReturn('res-1',
          returnPhoto: 'https://example.com/return.jpg');
      expect(result.isSuccess, isTrue);
      verify(() => mockQueryBuilder.update(any(
            that: allOf(
              containsPair('status', 'returned'),
              containsPair('return_photo', 'https://example.com/return.jpg'),
            ),
          ))).called(1);
    });

    test('returns Fail on error', () async {
      when(() => mockQueryBuilder.update(any()))
          .thenThrow(PostgrestException(message: 'update failed', code: '500'));

      final result = await repository.confirmReturn('res-1');
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });
}
