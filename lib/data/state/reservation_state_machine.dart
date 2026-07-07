/// Pure state machine for reservation lifecycle.
///
/// Mirrors `supabase/migrations/017_reservation_state_machine.sql`
/// `reservation_transitions` table; any change to the legal-transition
/// set MUST land in both. See `docs/escrow-state-machine.md` for the
/// authoritative diagram.
///
/// This class is a *client-side guard* — it lets the UI grey out illegal
/// buttons before the user taps. The Postgres RPC is the actual source of
/// truth; an attacker bypassing this guard will be rejected server-side.
library;

import '../../core/constants/enums.dart';

/// Who is performing the transition. Mirrors the SQL `actor_kind` CHECK.
enum TransitionActor {
  borrower,
  lender,
  system,
  admin;

  /// String used to disambiguate the actor when calling the RPC. Edge
  /// Functions and admin paths use these literals.
  String get rpcValue => name;
}

/// Legal-transition table. Lookup: `_transitions[fromStatus]?[toStatus]`
/// returns the set of actors authorised to perform that move.
const Map<ReservationStatus, Map<ReservationStatus, Set<TransitionActor>>>
_transitions = {
  ReservationStatus.pending: {
    ReservationStatus.paid: {TransitionActor.system},
    ReservationStatus.cancelled: {
      TransitionActor.borrower,
      TransitionActor.lender,
    },
  },
  ReservationStatus.paid: {
    ReservationStatus.pickedUp: {TransitionActor.lender},
    ReservationStatus.cancelled: {TransitionActor.system},
  },
  ReservationStatus.pickedUp: {
    ReservationStatus.returned: {TransitionActor.borrower},
    ReservationStatus.disputed: {
      TransitionActor.borrower,
      TransitionActor.lender,
    },
  },
  ReservationStatus.returned: {
    ReservationStatus.settled: {TransitionActor.system},
    ReservationStatus.disputed: {TransitionActor.lender},
  },
  ReservationStatus.disputed: {
    ReservationStatus.resolved: {TransitionActor.admin, TransitionActor.system},
  },
  // settled / cancelled / resolved are terminal.
};

class ReservationStateMachine {
  ReservationStateMachine._();

  /// Whether `actor` is allowed to move a reservation from `from` to `to`.
  /// Returns false for terminal-from states and for unknown actors.
  ///
  /// Idempotent self-transition (`from == to`) is true — the server RPC
  /// returns `already: true` for that case rather than failing, and the
  /// client guard should not block a double-tap on a confirm button.
  static bool canTransition({
    required ReservationStatus from,
    required ReservationStatus to,
    required TransitionActor actor,
  }) {
    if (from == to) return true;
    final allowedActors = _transitions[from]?[to];
    return allowedActors != null && allowedActors.contains(actor);
  }

  /// Convenience: all legal targets from `from` for `actor`. Empty for
  /// terminal states or when the actor has no authority.
  static Set<ReservationStatus> legalTargetsFor({
    required ReservationStatus from,
    required TransitionActor actor,
  }) {
    final map = _transitions[from];
    if (map == null) return const {};
    return {
      for (final entry in map.entries)
        if (entry.value.contains(actor)) entry.key,
    };
  }

  /// Maps a user id to its TransitionActor in the context of a given
  /// reservation. Returns null if the user is neither participant
  /// (caller should treat that as "no transitions possible"). System
  /// and admin actors are NOT resolvable by this method — those come
  /// from Edge Function code, not Flutter.
  static TransitionActor? actorFor({
    required String userId,
    required String borrowerId,
    required String lenderId,
  }) {
    if (userId == borrowerId) return TransitionActor.borrower;
    if (userId == lenderId) return TransitionActor.lender;
    return null;
  }
}
