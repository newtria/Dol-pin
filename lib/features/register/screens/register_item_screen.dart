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
import '../widgets/condition_selector.dart';
import '../widgets/photo_upload.dart';

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
            PhotoUpload(
              photos: _photos,
              onAdd: () async {
                final picker = ImagePicker();
                // Compress + downscale on pick. Prevents OOM during
                // base64-encode for Gemini and keeps Supabase storage
                // bills sane (item photos don't need full phone resolution).
                final images = await picker.pickMultiImage(
                  maxWidth: 1600,
                  maxHeight: 1600,
                  imageQuality: 82,
                );
                if (images.isEmpty) return;
                final wasEmpty = _photos.isEmpty;
                setState(() => _photos.addAll(images));
                // Auto-tag from the first photo when photos are initially added
                if (wasEmpty && _photos.isNotEmpty) {
                  unawaited(_autoTag(_photos.first));
                }
              },
              onRemove: (i) {
                setState(() => _photos.removeAt(i));
                // Re-tag if cover photo changed and photos remain
                if (i == 0 && _photos.isNotEmpty) {
                  unawaited(_autoTag(_photos.first));
                }
                if (_photos.isEmpty) {
                  _autoTagRequestId++;
                  setState(() {
                    _vlmTag = null;
                    _isAutoTagging = false;
                  });
                }
              },
            ),
            if (_isAutoTagging)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.autoTagging,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            if (_vlmTag != null && !_isAutoTagging)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _vlmTag!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _sectionTitle(l.concert),
            const SizedBox(height: 8),
            concertsAsync.when(
              data: (concerts) => DropdownButtonFormField<String>(
                initialValue: _selectedConcertId,
                decoration: InputDecoration(hintText: l.selectConcert),
                items: concerts
                    .map(
                      (concert) => DropdownMenuItem(
                        value: concert.id,
                        child: Text('${concert.title} · ${concert.city}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedConcertId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(
                l.couldNotLoadConcerts,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(l.category),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ItemCategory.values.map((c) {
                return ChoiceChip(
                  label: Text(c.localizedLabel(l)),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _sectionTitle(l.title),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(hintText: l.titleHint),
            ),
            const SizedBox(height: 24),
            _sectionTitle(l.description),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(hintText: l.descriptionHint),
            ),
            const SizedBox(height: 24),
            _sectionTitle(l.condition),
            const SizedBox(height: 8),
            ConditionSelector(
              grade: _conditionGrade,
              onChanged: (g) => setState(() => _conditionGrade = g),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(l.dailyPrice),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: '$currencySymbol ',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(l.deposit),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _depositController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: '$currencySymbol ',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle(l.availability),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectAvailability,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _availabilityRange == null
                            ? l.selectAvailability
                            : DateFormatter.rentalPeriod(
                                _availabilityRange!.start,
                                _availabilityRange!.end,
                              ),
                        style: TextStyle(
                          color: _availabilityRange == null
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(l.pickupLocation),
            const SizedBox(height: 8),
            TextField(
              controller: _pickupLocationController,
              decoration: InputDecoration(hintText: l.pickupLocationHint),
            ),
            const SizedBox(height: 24),
            _sectionTitle(l.pickupMethod),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PickupMethod.values.map((m) {
                return ChoiceChip(
                  label: Text(m.localizedLabel(l)),
                  selected: _pickupMethod == m,
                  onSelected: (_) => setState(() => _pickupMethod = m),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                );
              }).toList(),
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
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
