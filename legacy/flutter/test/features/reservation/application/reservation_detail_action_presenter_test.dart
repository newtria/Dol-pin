import 'package:dolpin/core/constants/enums.dart';
import 'package:dolpin/data/models/reservation_model.dart';
import 'package:dolpin/features/reservation/application/reservation_detail_action_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReservationActionPresenter', () {
    test('keeps chat visible but disabled when chat is not available', () {
      final actions = ReservationActionPresenter.actionsFor(
        reservation: _reservation(status: ReservationStatus.pending),
        status: ReservationStatus.pending,
        legalTargets: const {},
        isBorrower: true,
        isLender: false,
        canOpenChat: false,
      );

      expect(actions.map((action) => action.type), [
        ReservationDetailActionType.openChat,
      ]);
      expect(actions.single.enabled, isFalse);
    });

    test(
      'shows cancel for pending reservations when legal target allows it',
      () {
        final actions = ReservationActionPresenter.actionsFor(
          reservation: _reservation(status: ReservationStatus.pending),
          status: ReservationStatus.pending,
          legalTargets: const {ReservationStatus.cancelled},
          isBorrower: true,
          isLender: false,
          canOpenChat: false,
        );

        expect(actions.map((action) => action.type), [
          ReservationDetailActionType.openChat,
          ReservationDetailActionType.cancel,
        ]);
      },
    );

    test('shows lender pickup and refund actions for paid reservations', () {
      final actions = ReservationActionPresenter.actionsFor(
        reservation: _reservation(
          status: ReservationStatus.paid,
          paymentId: 'imp-1',
        ),
        status: ReservationStatus.paid,
        legalTargets: const {ReservationStatus.pickedUp},
        isBorrower: false,
        isLender: true,
        canOpenChat: true,
      );

      expect(actions.map((action) => action.type), [
        ReservationDetailActionType.openChat,
        ReservationDetailActionType.confirmPickup,
        ReservationDetailActionType.refundPaid,
      ]);
      expect(actions.first.enabled, isTrue);
    });

    test('shows borrower return action after pickup', () {
      final actions = ReservationActionPresenter.actionsFor(
        reservation: _reservation(status: ReservationStatus.pickedUp),
        status: ReservationStatus.pickedUp,
        legalTargets: const {ReservationStatus.returned},
        isBorrower: true,
        isLender: false,
        canOpenChat: true,
      );

      expect(actions.map((action) => action.type), [
        ReservationDetailActionType.openChat,
        ReservationDetailActionType.confirmReturn,
      ]);
    });

    test('shows lender settle and dispute actions after return', () {
      final actions = ReservationActionPresenter.actionsFor(
        reservation: _reservation(status: ReservationStatus.returned),
        status: ReservationStatus.returned,
        legalTargets: const {
          ReservationStatus.settled,
          ReservationStatus.disputed,
        },
        isBorrower: false,
        isLender: true,
        canOpenChat: true,
      );

      expect(actions.map((action) => action.type), [
        ReservationDetailActionType.openChat,
        ReservationDetailActionType.settle,
        ReservationDetailActionType.dispute,
      ]);
    });

    test('does not show state actions for terminal reservations', () {
      final actions = ReservationActionPresenter.actionsFor(
        reservation: _reservation(status: ReservationStatus.settled),
        status: ReservationStatus.settled,
        legalTargets: const {},
        isBorrower: true,
        isLender: false,
        canOpenChat: true,
      );

      expect(actions.map((action) => action.type), [
        ReservationDetailActionType.openChat,
      ]);
    });
  });
}

ReservationModel _reservation({
  required ReservationStatus status,
  String? paymentId,
}) {
  return ReservationModel(
    id: 'reservation-1',
    itemId: 'item-1',
    borrowerId: 'borrower-1',
    lenderId: 'lender-1',
    rentalDate: DateTime(2026, 7, 8),
    returnDate: DateTime(2026, 7, 10),
    status: status.value,
    rentalFee: 5000,
    deposit: 5000,
    totalPaid: 10000,
    currency: 'KRW',
    paymentId: paymentId,
  );
}
