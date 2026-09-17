import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/rental_item_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/dolpin_button.dart';
import '../../../shared/widgets/safe_badge.dart';

class ItemDetailHeaderSliver extends StatefulWidget {
  const ItemDetailHeaderSliver({
    super.key,
    required this.item,
    required this.onShare,
    required this.onReport,
  });

  final RentalItemModel item;
  final VoidCallback onShare;
  final VoidCallback onReport;

  @override
  State<ItemDetailHeaderSliver> createState() => _ItemDetailHeaderSliverState();
}

class _ItemDetailHeaderSliverState extends State<ItemDetailHeaderSliver> {
  int _currentPhoto = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final photos = widget.item.photos;
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.width,
      pinned: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          tooltip: l.share,
          onPressed: widget.onShare,
        ),
        IconButton(
          icon: const Icon(Icons.flag_outlined),
          tooltip: l.report,
          onPressed: widget.onReport,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: photos.isNotEmpty
            ? PageView.builder(
                itemCount: photos.length,
                onPageChanged: (index) => setState(() {
                  _currentPhoto = index;
                }),
                itemBuilder: (context, index) =>
                    CachedImage(imageUrl: photos[index]),
              )
            : Container(color: AppColors.surfaceLight),
      ),
      bottom: photos.length > 1
          ? PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(photos.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPhoto == index ? 8 : 6,
                    height: _currentPhoto == index ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPhoto == index
                          ? AppColors.primary
                          : AppColors.textHint,
                    ),
                  );
                }),
              ),
            )
          : null,
    );
  }
}

class ItemDetailContent extends StatelessWidget {
  const ItemDetailContent({super.key, required this.item});

  final RentalItemModel item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemConditionBadges(item: item),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (item.vlmTag != null) ...[
            const SizedBox(height: 4),
            Text(
              item.vlmTag!,
              style: const TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                CurrencyFormatter.format(item.dailyPrice, item.currency),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                ' ${l.perDay}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.depositAmount(
              CurrencyFormatter.format(item.deposit, item.currency),
            ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          const SafeBadge(),
          const SizedBox(height: 24),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 16),
          if (item.description != null) ...[
            Text(
              l.description,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.description!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
          ],
          ItemInfoRow(
            icon: Icons.local_shipping_outlined,
            label: l.pickup,
            value: PickupMethod.fromString(item.pickupMethod).localizedLabel(l),
          ),
          if (item.availableFrom != null && item.availableTo != null)
            ItemInfoRow(
              icon: Icons.date_range,
              label: l.available,
              value: DateFormatter.rentalPeriod(
                item.availableFrom!,
                item.availableTo!,
              ),
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class ItemConditionBadges extends StatelessWidget {
  const ItemConditionBadges({super.key, required this.item});

  final RentalItemModel item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        if (item.btVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.verified.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bluetooth,
                  size: 14,
                  color: AppColors.verified,
                ),
                const SizedBox(width: 4),
                Text(
                  l.btVerified,
                  style: const TextStyle(
                    color: AppColors.verified,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (item.conditionGrade != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l.gradeLabel(item.conditionGrade ?? ''),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class ItemBookBar extends StatelessWidget {
  const ItemBookBar({super.key, required this.item});

  final RentalItemModel item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: DolpinButton(
          label: l.bookNow,
          onPressed: () {
            context.pushNamed('reserve', pathParameters: {'itemId': item.id});
          },
        ),
      ),
    );
  }
}

class ItemInfoRow extends StatelessWidget {
  const ItemInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
