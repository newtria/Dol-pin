import 'dart:io';

import '../../../core/constants/enums.dart';
import 'register_item_controller.dart';

enum RegisterItemValidationError {
  photosRequired,
  fillAllFields,
  validNumbers,
  pricePositiveRequired,
}

class RegisterAvailability {
  const RegisterAvailability({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class RegisterItemDraft {
  const RegisterItemDraft({
    required this.userId,
    required this.photos,
    required this.selectedConcertId,
    required this.category,
    required this.titleText,
    required this.descriptionText,
    required this.dailyPriceText,
    required this.currency,
    required this.depositText,
    required this.conditionGrade,
    required this.pickupMethod,
    required this.pickupLocationText,
    required this.availableFrom,
    required this.availableTo,
    this.vlmTag,
  });

  final String userId;
  final List<File> photos;
  final String? selectedConcertId;
  final ItemCategory category;
  final String titleText;
  final String descriptionText;
  final String dailyPriceText;
  final String currency;
  final String depositText;
  final String conditionGrade;
  final PickupMethod pickupMethod;
  final String pickupLocationText;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final String? vlmTag;
}

sealed class RegisterItemBuildResult {
  const RegisterItemBuildResult();
}

class RegisterItemBuildSuccess extends RegisterItemBuildResult {
  const RegisterItemBuildSuccess(this.command);

  final RegisterItemCommand command;
}

class RegisterItemBuildFailure extends RegisterItemBuildResult {
  const RegisterItemBuildFailure(this.error);

  final RegisterItemValidationError error;
}

class RegisterItemCommandFactory {
  const RegisterItemCommandFactory._();

  static RegisterAvailability normalizeAvailability(
    DateTime start,
    DateTime end,
  ) {
    return RegisterAvailability(
      start: start,
      end: end.isAfter(start) ? end : start.add(const Duration(days: 1)),
    );
  }

  static RegisterItemBuildResult build(RegisterItemDraft draft) {
    if (draft.photos.length < 2) {
      return const RegisterItemBuildFailure(
        RegisterItemValidationError.photosRequired,
      );
    }

    final title = draft.titleText.trim();
    final priceText = draft.dailyPriceText.trim();
    final depositText = draft.depositText.trim();
    final pickupLocationLabel = draft.pickupLocationText.trim();
    final selectedConcertId = draft.selectedConcertId;
    final availableFrom = draft.availableFrom;
    final availableTo = draft.availableTo;
    if (title.isEmpty ||
        priceText.isEmpty ||
        depositText.isEmpty ||
        selectedConcertId == null ||
        selectedConcertId.isEmpty ||
        availableFrom == null ||
        availableTo == null ||
        pickupLocationLabel.isEmpty) {
      return const RegisterItemBuildFailure(
        RegisterItemValidationError.fillAllFields,
      );
    }

    final price = int.tryParse(priceText);
    final deposit = int.tryParse(depositText);
    if (price == null || deposit == null) {
      return const RegisterItemBuildFailure(
        RegisterItemValidationError.validNumbers,
      );
    }
    if (price <= 0 || deposit <= 0) {
      return const RegisterItemBuildFailure(
        RegisterItemValidationError.pricePositiveRequired,
      );
    }

    final availability = normalizeAvailability(availableFrom, availableTo);
    return RegisterItemBuildSuccess(
      RegisterItemCommand(
        userId: draft.userId,
        photos: draft.photos,
        selectedConcertId: selectedConcertId,
        category: draft.category,
        title: title,
        description: draft.descriptionText.trim(),
        dailyPrice: price,
        currency: draft.currency,
        deposit: deposit,
        conditionGrade: draft.conditionGrade,
        pickupMethod: draft.pickupMethod,
        pickupLocationLabel: pickupLocationLabel,
        availableFrom: availability.start,
        availableTo: availability.end,
        vlmTag: draft.vlmTag,
      ),
    );
  }
}
