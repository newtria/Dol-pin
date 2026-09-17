import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/reservation_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dolpin_button.dart';
import '../application/reservation_detail_action_presenter.dart';

class ReservationStatusHeader extends StatelessWidget {
  const ReservationStatusHeader({super.key, required this.status});

  final ReservationStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_iconFor(status), color: _colorFor(status), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status.localizedLabel(l),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ReservationStatus status) => switch (status) {
    ReservationStatus.pending => Icons.schedule,
    ReservationStatus.paid => Icons.check_circle_outline,
    ReservationStatus.pickedUp => Icons.inventory_2,
    ReservationStatus.returned => Icons.assignment_return,
    ReservationStatus.settled || ReservationStatus.resolved => Icons.done_all,
    ReservationStatus.cancelled => Icons.cancel_outlined,
    ReservationStatus.disputed => Icons.report_problem_outlined,
  };

  Color _colorFor(ReservationStatus status) => switch (status) {
    ReservationStatus.pending => AppColors.warning,
    ReservationStatus.paid => AppColors.accent,
    ReservationStatus.pickedUp => AppColors.primary,
    ReservationStatus.returned => AppColors.success,
    ReservationStatus.settled ||
    ReservationStatus.resolved => AppColors.success,
    ReservationStatus.cancelled => AppColors.error,
    ReservationStatus.disputed => AppColors.warning,
  };
}

class ReservationDetailsSummary extends StatelessWidget {
  const ReservationDetailsSummary({super.key, required this.reservation});

  final ReservationModel reservation;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        ReservationInfoRow(
          label: l.selectRentalDates,
          value: DateFormatter.rentalPeriod(
            reservation.rentalDate,
            reservation.returnDate,
          ),
        ),
        ReservationInfoRow(
          label: l.total,
          value: CurrencyFormatter.format(
            reservation.totalPaid,
            reservation.currency,
          ),
        ),
        ReservationInfoRow(label: l.reservationId, value: reservation.id),
        if (reservation.paymentId != null)
          ReservationInfoRow(label: l.paymentId, value: reservation.paymentId!),
      ],
    );
  }
}

class ReservationActionButtons extends StatelessWidget {
  const ReservationActionButtons({
    super.key,
    required this.actions,
    required this.isBusy,
    required this.onAction,
  });

  final List<ReservationActionSpec> actions;
  final bool isBusy;
  final ValueChanged<ReservationDetailActionType> onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in actions)
          _ActionButton(action: action, isBusy: isBusy, onAction: onAction),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.isBusy,
    required this.onAction,
  });

  final ReservationActionSpec action;
  final bool isBusy;
  final ValueChanged<ReservationDetailActionType> onAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final onPressed = isBusy || !action.enabled
        ? null
        : () => onAction(action.type);

    return switch (action.type) {
      ReservationDetailActionType.openChat => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(l.openChat),
        ),
      ),
      ReservationDetailActionType.cancel => DolpinButton(
        label: l.cancel,
        isLoading: isBusy,
        onPressed: onPressed,
      ),
      ReservationDetailActionType.confirmPickup => DolpinButton(
        label: l.confirmPickup,
        isLoading: isBusy,
        onPressed: onPressed,
      ),
      ReservationDetailActionType.refundPaid => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton(
          onPressed: onPressed,
          child: Text(l.cancelAndRefund),
        ),
      ),
      ReservationDetailActionType.confirmReturn => DolpinButton(
        label: l.confirmReturn,
        isLoading: isBusy,
        onPressed: onPressed,
      ),
      ReservationDetailActionType.settle => DolpinButton(
        label: l.settleDeposit,
        isLoading: isBusy,
        onPressed: onPressed,
      ),
      ReservationDetailActionType.dispute => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton(onPressed: onPressed, child: Text(l.openDispute)),
      ),
    };
  }
}

class ReservationInfoRow extends StatelessWidget {
  const ReservationInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
