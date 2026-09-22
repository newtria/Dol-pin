import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/rental_item_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/safe_badge.dart';
import '../application/reservation_checkout_controller.dart';

class ReservationItemHeader extends StatelessWidget {
  const ReservationItemHeader({super.key, required this.item});

  final RentalItemModel item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: item.photos.isNotEmpty
              ? CachedImage(imageUrl: item.photos.first, width: 80, height: 80)
              : Container(width: 80, height: 80, color: AppColors.surfaceLight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${CurrencyFormatter.format(item.dailyPrice, item.currency)} ${l.perDay}',
                style: const TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReservationDateSelector extends StatelessWidget {
  const ReservationDateSelector({
    super.key,
    required this.dateRange,
    required this.days,
    required this.onTap,
  });

  final DateTimeRange? dateRange;
  final int days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
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
            Text(
              dateRange != null
                  ? DateFormatter.rentalPeriod(dateRange!.start, dateRange!.end)
                  : l.selectRentalDates,
              style: TextStyle(
                color: dateRange != null
                    ? AppColors.textPrimary
                    : AppColors.textHint,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (dateRange != null)
              Text(
                l.dayCount(days),
                style: const TextStyle(color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class ReservationPriceSummary extends StatelessWidget {
  const ReservationPriceSummary({
    super.key,
    required this.item,
    required this.quote,
  });

  final RentalItemModel item;
  final ReservationCheckoutQuote? quote;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final currency = item.currency;
    final days = quote?.days ?? 0;
    final rentalFee = quote?.rentalFee ?? 0;
    final total = quote?.total ?? item.deposit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.priceSummary,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _PriceRow(
          label: l.rentalFeeLabel(
            CurrencyFormatter.format(item.dailyPrice, currency),
            days,
          ),
          value: CurrencyFormatter.format(rentalFee, currency),
        ),
        const SizedBox(height: 8),
        _PriceRow(
          label: l.depositRefundable,
          value: CurrencyFormatter.format(item.deposit, currency),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: AppColors.divider),
        ),
        _PriceRow(
          label: l.total,
          value: CurrencyFormatter.format(total, currency),
          isBold: true,
        ),
        const SizedBox(height: 24),
        SafeBadge(label: l.escrowProtectedFull),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}
