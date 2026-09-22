import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dolpin/core/constants/enums.dart';
import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/repositories/rental_repository.dart';
import 'package:dolpin/providers/rental_provider.dart';

import '../../helpers/postgrest_fakes.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder<PostgrestList> mockFilterBuilder;
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
    mockFilterBuilder = MockPostgrestFilterBuilder<PostgrestList>();
    when(
      () => mockClient.from('rental_items'),
    ).thenAnswer((_) => mockQueryBuilder);
    repository = RentalRepository(mockClient);
  });

  group('RentalFilter', () {
    test('uses value equality for Riverpod family keys', () {
      const a = RentalFilter(
        concertId: 'concert-1',
        category: 'camera',
        searchQuery: 'zoom',
      );
      const b = RentalFilter(
        concertId: 'concert-1',
        category: 'camera',
        searchQuery: 'zoom',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('distinguishes concert, category, and search dimensions', () {
      const base = RentalFilter(concertId: 'concert-1');

      expect(base, isNot(equals(const RentalFilter(concertId: 'concert-2'))));
      expect(
        base,
        isNot(
          equals(
            const RentalFilter(concertId: 'concert-1', category: 'lightstick'),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            const RentalFilter(concertId: 'concert-1', searchQuery: 'strap'),
          ),
        ),
      );
    });
  });

  group('getById', () {
    test('returns Success with RentalItemModel', () async {
      when(
        () => mockQueryBuilder.select(),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq('id', 'item-1'),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.single(),
      ).thenAnswer((_) => FakePostgrestResponse<PostgrestMap>(sampleItem));

      final result = await repository.getById('item-1');

      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'item-1');
      expect(result.value.title, 'BTS Lightstick');
      expect(result.value.dailyPrice, 5000);
    });

    test('returns Fail with NotFoundFailure on PGRST116', () async {
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
      when(
        () => mockQueryBuilder.insert(input),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.select(),
      ).thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.single()).thenAnswer(
        (_) => FakePostgrestResponse<PostgrestMap>({
          ...input,
          'id': 'item-new',
          'status': 'active',
          'created_at': '2026-03-28T12:00:00.000Z',
        }),
      );

      final result = await repository.create(input);

      expect(result.isSuccess, isTrue);
      expect(result.value.id, 'item-new');
      expect(result.value.category, 'lightstick');
    });

    test('returns Fail on insert error', () async {
      when(
        () => mockQueryBuilder.insert(any()),
      ).thenThrow(PostgrestException(message: 'insert failed', code: '500'));

      final result = await repository.create({'title': 'test'});

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('CreateRentalItemInput', () {
    test(
      'serializes app enums and dates into the rental_items insert shape',
      () {
        final input = CreateRentalItemInput(
          lenderId: 'user-1',
          concertId: 'concert-1',
          category: ItemCategory.lightstick,
          title: 'Army Bomb',
          description: 'Clean condition',
          photos: const ['https://example.com/a.jpg'],
          dailyPrice: 12000,
          currency: 'KRW',
          deposit: 50000,
          conditionGrade: 'A',
          pickupMethod: PickupMethod.direct,
          pickupLocationLabel: 'KSPO Dome',
          availableFrom: DateTime(2026, 7, 8, 12),
          availableTo: DateTime(2026, 7, 10, 12),
          vlmTag: 'Official lightstick',
        );

        expect(input.toJson(), {
          'lender_id': 'user-1',
          'concert_id': 'concert-1',
          'category': 'lightstick',
          'title': 'Army Bomb',
          'description': 'Clean condition',
          'photos': ['https://example.com/a.jpg'],
          'daily_price': 12000,
          'currency': 'KRW',
          'deposit': 50000,
          'condition_grade': 'A',
          'pickup_method': 'direct',
          'pickup_location': {'label': 'KSPO Dome'},
          'available_from': '2026-07-08',
          'available_to': '2026-07-10',
          'vlm_tag': 'Official lightstick',
        });
      },
    );
  });

  group('updateStatus', () {
    test('returns Success on status update', () async {
      when(
        () => mockQueryBuilder.update({'status': 'paused'}),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq('id', 'item-1'),
      ).thenAnswer((_) => FakePostgrestResponse<PostgrestList>([sampleItem]));

      final result = await repository.updateStatus('item-1', ItemStatus.paused);

      expect(result.isSuccess, isTrue);
    });

    test('returns Fail on error', () async {
      when(
        () => mockQueryBuilder.update({'status': 'deleted'}),
      ).thenThrow(PostgrestException(message: 'update failed', code: '500'));

      final result = await repository.updateStatus(
        'item-1',
        ItemStatus.deleted,
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
    });
  });
}
