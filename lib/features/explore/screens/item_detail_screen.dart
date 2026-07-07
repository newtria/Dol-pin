import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/share_helper.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/rental_item_model.dart';
import '../../../providers/rental_provider.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/safe_badge.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/dolpin_button.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/dialogs/report_dialog.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(rentalDetailProvider(itemId));

    return Scaffold(
      body: itemAsync.when(
        data: (item) => _ItemDetailBody(item: item),
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(rentalDetailProvider(itemId)),
        ),
      ),
      bottomNavigationBar: itemAsync.whenOrNull(
        data: (item) => _BookButton(item: item),
      ),
    );
  }
}

class _ItemDetailBody extends ConsumerStatefulWidget {
  const _ItemDetailBody({required this.item});
  final RentalItemModel item;

  @override
  ConsumerState<_ItemDetailBody> createState() => _ItemDetailBodyState();
}

class _ItemDetailBodyState extends ConsumerState<_ItemDetailBody> {
  int _currentPhoto = 0;

  Future<void> _shareItem() async {
    final l = AppLocalizations.of(context)!;
    final item = widget.item;
    final price = CurrencyFormatter.format(item.dailyPrice, item.currency);
    final url = 'https://dolpin.app/item/${item.id}';
    final message = '${l.checkOutThisItem(item.title, price)}\n$url';
    await shareWithFallback(context, url: url, message: message);
  }

  Future<void> _reportItem() async {
    final l = AppLocalizations.of(context)!;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final result = await ReportDialog.show(context, widget.item.title);
    if (result != null && mounted) {
      final res = await ref
          .read(reportRepositoryProvider)
          .submitReport(
            reporterId: userId,
            reportedItemId: widget.item.id,
            reason: result['reason']!,
            description: result['description'],
          );
      if (!mounted) return;
      res.when(
        success: (_) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.reportSubmitted))),
        failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.reportFailed}: ${f.message}')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final item = widget.item;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: MediaQuery.of(context).size.width,
          pinned: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: l.share,
              onPressed: _shareItem,
            ),
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              onPressed: _reportItem,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: item.photos.isNotEmpty
                ? PageView.builder(
                    itemCount: item.photos.length,
                    onPageChanged: (i) => setState(() => _currentPhoto = i),
                    itemBuilder: (context, i) =>
                        CachedImage(imageUrl: item.photos[i]),
                  )
                : Container(color: AppColors.surfaceLight),
          ),
          bottom: item.photos.length > 1
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(item.photos.length, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPhoto == i ? 8 : 6,
                        height: _currentPhoto == i ? 8 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPhoto == i
                              ? AppColors.primary
                              : AppColors.textHint,
                        ),
                      );
                    }),
                  ),
                )
              : null,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.btVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                ),
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
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 14,
                    ),
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
                _InfoRow(
                  icon: Icons.local_shipping_outlined,
                  label: l.pickup,
                  value: PickupMethod.fromString(
                    item.pickupMethod,
                  ).localizedLabel(l),
                ),
                if (item.availableFrom != null && item.availableTo != null)
                  _InfoRow(
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
          ),
        ),
      ],
    );
  }
}

class _BookButton extends StatelessWidget {
  const _BookButton({required this.item});
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
