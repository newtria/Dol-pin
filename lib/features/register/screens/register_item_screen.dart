import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/gemini_service.dart';
import '../../../data/datasources/storage_service.dart';
import '../../../core/constants/enums.dart';
import '../../../data/repositories/rental_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dolpin_button.dart';
import '../widgets/condition_selector.dart';
import '../widgets/photo_upload.dart';

class RegisterItemScreen extends ConsumerStatefulWidget {
  const RegisterItemScreen({super.key});

  @override
  ConsumerState<RegisterItemScreen> createState() =>
      _RegisterItemScreenState();
}

class _RegisterItemScreenState extends ConsumerState<RegisterItemScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _depositController = TextEditingController();

  ItemCategory _category = ItemCategory.lightstick;
  PickupMethod _pickupMethod = PickupMethod.direct;
  String _conditionGrade = 'A';
  final _photos = <XFile>[];
  bool _isLoading = false;
  String? _vlmTag;
  bool _isAutoTagging = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _autoTag(XFile photo) async {
    setState(() => _isAutoTagging = true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      final file = File(photo.path);

      // Run tag analysis and category suggestion in parallel
      final results = await Future.wait([
        gemini.analyzeItemPhoto(file),
        gemini.suggestCategory(file),
      ]);

      if (!mounted) return;

      final tagResult = results[0];
      final categoryResult = results[1];

      tagResult.when(
        success: (tag) => setState(() => _vlmTag = tag),
        failure: (_) {},
      );

      categoryResult.when(
        success: (cat) {
          final suggested = ItemCategory.fromString(cat);
          setState(() => _category = suggested);
        },
        failure: (_) {},
      );
    } finally {
      if (mounted) setState(() => _isAutoTagging = false);
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (_photos.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.photosRequired)),
      );
      return;
    }
    final title = _titleController.text.trim();
    final priceText = _priceController.text.trim();
    final depositText = _depositController.text.trim();
    if (title.isEmpty || priceText.isEmpty || depositText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.fillAllFields)),
      );
      return;
    }

    final price = int.tryParse(priceText);
    final deposit = int.tryParse(depositText);
    if (price == null || deposit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.validNumbers)),
      );
      return;
    }
    if (price <= 0 || deposit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.pricePositiveRequired)),
      );
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      // Upload photos in parallel
      final storage = ref.read(storageServiceProvider);
      final uploadResults = await Future.wait(
        _photos.map((photo) => storage.uploadItemPhoto(userId, File(photo.path))),
      );

      // Check for upload failures
      final photoUrls = <String>[];
      for (final result in uploadResults) {
        if (result.isFailure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.errorPrefix(result.failure.message))),
            );
          }
          return;
        }
        photoUrls.add(result.value);
      }

      // Auto-tag via Gemini VLM if not already tagged
      String? vlmTag = _vlmTag;
      if (vlmTag == null && photoUrls.isNotEmpty) {
        final gemini = ref.read(geminiServiceProvider);
        final tagResult =
            await gemini.analyzeItemPhoto(File(_photos.first.path));
        tagResult.when(
          success: (tag) => vlmTag = tag,
          failure: (_) {},
        );
      }

      // Create item
      final result = await ref.read(rentalRepositoryProvider).create({
        'lender_id': userId,
        'category': _category.name,
        'title': title,
        'description': _descController.text.trim(),
        'photos': photoUrls,
        'daily_price': price,
        'currency': ref.read(currentUserProvider).value?.currency ?? 'KRW',
        'deposit': deposit,
        'condition_grade': _conditionGrade,
        'pickup_method': _pickupMethod.name,
        'vlm_tag': vlmTag,
      });

      if (!mounted) return;
      result.when(
        success: (_) => context.pop(),
        failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorPrefix(f.message))),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorPrefix(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
                final images = await picker.pickMultiImage();
                if (images.isEmpty) return;
                final wasEmpty = _photos.isEmpty;
                setState(() => _photos.addAll(images));
                // Auto-tag from the first photo when photos are initially added
                if (wasEmpty && _photos.isNotEmpty) {
                  _autoTag(_photos.first);
                }
              },
              onRemove: (i) {
                setState(() => _photos.removeAt(i));
                // Re-tag if cover photo changed and photos remain
                if (i == 0 && _photos.isNotEmpty) {
                  _autoTag(_photos.first);
                }
                if (_photos.isEmpty) {
                  setState(() => _vlmTag = null);
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
                    const Icon(Icons.auto_awesome,
                        size: 16, color: AppColors.primary),
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
              decoration: InputDecoration(
                hintText: l.titleHint,
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(l.description),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l.descriptionHint,
              ),
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
}
