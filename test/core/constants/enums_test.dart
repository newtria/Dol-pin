import 'package:flutter_test/flutter_test.dart';
import 'package:dolpin/core/constants/enums.dart';

void main() {
  group('ReservationStatus', () {
    test('value returns correct DB string', () {
      expect(ReservationStatus.pending.value, 'pending');
      expect(ReservationStatus.pickedUp.value, 'picked_up');
      expect(ReservationStatus.returned.value, 'returned');
    });

    test('fromString parses correctly', () {
      expect(ReservationStatus.fromString('picked_up'), ReservationStatus.pickedUp);
      expect(ReservationStatus.fromString('returned'), ReservationStatus.returned);
      expect(ReservationStatus.fromString('unknown'), ReservationStatus.pending);
    });
  });

  group('ItemCategory', () {
    test('fromString parses correctly', () {
      expect(ItemCategory.fromString('lightstick'), ItemCategory.lightstick);
      expect(ItemCategory.fromString('unknown'), ItemCategory.etc);
    });

    test('label returns English fallback', () {
      expect(ItemCategory.lightstick.label, 'Lightstick');
      expect(ItemCategory.etc.label, 'Other');
    });
  });

  group('PickupMethod', () {
    test('fromString parses correctly', () {
      expect(PickupMethod.fromString('direct'), PickupMethod.direct);
      expect(PickupMethod.fromString('delivery'), PickupMethod.delivery);
      expect(PickupMethod.fromString('invalid'), PickupMethod.direct);
    });
  });
}
