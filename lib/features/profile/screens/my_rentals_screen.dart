import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/rental_provider.dart';
import '../../../providers/reservation_provider.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../core/utils/formatters.dart';

class MyRentalsScreen extends ConsumerWidget {
  const MyRentalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserIdProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.myRentals),
          bottom: TabBar(
            tabs: [
              Tab(text: l.asLender),
              Tab(text: l.asBorrower),
            ],
          ),
        ),
        body: userId == null
            ? Center(child: Text(l.pleaseLogIn))
            : TabBarView(
                children: [
                  _LenderTab(userId: userId),
                  _BorrowerTab(userId: userId),
                ],
              ),
      ),
    );
  }
}

class _LenderTab extends ConsumerWidget {
  const _LenderTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(myRentalsProvider(userId));

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              l.noItemsRegistered,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              color: AppColors.card,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.photos.isNotEmpty
                      ? CachedImage(
                          imageUrl: item.photos.first,
                          width: 56,
                          height: 56,
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: AppColors.surfaceLight,
                          child: const Icon(Icons.image),
                        ),
                ),
                title: Text(item.title),
                subtitle: Text(
                  '${CurrencyFormatter.format(item.dailyPrice, item.currency)}/day - ${item.status}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  'itemDetail',
                  pathParameters: {'id': item.id},
                ),
              ),
            );
          },
        );
      },
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text(l.errorPrefix(e.toString()))),
    );
  }
}

class _BorrowerTab extends ConsumerWidget {
  const _BorrowerTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final reservationsAsync = ref.watch(borrowerReservationsProvider(userId));

    return reservationsAsync.when(
      data: (reservations) {
        if (reservations.isEmpty) {
          return Center(
            child: Text(
              l.noReservationsYet,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final res = reservations[index];
            return Card(
              color: AppColors.card,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: _StatusIcon(status: res.status),
                title: Text(
                  DateFormatter.rentalPeriod(res.rentalDate, res.returnDate),
                ),
                subtitle: Text(
                  '${CurrencyFormatter.format(res.totalPaid, res.currency)} - ${res.status}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            );
          },
        );
      },
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text(l.errorPrefix(e.toString()))),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'pending' => (Icons.schedule, AppColors.warning),
      'accepted' || 'paid' => (Icons.check_circle_outline, AppColors.accent),
      'picked_up' => (Icons.inventory_2, AppColors.primary),
      'returned' || 'completed' => (Icons.done_all, AppColors.success),
      'rejected' || 'cancelled' => (Icons.cancel_outlined, AppColors.error),
      _ => (Icons.help_outline, AppColors.textHint),
    };
    return Icon(icon, color: color, size: 32);
  }
}
