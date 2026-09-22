import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('register item localization', () {
    late String registerUi;
    late String registerPolicy;

    setUpAll(() {
      registerUi = [
        File('lib/features/register/screens/register_item_screen.dart'),
        File('lib/features/register/widgets/register_item_form_sections.dart'),
      ].map((file) => file.readAsStringSync()).join('\n');
      registerPolicy = File(
        'lib/features/register/application/register_item_form_policy.dart',
      ).readAsStringSync();
    });

    test('does not hardcode form labels that users see', () {
      expect(registerUi, contains('l.concert'));
      expect(registerUi, contains('l.selectConcert'));
      expect(registerUi, contains('l.availability'));
      expect(registerUi, contains('l.selectAvailability'));
      expect(registerUi, contains('l.pickupLocation'));
      expect(registerUi, contains('l.pickupLocationHint'));
      expect(registerUi, isNot(contains("_sectionTitle('Concert')")));
      expect(registerUi, isNot(contains("'Select availability'")));
      expect(registerUi, isNot(contains("'Pickup location'")));
    });

    test(
      'normalizes same-day availability to the exclusive return-date model',
      () {
        expect(registerPolicy, contains("start.add(const Duration(days: 1))"));
        expect(registerUi, contains('DateTimeRange('));
      },
    );
  });
}
