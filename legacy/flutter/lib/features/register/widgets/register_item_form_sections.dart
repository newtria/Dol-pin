import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/concert_model.dart';
import '../../../l10n/app_localizations.dart';
import 'condition_selector.dart';
import 'photo_upload.dart';

class RegisterPhotoSection extends StatelessWidget {
  const RegisterPhotoSection({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    required this.isAutoTagging,
    required this.vlmTag,
  });

  final List<XFile> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final bool isAutoTagging;
  final String? vlmTag;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhotoUpload(photos: photos, onAdd: onAdd, onRemove: onRemove),
        if (isAutoTagging)
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
        if (vlmTag != null && !isAutoTagging)
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
                    vlmTag!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class RegisterConcertSection extends StatelessWidget {
  const RegisterConcertSection({
    super.key,
    required this.concertsAsync,
    required this.selectedConcertId,
    required this.onChanged,
  });

  final AsyncValue<List<ConcertModel>> concertsAsync;
  final String? selectedConcertId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return RegisterFieldSection(
      title: l.concert,
      child: concertsAsync.when(
        data: (concerts) => DropdownButtonFormField<String>(
          initialValue: selectedConcertId,
          decoration: InputDecoration(hintText: l.selectConcert),
          items: concerts
              .map(
                (concert) => DropdownMenuItem(
                  value: concert.id,
                  child: Text('${concert.title} · ${concert.city}'),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Text(
          l.couldNotLoadConcerts,
          style: const TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

class RegisterCategorySection extends StatelessWidget {
  const RegisterCategorySection({
    super.key,
    required this.category,
    required this.onChanged,
  });

  final ItemCategory category;
  final ValueChanged<ItemCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return RegisterFieldSection(
      title: l.category,
      child: Wrap(
        spacing: 8,
        children: ItemCategory.values.map((candidate) {
          return ChoiceChip(
            label: Text(candidate.localizedLabel(l)),
            selected: category == candidate,
            onSelected: (_) => onChanged(candidate),
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
          );
        }).toList(),
      ),
    );
  }
}

class RegisterConditionSection extends StatelessWidget {
  const RegisterConditionSection({
    super.key,
    required this.grade,
    required this.onChanged,
  });

  final String grade;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return RegisterFieldSection(
      title: l.condition,
      child: ConditionSelector(grade: grade, onChanged: onChanged),
    );
  }
}

class RegisterPriceDepositSection extends StatelessWidget {
  const RegisterPriceDepositSection({
    super.key,
    required this.priceController,
    required this.depositController,
    required this.currencySymbol,
  });

  final TextEditingController priceController;
  final TextEditingController depositController;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: RegisterTextFieldSection(
            title: l.dailyPrice,
            controller: priceController,
            keyboardType: TextInputType.number,
            prefixText: '$currencySymbol ',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: RegisterTextFieldSection(
            title: l.deposit,
            controller: depositController,
            keyboardType: TextInputType.number,
            prefixText: '$currencySymbol ',
          ),
        ),
      ],
    );
  }
}

class RegisterAvailabilitySection extends StatelessWidget {
  const RegisterAvailabilitySection({
    super.key,
    required this.availabilityRange,
    required this.onTap,
  });

  final DateTimeRange? availabilityRange;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return RegisterFieldSection(
      title: l.availability,
      child: InkWell(
        onTap: onTap,
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
                  availabilityRange == null
                      ? l.selectAvailability
                      : DateFormatter.rentalPeriod(
                          availabilityRange!.start,
                          availabilityRange!.end,
                        ),
                  style: TextStyle(
                    color: availabilityRange == null
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterPickupMethodSection extends StatelessWidget {
  const RegisterPickupMethodSection({
    super.key,
    required this.pickupMethod,
    required this.onChanged,
  });

  final PickupMethod pickupMethod;
  final ValueChanged<PickupMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return RegisterFieldSection(
      title: l.pickupMethod,
      child: Wrap(
        spacing: 8,
        children: PickupMethod.values.map((method) {
          return ChoiceChip(
            label: Text(method.localizedLabel(l)),
            selected: pickupMethod == method,
            onSelected: (_) => onChanged(method),
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
          );
        }).toList(),
      ),
    );
  }
}

class RegisterTextFieldSection extends StatelessWidget {
  const RegisterTextFieldSection({
    super.key,
    required this.title,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
    this.prefixText,
  });

  final String title;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return RegisterFieldSection(
      title: title,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(hintText: hintText, prefixText: prefixText),
      ),
    );
  }
}

class RegisterFieldSection extends StatelessWidget {
  const RegisterFieldSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [RegisterSectionTitle(title), const SizedBox(height: 8), child],
    );
  }
}

class RegisterSectionTitle extends StatelessWidget {
  const RegisterSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
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
