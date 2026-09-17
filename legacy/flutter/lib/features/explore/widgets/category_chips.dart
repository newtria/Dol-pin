import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;

  static List<(String, String, IconData)> _categories(AppLocalizations l) => [
    ('all', l.categoryAll, Icons.apps),
    ('lightstick', l.categoryLightstick, Icons.flashlight_on),
    ('phone', l.categoryPhone, Icons.phone_android),
    ('camera', l.categoryCamera, Icons.camera_alt),
    ('slogan', l.categorySlogan, Icons.flag),
    ('costume', l.categoryCostume, Icons.checkroom),
    ('etc', l.categoryOther, Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    final categories = _categories(AppLocalizations.of(context)!);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label, icon) = categories[index];
          final isSelected =
              (selected == null && value == 'all') || selected == value;
          return FilterChip(
            selected: isSelected,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 4),
                Text(label),
              ],
            ),
            onSelected: (_) => onSelected(value == 'all' ? null : value),
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
            checkmarkColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
          );
        },
      ),
    );
  }
}
