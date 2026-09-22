import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

class SafeBadge extends StatelessWidget {
  const SafeBadge({super.key, this.label, this.compact = false});

  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? AppLocalizations.of(context)!.escrowProtected;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.escrowSafe.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.escrowSafe.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: compact ? 12 : 14,
            color: AppColors.escrowSafe,
          ),
          const SizedBox(width: 4),
          Text(
            displayLabel,
            style: TextStyle(
              color: AppColors.escrowSafe,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
