import '../../../core/constants/enums.dart';
import '../../../data/models/reservation_model.dart';

enum ReservationDetailActionType {
  openChat,
  cancel,
  confirmPickup,
  refundPaid,
  confirmReturn,
  settle,
  dispute,
}

class ReservationActionSpec {
  const ReservationActionSpec({required this.type, this.enabled = true});

  final ReservationDetailActionType type;
  final bool enabled;
}

class ReservationActionPresenter {
  const ReservationActionPresenter._();

  static List<ReservationActionSpec> actionsFor({
    required ReservationModel reservation,
    required ReservationStatus status,
    required Set<ReservationStatus> legalTargets,
    required bool isBorrower,
    required bool isLender,
    required bool canOpenChat,
  }) {
    final actions = <ReservationActionSpec>[
      ReservationActionSpec(
        type: ReservationDetailActionType.openChat,
        enabled: canOpenChat,
      ),
    ];

    if (legalTargets.contains(ReservationStatus.cancelled) &&
        status == ReservationStatus.pending) {
      actions.add(
        const ReservationActionSpec(type: ReservationDetailActionType.cancel),
      );
    }
    if (status == ReservationStatus.paid && isLender) {
      actions.add(
        const ReservationActionSpec(
          type: ReservationDetailActionType.confirmPickup,
        ),
      );
    }
    if (status == ReservationStatus.paid &&
        reservation.paymentId != null &&
        (isBorrower || isLender)) {
      actions.add(
        const ReservationActionSpec(
          type: ReservationDetailActionType.refundPaid,
        ),
      );
    }
    if (status == ReservationStatus.pickedUp && isBorrower) {
      actions.add(
        const ReservationActionSpec(
          type: ReservationDetailActionType.confirmReturn,
        ),
      );
    }
    if (status == ReservationStatus.returned && isLender) {
      actions.add(
        const ReservationActionSpec(type: ReservationDetailActionType.settle),
      );
    }
    if (legalTargets.contains(ReservationStatus.disputed)) {
      actions.add(
        const ReservationActionSpec(type: ReservationDetailActionType.dispute),
      );
    }

    return actions;
  }
}
