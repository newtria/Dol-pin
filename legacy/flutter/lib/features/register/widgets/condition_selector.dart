import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class ConditionSelector extends StatelessWidget {
  const ConditionSelector({
    super.key,
    required this.grade,
    required this.onChanged,
  });

  final String grade;
  final ValueChanged<String> onChanged;

  static List<(String, String, String)> _grades(AppLocalizations l) => [
    ('S', l.conditionS, l.conditionSDesc),
    ('A', l.conditionA, l.conditionADesc),
    ('B', l.conditionB, l.conditionBDesc),
    ('C', l.conditionC, l.conditionCDesc),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: _grades(l).map((g) {
        final (value, label, desc) = g;
        final isSelected = grade == value;
        return GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        desc,
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
