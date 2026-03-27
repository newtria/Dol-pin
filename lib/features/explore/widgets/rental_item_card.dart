import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/rental_item_model.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/dolpin_card.dart';
import '../../../shared/widgets/safe_badge.dart';

class RentalItemCard extends StatelessWidget {
  const RentalItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final RentalItemModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DolpinCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 1,
              child: item.photos.isNotEmpty
                  ? CachedImage(imageUrl: item.photos.first)
                  : Container(
                      color: AppColors.surfaceLight,
                      child:
                          const Icon(Icons.image, color: AppColors.textHint),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.btVerified)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.bluetooth,
                          size: 14,
                          color: AppColors.verified,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.vlmTag != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.vlmTag!,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${CurrencyFormatter.format(item.dailyPrice, item.currency)}/day',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const SafeBadge(compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
