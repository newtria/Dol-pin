import 'dart:io';

import 'package:dolpin/core/constants/enums.dart';
import 'package:dolpin/features/register/application/register_item_form_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegisterItemCommandFactory', () {
    test('rejects drafts with fewer than two photos', () {
      final result = RegisterItemCommandFactory.build(
        _draft(photos: [File('one.jpg')]),
      );

      expect(result, isA<RegisterItemBuildFailure>());
      expect(
        (result as RegisterItemBuildFailure).error,
        RegisterItemValidationError.photosRequired,
      );
    });

    test('rejects missing required fields', () {
      final result = RegisterItemCommandFactory.build(_draft(titleText: ''));

      expect(result, isA<RegisterItemBuildFailure>());
      expect(
        (result as RegisterItemBuildFailure).error,
        RegisterItemValidationError.fillAllFields,
      );
    });

    test('rejects non-numeric price and deposit fields', () {
      final result = RegisterItemCommandFactory.build(
        _draft(dailyPriceText: 'ten'),
      );

      expect(result, isA<RegisterItemBuildFailure>());
      expect(
        (result as RegisterItemBuildFailure).error,
        RegisterItemValidationError.validNumbers,
      );
    });

    test('rejects non-positive price and deposit fields', () {
      final result = RegisterItemCommandFactory.build(_draft(depositText: '0'));

      expect(result, isA<RegisterItemBuildFailure>());
      expect(
        (result as RegisterItemBuildFailure).error,
        RegisterItemValidationError.pricePositiveRequired,
      );
    });

    test('normalizes same-day availability and trims command fields', () {
      final result = RegisterItemCommandFactory.build(
        _draft(
          titleText: '  Lightstick  ',
          descriptionText: '  clean  ',
          pickupLocationText: '  KSPO Dome  ',
          availableFrom: DateTime(2026, 7, 8),
          availableTo: DateTime(2026, 7, 8),
        ),
      );

      expect(result, isA<RegisterItemBuildSuccess>());
      final command = (result as RegisterItemBuildSuccess).command;
      expect(command.title, 'Lightstick');
      expect(command.description, 'clean');
      expect(command.pickupLocationLabel, 'KSPO Dome');
      expect(command.availableFrom, DateTime(2026, 7, 8));
      expect(command.availableTo, DateTime(2026, 7, 9));
      expect(command.dailyPrice, 10000);
      expect(command.deposit, 50000);
    });
  });
}

RegisterItemDraft _draft({
  List<File>? photos,
  String? selectedConcertId = 'concert-1',
  String titleText = 'Lightstick',
  String descriptionText = 'Clean',
  String dailyPriceText = '10000',
  String depositText = '50000',
  String pickupLocationText = 'KSPO Dome',
  DateTime? availableFrom,
  DateTime? availableTo,
}) {
  return RegisterItemDraft(
    userId: 'user-1',
    photos: photos ?? [File('one.jpg'), File('two.jpg')],
    selectedConcertId: selectedConcertId,
    category: ItemCategory.lightstick,
    titleText: titleText,
    descriptionText: descriptionText,
    dailyPriceText: dailyPriceText,
    currency: 'KRW',
    depositText: depositText,
    conditionGrade: 'A',
    pickupMethod: PickupMethod.direct,
    pickupLocationText: pickupLocationText,
    availableFrom: availableFrom ?? DateTime(2026, 7, 8),
    availableTo: availableTo ?? DateTime(2026, 7, 10),
  );
}
