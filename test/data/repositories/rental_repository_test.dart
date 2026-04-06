import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dolpin/core/constants/enums.dart';
import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/repositories/rental_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}

/// A fake [PostgrestBuilder] that resolves to [_value] when awaited.
class FakePostgrestResponse<T> extends Fake implements PostgrestBuilder<T> {
  final T _value;
  FakePostgrestResponse(this._value);

  @override
  Future<S> then<S>(FutureOr<S> Function(T value) onValue,
          {Function? onError}) =>
      Future<T>.value(_value).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError,
          {bool Function(Object error)? test}) =>
      Future<T>.value(_value);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future<T>.value(_value).whenComplete(action);

  @override
  Stream<T> asStream() => Stream.value(_value);

  @override
  Future<T> timeout(Duration timeLimit,
          {FutureOr<T> Function()? onTimeout}) =>
      Future<T>.value(_value);
}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late RentalRepository repository;

  final sampleItem = {
    'id': 'item-1',
    'lender_id': 'user-1',
    'category': 'lightstick',
    'title': 'BTS Lightstick',
    'photos': ['https://example.com/photo1.jpg'],
    'daily_price': 5000,
    'currency': 'KRW',
    'deposit': 50000,
    'pickup_method': 'direct',
    'status': 'active',
    'created_at': '2026-03-28T12:00:00.000Z',
  };

  setUp(() {
    mockClient = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    when(() => mockClient.from('rental_items')).thenReturn(mockQueryBuilder);
    repository = RentalRepository(mockClient);
  });

  group('getById', () {
    test('returns Success with RentalItemModel', () async {
      when(() => mockQueryBuilder.select()).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'item-1'))
          .thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.single())
          .thenReturn(FakePostgrestResponse<PostgrestMap>(sampleItem));

      final result = await repository.getById('item-1');
      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'item-1');
      expect(result.value.title, 'BTS Lightstick');
      expect(result.value.dailyPrice, 5000);
    });

    test('returns Fail with NotFoundFailure on PGRST116', () async {
      when(() => mockQueryBuilder.select()).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'nonexistent')).thenThrow(
        PostgrestException(message: 'not found', code: 'PGRST116'),
      );

      final result = await repository.getById('nonexistent');
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });

  group('create', () {
    test('returns Success with created item', () async {
      final input = {
        'lender_id': 'user-1',
        'category': 'lightstick',
        'title': 'BTS Lightstick',
        'photos': ['url1'],
        'daily_price': 5000,
        'currency': 'KRW',
        'deposit': 50000,
        'pickup_method': 'direct',
      };
      when(() => mockQueryBuilder.insert(input)).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.select()).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.single())
          .thenReturn(FakePostgrestResponse<PostgrestMap>({
        ...input,
        'id': 'item-new',
        'status': 'active',
        'created_at': '2026-03-28T12:00:00.000Z',
      }));

      final result = await repository.create(input);
      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'item-new');
      expect(result.value.category, 'lightstick');
    });

    test('returns Fail on insert error', () async {
      when(() => mockQueryBuilder.insert(any()))
          .thenThrow(PostgrestException(message: 'insert failed', code: '500'));

      final result = await repository.create({'title': 'test'});
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('updateStatus', () {
    test('returns Success on status update', () async {
      when(() => mockQueryBuilder.update({'status': 'paused'}))
          .thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'item-1'))
          .thenReturn(FakePostgrestResponse<dynamic>([sampleItem]));

      final result =
          await repository.updateStatus('item-1', ItemStatus.paused);
      expect(result.isSuccess, isTrue);
    });

    test('returns Fail on error', () async {
      when(() => mockQueryBuilder.update({'status': 'deleted'}))
          .thenThrow(PostgrestException(message: 'update failed', code: '500'));

      final result =
          await repository.updateStatus('item-1', ItemStatus.deleted);
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });
}
