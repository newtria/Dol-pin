import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('register item localization', () {
    late String registerScreen;

    setUpAll(() {
      registerScreen = File(
        'lib/features/register/screens/register_item_screen.dart',
      ).readAsStringSync();
    });

    test('does not hardcode form labels that users see', () {
      expect(registerScreen, contains('l.concert'));
      expect(registerScreen, contains('l.selectConcert'));
      expect(registerScreen, contains('l.availability'));
      expect(registerScreen, contains('l.selectAvailability'));
      expect(registerScreen, contains('l.pickupLocation'));
      expect(registerScreen, contains('l.pickupLocationHint'));
      expect(registerScreen, isNot(contains("_sectionTitle('Concert')")));
      expect(registerScreen, isNot(contains("'Select availability'")));
      expect(registerScreen, isNot(contains("'Pickup location'")));
    });

    test(
      'normalizes same-day availability to the exclusive return-date model',
      () {
        expect(
          registerScreen,
          contains("range.start.add(const Duration(days: 1))"),
        );
        expect(registerScreen, contains('DateTimeRange('));
      },
    );
  });
}
