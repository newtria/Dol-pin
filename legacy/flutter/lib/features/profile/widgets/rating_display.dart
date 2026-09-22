import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class RatingDisplay extends StatelessWidget {
  const RatingDisplay({
    super.key,
    required this.rating,
    this.reviewCount,
    this.size = 16,
  });

  final double rating;
  final int? reviewCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final starValue = i + 1;
          if (rating >= starValue) {
            return Icon(Icons.star, size: size, color: AppColors.warning);
          } else if (rating >= starValue - 0.5) {
            return Icon(Icons.star_half, size: size, color: AppColors.warning);
          }
          return Icon(Icons.star_border, size: size, color: AppColors.textHint);
        }),
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: size * 0.75,
            ),
          ),
        ],
      ],
    );
  }
}
