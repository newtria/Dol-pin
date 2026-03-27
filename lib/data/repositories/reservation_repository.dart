import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/database.dart';
import '../../core/constants/enums.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../../core/utils/pagination.dart';
import '../datasources/supabase_client.dart';
import '../models/reservation_model.dart';

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

  Future<Result<void>> updateStatus(
      String id, ReservationStatus status) async {
    try {
      await _client
          .from(DbTables.reservations)
          .update({'status': status.value}).eq('id', id);
      return const Success(null);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<void>> confirmPickup(String id) async {
    try {
      await _client.from(DbTables.reservations).update({
        'status': ReservationStatus.pickedUp.value,
        'pickup_confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return const Success(null);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<void>> confirmReturn(String id, {String? returnPhoto}) async {
    try {
      final updates = <String, dynamic>{
        'status': ReservationStatus.returned_.value,
        'return_confirmed_at': DateTime.now().toIso8601String(),
      };
      if (returnPhoto != null) updates['return_photo'] = returnPhoto;
      await _client
          .from(DbTables.reservations)
          .update(updates)
          .eq('id', id);
      return const Success(null);
    } catch (e) {
      return Fail(mapException(e));
    }
  }
}
