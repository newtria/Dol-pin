import 'package:dolpin/core/constants/enums.dart';
import 'package:dolpin/data/state/reservation_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReservationStateMachine.canTransition', () {
    test('pending → paid is system-only', () {
      expect(
        ReservationStateMachine.canTransition(
          from: ReservationStatus.pending,
          to: ReservationStatus.paid,
          actor: TransitionActor.system,
        ),
        isTrue,
      );
      for (final actor in [
        TransitionActor.borrower,
        TransitionActor.lender,
        TransitionActor.admin,
      ]) {
        expect(
          ReservationStateMachine.canTransition(
            from: ReservationStatus.pending,
            to: ReservationStatus.paid,
            actor: actor,
          ),
          isFalse,
          reason: 'actor=$actor must not be able to mark pending→paid',
        );
      }
    });

    test('paid → picked_up only by lender', () {
      expect(
        ReservationStateMachine.canTransition(
          from: ReservationStatus.paid,
          to: ReservationStatus.pickedUp,
          actor: TransitionActor.lender,
        ),
        isTrue,
      );
      expect(
        ReservationStateMachine.canTransition(
          from: ReservationStatus.paid,
          to: ReservationStatus.pickedUp,
          actor: TransitionActor.borrower,
        ),
        isFalse,
        reason: 'borrower must not be able to claim their own pickup',
      );
    });

    test('picked_up → returned only by borrower', () {
      expect(
        ReservationStateMachine.canTransition(
          from: ReservationStatus.pickedUp,
          to: ReservationStatus.returned,
          actor: TransitionActor.borrower,
        ),
        isTrue,
      );
      expect(
        ReservationStateMachine.canTransition(
          from: ReservationStatus.pickedUp,
          to: ReservationStatus.returned,
          actor: TransitionActor.lender,
        ),
        isFalse,
        reason: 'lender must not be able to mark a return without borrower',
      );
    });

    test('returned → settled by lender OR system', () {
      expect(
        ReservationStateMachine.canTransition(
          from: ReservationStatus.returned,
          to: ReservationStatus.settled,
          actor: TransitionActor.lender,
        ),
        isTrue,
      );
      expect(
        ReservationStateMachine.canTransition(
          from: ReservationStatus.returned,
          to: ReservationStatus.settled,
          actor: TransitionActor.system,
        ),
        isTrue,
      );
      expect(
        ReservationStateMachine.canTransition(
          from: ReservationStatus.returned,
          to: ReservationStatus.settled,
          actor: TransitionActor.borrower,
        ),
        isFalse,
        reason: 'borrower must not be able to force-settle',
      );
    });

    test('disputed → resolved only by admin OR system', () {
      expect(
        ReservationStateMachine.canTransition(
          from: ReservationStatus.disputed,
          to: ReservationStatus.resolved,
          actor: TransitionActor.admin,
        ),
        isTrue,
      );
      for (final actor in [TransitionActor.borrower, TransitionActor.lender]) {
        expect(
          ReservationStateMachine.canTransition(
            from: ReservationStatus.disputed,
            to: ReservationStatus.resolved,
            actor: actor,
          ),
          isFalse,
          reason: 'participants cannot self-resolve disputes',
        );
      }
    });

    test('terminal states cannot transition out', () {
      const terminals = [
        ReservationStatus.settled,
        ReservationStatus.cancelled,
        ReservationStatus.resolved,
      ];
      for (final from in terminals) {
        for (final to in ReservationStatus.values) {
          if (from == to) continue; // idempotent self-transition
          for (final actor in TransitionActor.values) {
            expect(
              ReservationStateMachine.canTransition(
                from: from,
                to: to,
                actor: actor,
              ),
              isFalse,
              reason: '$from is terminal but $actor could move it to $to',
            );
          }
        }
      }
    });

    test('idempotent self-transition is always legal', () {
      for (final state in ReservationStatus.values) {
        for (final actor in TransitionActor.values) {
          expect(
            ReservationStateMachine.canTransition(
              from: state,
              to: state,
              actor: actor,
            ),
            isTrue,
            reason: 'same-state transition must be legal for $actor on $state',
          );
        }
      }
    });

    test('skipping states is illegal', () {
      // pending → picked_up (skip paid) is impossible — no actor.
      for (final actor in TransitionActor.values) {
        expect(
          ReservationStateMachine.canTransition(
            from: ReservationStatus.pending,
            to: ReservationStatus.pickedUp,
            actor: actor,
          ),
          isFalse,
          reason: '$actor must not skip the payment step',
        );
      }
      // paid → returned (skip picked_up) is impossible.
      for (final actor in TransitionActor.values) {
        expect(
          ReservationStateMachine.canTransition(
            from: ReservationStatus.paid,
            to: ReservationStatus.returned,
            actor: actor,
          ),
          isFalse,
          reason: '$actor must not skip the pickup step',
        );
      }
      // returned → cancelled is impossible — money has already moved.
      for (final actor in TransitionActor.values) {
        expect(
          ReservationStateMachine.canTransition(
            from: ReservationStatus.returned,
            to: ReservationStatus.cancelled,
            actor: actor,
          ),
          isFalse,
          reason:
              '$actor must not cancel a returned reservation — use settled/disputed',
        );
      }
    });

    test('backwards transitions are illegal', () {
      // picked_up → paid (revert pickup evidence) is impossible.
      for (final actor in TransitionActor.values) {
        expect(
          ReservationStateMachine.canTransition(
            from: ReservationStatus.pickedUp,
            to: ReservationStatus.paid,
            actor: actor,
          ),
          isFalse,
        );
      }
      // returned → picked_up is impossible.
      for (final actor in TransitionActor.values) {
        expect(
          ReservationStateMachine.canTransition(
            from: ReservationStatus.returned,
            to: ReservationStatus.pickedUp,
            actor: actor,
          ),
          isFalse,
        );
      }
    });
  });

  group('ReservationStateMachine.legalTargetsFor', () {
    test('terminal states have no legal targets', () {
      for (final terminal in [
        ReservationStatus.settled,
        ReservationStatus.cancelled,
        ReservationStatus.resolved,
      ]) {
        for (final actor in TransitionActor.values) {
          expect(
            ReservationStateMachine.legalTargetsFor(
              from: terminal,
              actor: actor,
            ),
            isEmpty,
          );
        }
      }
    });

    test('borrower from paid: cancelled only', () {
      expect(
        ReservationStateMachine.legalTargetsFor(
          from: ReservationStatus.paid,
          actor: TransitionActor.borrower,
        ),
        equals({ReservationStatus.cancelled}),
      );
    });

    test('lender from paid: pickedUp + cancelled', () {
      expect(
        ReservationStateMachine.legalTargetsFor(
          from: ReservationStatus.paid,
          actor: TransitionActor.lender,
        ),
        equals({ReservationStatus.pickedUp, ReservationStatus.cancelled}),
      );
    });

    test('lender from returned: settled + disputed', () {
      expect(
        ReservationStateMachine.legalTargetsFor(
          from: ReservationStatus.returned,
          actor: TransitionActor.lender,
        ),
        equals({ReservationStatus.settled, ReservationStatus.disputed}),
      );
    });

    test('borrower from returned: empty (no authority)', () {
      // The borrower has reported the return; the lender owns the next move.
      expect(
        ReservationStateMachine.legalTargetsFor(
          from: ReservationStatus.returned,
          actor: TransitionActor.borrower,
        ),
        isEmpty,
      );
    });
  });

  group('ReservationStateMachine.actorFor', () {
    test('borrower id resolves to borrower', () {
      expect(
        ReservationStateMachine.actorFor(
          userId: 'u-borrower',
          borrowerId: 'u-borrower',
          lenderId: 'u-lender',
        ),
        TransitionActor.borrower,
      );
    });
    test('lender id resolves to lender', () {
      expect(
        ReservationStateMachine.actorFor(
          userId: 'u-lender',
          borrowerId: 'u-borrower',
          lenderId: 'u-lender',
        ),
        TransitionActor.lender,
      );
    });
    test('non-participant resolves to null', () {
      expect(
        ReservationStateMachine.actorFor(
          userId: 'u-stranger',
          borrowerId: 'u-borrower',
          lenderId: 'u-lender',
        ),
        isNull,
      );
    });
    test('does not return system or admin (those come from server only)', () {
      // Even with a service-role-shaped id, this client-side helper must
      // never resolve to system/admin. Those actors come from Edge
      // Functions calling the RPC with explicit `p_actor_kind`.
      final actor = ReservationStateMachine.actorFor(
        userId: '00000000-0000-0000-0000-000000000000',
        borrowerId: 'u-borrower',
        lenderId: 'u-lender',
      );
      expect(actor, isNot(TransitionActor.system));
      expect(actor, isNot(TransitionActor.admin));
    });
  });

  group('ReservationStatus.isTerminal', () {
    test('settled / cancelled / resolved are terminal', () {
      expect(ReservationStatus.settled.isTerminal, isTrue);
      expect(ReservationStatus.cancelled.isTerminal, isTrue);
      expect(ReservationStatus.resolved.isTerminal, isTrue);
    });
    test('non-terminal states', () {
      for (final s in [
        ReservationStatus.pending,
        ReservationStatus.paid,
        ReservationStatus.pickedUp,
        ReservationStatus.returned,
        ReservationStatus.disputed,
      ]) {
        expect(s.isTerminal, isFalse, reason: '$s should not be terminal');
      }
    });
  });
}
