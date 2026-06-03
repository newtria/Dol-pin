import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/database.dart';
import '../../core/constants/enums.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../../core/utils/pagination.dart';
import '../datasources/supabase_client.dart';
import '../models/reservation_model.dart';
import '../state/reservation_state_machine.dart';

final reservationRepositoryProvider =
    Provider<ReservationRepository>((ref) {
  return ReservationRepository(ref.watch(supabaseProvider));
});

class ReservationRepository {
  ReservationRepository(this._client);
  final SupabaseClient _client;

  Future<Result<ReservationModel>> create(
      Map<String, dynamic> reservation) async {
    try {
      final data = await _client
          .from(DbTables.reservations)
          .insert(reservation)
          .select()
          .single();
      return Success(ReservationModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<List<ReservationModel>>> getByBorrower(
    String borrowerId, {
    int limit = kDefaultPageLimit,
    int offset = 0,
  }) async {
    try {
      final data = await _client
          .from(DbTables.reservations)
          .select()
          .eq('borrower_id', borrowerId)
          .order('created_at', ascending: false)
          .range(safeOffset(offset), safeOffset(offset) + safeLimit(limit) - 1);
      return Success(data.map((e) => ReservationModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<List<ReservationModel>>> getByLender(
    String lenderId, {
    int limit = kDefaultPageLimit,
    int offset = 0,
  }) async {
    try {
      final data = await _client
          .from(DbTables.reservations)
          .select()
          .eq('lender_id', lenderId)
          .order('created_at', ascending: false)
          .range(safeOffset(offset), safeOffset(offset) + safeLimit(limit) - 1);
      return Success(data.map((e) => ReservationModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<ReservationModel>> getById(String id) async {
    try {
      final data = await _client
          .from(DbTables.reservations)
          .select()
          .eq('id', id)
          .single();
      return Success(ReservationModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  /// Calls the `transition_reservation_status` RPC (migration 017).
  /// Server-side validation rejects illegal moves; this method returns
  /// the resulting status on success (which may equal the prior status
  /// for an idempotent re-call).
  ///
  /// Direct UPDATE on `reservations.status` is blocked by a trigger;
  /// this is the only Flutter-side path to change state.
  Future<Result<ReservationStatus>> transition({
    required String reservationId,
    required ReservationStatus target,
    String? reason,
  }) async {
    try {
      final response = await _client.rpc(
        'transition_reservation_status',
        params: {
          'p_reservation_id': reservationId,
          'p_target': target.value,
          'p_reason': reason,
        },
      );
      final row = response as Map<String, dynamic>?;
      if (row == null) {
        return const Fail(ServerFailure('Empty RPC response'));
      }
      if (row['ok'] != true) {
        return Fail(ValidationFailure(
          row['error']?.toString() ?? 'Transition rejected',
        ));
      }
      return Success(ReservationStatus.fromString(row['status'] as String));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  /// Lender confirms the borrower picked the item up. The RPC stamps
  /// `pickup_confirmed_at` server-side.
  Future<Result<ReservationStatus>> confirmPickup(String id) =>
      transition(reservationId: id, target: ReservationStatus.pickedUp);

  /// Borrower reports the item returned. The RPC stamps
  /// `return_confirmed_at` server-side. The optional `returnPhoto`
  /// upload happens as a SEPARATE direct UPDATE on the photo column
  /// (the trigger only gates `status`).
  Future<Result<ReservationStatus>> confirmReturn(
    String id, {
    String? returnPhoto,
  }) async {
    final result = await transition(
      reservationId: id,
      target: ReservationStatus.returned,
    );
    if (result.isFailure) return result;
    if (returnPhoto != null) {
      try {
        await _client
            .from(DbTables.reservations)
            .update({'return_photo': returnPhoto})
            .eq('id', id);
      } catch (_) {
        // Photo is evidence the lender can also re-capture from their
        // side; do not roll back the state on a photo-upload failure.
      }
    }
    return result;
  }

  /// Cancellation entry point. The caller is responsible for invoking the
  /// `refund-payment` Edge Function on the resulting `cancelled` state
  /// when money was already held (i.e. `from == paid`).
  Future<Result<ReservationStatus>> cancel(String id) =>
      transition(reservationId: id, target: ReservationStatus.cancelled);

  /// Either party can raise a dispute. The platform freezes escrow until
  /// admin resolution; no money moves automatically.
  Future<Result<ReservationStatus>> dispute(
    String id, {
    String? reason,
  }) =>
      transition(
        reservationId: id,
        target: ReservationStatus.disputed,
        reason: reason,
      );

  /// Convenience for UI: legal next states for the given user. Empty if
  /// the user is neither participant or if the reservation is terminal.
  Set<ReservationStatus> legalNextStates({
    required ReservationModel reservation,
    required String userId,
  }) {
    final actor = ReservationStateMachine.actorFor(
      userId: userId,
      borrowerId: reservation.borrowerId,
      lenderId: reservation.lenderId,
    );
    if (actor == null) return const {};
    return ReservationStateMachine.legalTargetsFor(
      from: ReservationStatus.fromString(reservation.status),
      actor: actor,
    );
  }
}
