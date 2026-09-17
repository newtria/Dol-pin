import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/errors/result.dart';
import '../../../data/datasources/gemini_service.dart';
import '../../../data/datasources/storage_service.dart';
import '../../../data/models/rental_item_model.dart';
import '../../../data/repositories/rental_repository.dart';

final registerItemControllerProvider = Provider<RegisterItemController>((ref) {
  return RegisterItemController(
    geminiService: ref.watch(geminiServiceProvider),
    storageService: ref.watch(storageServiceProvider),
    rentalRepository: ref.watch(rentalRepositoryProvider),
  );
});

class RegisterAutoTagResult {
  const RegisterAutoTagResult({this.tag, this.category});

  final String? tag;
  final ItemCategory? category;
}

class RegisterItemCommand {
  const RegisterItemCommand({
    required this.userId,
    required this.photos,
    required this.selectedConcertId,
    required this.category,
    required this.title,
    required this.description,
    required this.dailyPrice,
    required this.currency,
    required this.deposit,
    required this.conditionGrade,
    required this.pickupMethod,
    required this.pickupLocationLabel,
    required this.availableFrom,
    required this.availableTo,
    this.vlmTag,
  });

  final String userId;
  final List<File> photos;
  final String selectedConcertId;
  final ItemCategory category;
  final String title;
  final String description;
  final int dailyPrice;
  final String currency;
  final int deposit;
  final String conditionGrade;
  final PickupMethod pickupMethod;
  final String pickupLocationLabel;
  final DateTime availableFrom;
  final DateTime availableTo;
  final String? vlmTag;
}

class RegisterItemController {
  const RegisterItemController({
    required GeminiService geminiService,
    required StorageService storageService,
    required RentalRepository rentalRepository,
  }) : _geminiService = geminiService,
       _storageService = storageService,
       _rentalRepository = rentalRepository;

  final GeminiService _geminiService;
  final StorageService _storageService;
  final RentalRepository _rentalRepository;

  Future<Result<RegisterAutoTagResult>> autoTag(File photo) async {
    final results = await Future.wait([
      _geminiService.analyzeItemPhoto(photo),
      _geminiService.suggestCategory(photo),
    ]);

    final tagResult = results[0];
    final categoryResult = results[1];
    if (tagResult.isFailure && categoryResult.isFailure) {
      return Fail(tagResult.failure);
    }

    return Success(
      RegisterAutoTagResult(
        tag: tagResult.isSuccess ? tagResult.value : null,
        category: categoryResult.isSuccess
            ? ItemCategory.fromString(categoryResult.value)
            : null,
      ),
    );
  }

  Future<Result<RentalItemModel>> createItem(
    RegisterItemCommand command,
  ) async {
    final uploadResults = await Future.wait(
      command.photos.map(
        (photo) => _storageService.uploadItemPhoto(command.userId, photo),
      ),
    );

    final photoUrls = <String>[];
    for (final result in uploadResults) {
      if (result.isFailure) {
        return Fail(result.failure);
      }
      photoUrls.add(result.value);
    }

    var vlmTag = command.vlmTag;
    if (vlmTag == null && command.photos.isNotEmpty) {
      final tagResult = await _geminiService.analyzeItemPhoto(
        command.photos.first,
      );
      tagResult.when(success: (tag) => vlmTag = tag, failure: (_) {});
    }

    return _rentalRepository.createItem(
      CreateRentalItemInput(
        lenderId: command.userId,
        concertId: command.selectedConcertId,
        category: command.category,
        title: command.title,
        description: command.description,
        photos: photoUrls,
        dailyPrice: command.dailyPrice,
        currency: command.currency,
        deposit: command.deposit,
        conditionGrade: command.conditionGrade,
        pickupMethod: command.pickupMethod,
        pickupLocationLabel: command.pickupLocationLabel,
        availableFrom: command.availableFrom,
        availableTo: command.availableTo,
        vlmTag: vlmTag,
      ),
    );
  }
}
