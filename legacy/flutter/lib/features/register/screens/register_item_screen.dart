import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/constants/enums.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/concert_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dolpin_button.dart';
import '../application/register_item_controller.dart';
import '../application/register_item_form_policy.dart';
import '../widgets/register_item_form_sections.dart';

class RegisterItemScreen extends ConsumerStatefulWidget {
  const RegisterItemScreen({super.key});

  @override
  ConsumerState<RegisterItemScreen> createState() => _RegisterItemScreenState();
}

class _RegisterItemScreenState extends ConsumerState<RegisterItemScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _depositController = TextEditingController();
  final _pickupLocationController = TextEditingController();

  ItemCategory _category = ItemCategory.lightstick;
  PickupMethod _pickupMethod = PickupMethod.direct;
  DateTimeRange? _availabilityRange;
  String? _selectedConcertId;
  String _conditionGrade = 'A';
  final _photos = <XFile>[];
  bool _isLoading = false;
  String? _vlmTag;
  bool _isAutoTagging = false;
  int _autoTagRequestId = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _pickupLocationController.dispose();
    super.dispose();
  }

  Future<void> _selectAvailability() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      final availability = RegisterItemCommandFactory.normalizeAvailability(
        range.start,
        range.end,
      );
      setState(
        () => _availabilityRange = DateTimeRange(
          start: availability.start,
          end: availability.end,
        ),
      );
    }
  }

  Future<void> _autoTag(XFile photo) async {
    final requestId = ++_autoTagRequestId;
    setState(() => _isAutoTagging = true);
    try {
      final result = await ref
          .read(registerItemControllerProvider)
          .autoTag(File(photo.path));

      if (!mounted ||
          requestId != _autoTagRequestId ||
          _photos.isEmpty ||
          _photos.first.path != photo.path) {
        return;
      }

      result.when(
        success: (autoTag) {
          setState(() {
            _vlmTag = autoTag.tag ?? _vlmTag;
            _category = autoTag.category ?? _category;
          });
        },
        failure: (_) {},
      );
    } finally {
      if (mounted && requestId == _autoTagRequestId) {
        setState(() => _isAutoTagging = false);
      }
    }
  }

  Future<void> _addPhotos() async {
    final picker = ImagePicker();
    // Compress + downscale on pick. Prevents OOM during base64-encode for
    // Gemini and keeps Supabase storage bills sane.
    final images = await picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (images.isEmpty) return;
    final wasEmpty = _photos.isEmpty;
    setState(() => _photos.addAll(images));
    if (wasEmpty && _photos.isNotEmpty) {
      unawaited(_autoTag(_photos.first));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
    if (index == 0 && _photos.isNotEmpty) {
      unawaited(_autoTag(_photos.first));
    }
    if (_photos.isEmpty) {
      _autoTagRequestId++;
      setState(() {
        _vlmTag = null;
        _isAutoTagging = false;
      });
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final buildResult = RegisterItemCommandFactory.build(
      RegisterItemDraft(
        userId: userId,
        photos: _photos.map((photo) => File(photo.path)).toList(),
        selectedConcertId: _selectedConcertId,
        category: _category,
        titleText: _titleController.text,
        descriptionText: _descController.text,
        dailyPriceText: _priceController.text,
        currency: ref.read(currentUserProvider).value?.currency ?? 'KRW',
        depositText: _depositController.text,
        conditionGrade: _conditionGrade,
        pickupMethod: _pickupMethod,
        pickupLocationText: _pickupLocationController.text,
        availableFrom: _availabilityRange?.start,
        availableTo: _availabilityRange?.end,
        vlmTag: _vlmTag,
      ),
    );

    final RegisterItemCommand command;
    switch (buildResult) {
      case RegisterItemBuildSuccess(command: final builtCommand):
        command = builtCommand;
      case RegisterItemBuildFailure(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_validationMessage(l, error))));
        return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ref
          .read(registerItemControllerProvider)
          .createItem(command);

      if (!mounted) return;
      result.when(
        success: (_) => context.pop(),
        failure: (f) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.errorPrefix(f.message)))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.errorPrefix(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final concertsAsync = ref.watch(upcomingConcertsProvider(null));
    final currencySymbol = CurrencyFormatter.symbol(
      ref.watch(currentUserProvider).value?.currency ?? 'KRW',
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.registerItem)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RegisterPhotoSection(
              photos: _photos,
              onAdd: _addPhotos,
              onRemove: _removePhoto,
              isAutoTagging: _isAutoTagging,
              vlmTag: _vlmTag,
            ),
            const SizedBox(height: 24),
            RegisterConcertSection(
              concertsAsync: concertsAsync,
              selectedConcertId: _selectedConcertId,
              onChanged: (value) => setState(() => _selectedConcertId = value),
            ),
            const SizedBox(height: 24),
            RegisterCategorySection(
              category: _category,
              onChanged: (category) => setState(() => _category = category),
            ),
            const SizedBox(height: 24),
            RegisterTextFieldSection(
              title: l.title,
              controller: _titleController,
              hintText: l.titleHint,
            ),
            const SizedBox(height: 24),
            RegisterTextFieldSection(
              title: l.description,
              controller: _descController,
              hintText: l.descriptionHint,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            RegisterConditionSection(
              grade: _conditionGrade,
              onChanged: (g) => setState(() => _conditionGrade = g),
            ),
            const SizedBox(height: 24),
            RegisterPriceDepositSection(
              priceController: _priceController,
              depositController: _depositController,
              currencySymbol: currencySymbol,
            ),
            const SizedBox(height: 24),
            RegisterAvailabilitySection(
              availabilityRange: _availabilityRange,
              onTap: _selectAvailability,
            ),
            const SizedBox(height: 24),
            RegisterTextFieldSection(
              title: l.pickupLocation,
              controller: _pickupLocationController,
              hintText: l.pickupLocationHint,
            ),
            const SizedBox(height: 24),
            RegisterPickupMethodSection(
              pickupMethod: _pickupMethod,
              onChanged: (method) => setState(() => _pickupMethod = method),
            ),
            const SizedBox(height: 40),
            DolpinButton(
              label: l.register,
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _validationMessage(
    AppLocalizations l,
    RegisterItemValidationError error,
  ) {
    return switch (error) {
      RegisterItemValidationError.photosRequired => l.photosRequired,
      RegisterItemValidationError.fillAllFields => l.fillAllFields,
      RegisterItemValidationError.validNumbers => l.validNumbers,
      RegisterItemValidationError.pricePositiveRequired =>
        l.pricePositiveRequired,
    };
  }
}
