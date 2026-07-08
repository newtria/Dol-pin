import 'package:dolpin/core/constants/enums.dart';
import 'package:dolpin/data/repositories/rental_repository.dart';
import 'package:dolpin/providers/rental_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
