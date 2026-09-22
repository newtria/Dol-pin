import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/reservation_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/reservation_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

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
    final reservationsAsync = ref.watch(lenderReservationsProvider(userId));

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
            return _ReservationTile(reservation: reservations[index]);
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
            return _ReservationTile(reservation: res);
          },
        );
      },
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text(l.errorPrefix(e.toString()))),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation});

  final ReservationModel reservation;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = ReservationStatus.fromString(reservation.status);
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _StatusIcon(status: status),
        title: Text(
          DateFormatter.rentalPeriod(
            reservation.rentalDate,
            reservation.returnDate,
          ),
        ),
        subtitle: Text(
          '${CurrencyFormatter.format(reservation.totalPaid, reservation.currency)} - ${status.localizedLabel(l)}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.pushNamed(
          'reservationDetail',
          pathParameters: {'id': reservation.id},
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final ReservationStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      ReservationStatus.pending => (Icons.schedule, AppColors.warning),
      ReservationStatus.paid => (Icons.check_circle_outline, AppColors.accent),
      ReservationStatus.pickedUp => (Icons.inventory_2, AppColors.primary),
      ReservationStatus.returned => (
        Icons.assignment_return,
        AppColors.success,
      ),
      ReservationStatus.settled ||
      ReservationStatus.resolved => (Icons.done_all, AppColors.success),
      ReservationStatus.disputed => (
        Icons.report_problem_outlined,
        AppColors.warning,
      ),
      ReservationStatus.cancelled => (Icons.cancel_outlined, AppColors.error),
    };
    return Icon(icon, color: color, size: 32);
  }
}
