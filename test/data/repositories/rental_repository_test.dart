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
}
