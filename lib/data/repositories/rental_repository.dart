import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/database.dart';
import '../../core/constants/enums.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../../core/utils/pagination.dart';
import '../datasources/supabase_client.dart';
import '../models/rental_item_model.dart';

final rentalRepositoryProvider = Provider<RentalRepository>((ref) {
  return RentalRepository(ref.watch(supabaseProvider));
});

class RentalRepository {
  RentalRepository(this._client);
  final SupabaseClient _client;

  Future<Result<List<RentalItemModel>>> getByConcert(
    String concertId, {
    int limit = kDefaultPageLimit,
    int offset = 0,
  }) async {
    try {
      final data = await _client
          .from(DbTables.rentalItems)
          .select()
          .eq('concert_id', concertId)
          .eq('status', ItemStatus.active.name)
          .order('created_at', ascending: false)
          .range(safeOffset(offset), safeOffset(offset) + safeLimit(limit) - 1);
      return Success(data.map((e) => RentalItemModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<List<RentalItemModel>>> getByCategory(
    String category, {
    int limit = kDefaultPageLimit,
    int offset = 0,
  }) async {
    try {
      final data = await _client
          .from(DbTables.rentalItems)
          .select()
          .eq('category', category)
          .eq('status', ItemStatus.active.name)
          .order('created_at', ascending: false)
          .range(safeOffset(offset), safeOffset(offset) + safeLimit(limit) - 1);
      return Success(data.map((e) => RentalItemModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<List<RentalItemModel>>> getFiltered({
    String? concertId,
    String? category,
    String? searchQuery,
    int limit = kDefaultPageLimit,
    int offset = 0,
  }) async {
    final safeQuery = searchQuery == null
        ? null
        : _sanitizeSearchQuery(searchQuery);
    try {
      var query = _client
          .from(DbTables.rentalItems)
          .select()
          .eq('status', ItemStatus.active.name);
      if (concertId != null && concertId.isNotEmpty) {
        query = query.eq('concert_id', concertId);
      }
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (safeQuery != null && safeQuery.isNotEmpty) {
        query = query.or(
          'title.ilike.%$safeQuery%,description.ilike.%$safeQuery%',
        );
      }
      final data = await query
          .order('created_at', ascending: false)
          .range(safeOffset(offset), safeOffset(offset) + safeLimit(limit) - 1);
      return Success(data.map((e) => RentalItemModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<RentalItemModel>> getById(String id) async {
    try {
      final data = await _client
          .from(DbTables.rentalItems)
          .select()
          .eq('id', id)
          .single();
      return Success(RentalItemModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<List<RentalItemModel>>> getByLender(
    String lenderId, {
    int limit = kDefaultPageLimit,
    int offset = 0,
  }) async {
    try {
      final data = await _client
          .from(DbTables.rentalItems)
          .select()
          .eq('lender_id', lenderId)
          .order('created_at', ascending: false)
          .range(safeOffset(offset), safeOffset(offset) + safeLimit(limit) - 1);
      return Success(data.map((e) => RentalItemModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<RentalItemModel>> create(Map<String, dynamic> item) async {
    try {
      final data = await _client
          .from(DbTables.rentalItems)
          .insert(item)
          .select()
          .single();
      return Success(RentalItemModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  /// PostgREST `or()` parses commas / parens / colons / `*` as filter syntax,
  /// and `%` / `_` are LIKE wildcards. Both surfaces are user-controlled in
  /// search input, so we strip them before interpolating into the filter
  /// expression. Empty queries (after sanitization) return an empty result
  /// instead of matching every active item via `%%`.
  static String _sanitizeSearchQuery(String raw) {
    final stripped = raw.replaceAll(RegExp(r'[%_,():\*]'), '').trim();
    // Defense in depth: cap length so a pathological input cannot inflate the
    // PostgREST request line beyond reasonable bounds.
    if (stripped.length > 100) return stripped.substring(0, 100);
    return stripped;
  }

  Future<Result<List<RentalItemModel>>> search(
    String query, {
    int limit = kDefaultPageLimit,
    int offset = 0,
  }) async {
    final safeQuery = _sanitizeSearchQuery(query);
    if (safeQuery.isEmpty) {
      return const Success(<RentalItemModel>[]);
    }
    try {
      final data = await _client
          .from(DbTables.rentalItems)
          .select()
          .eq('status', ItemStatus.active.name)
          .or('title.ilike.%$safeQuery%,description.ilike.%$safeQuery%')
          .order('created_at', ascending: false)
          .range(safeOffset(offset), safeOffset(offset) + safeLimit(limit) - 1);
      return Success(data.map((e) => RentalItemModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<void>> updateStatus(String id, ItemStatus status) async {
    try {
      await _client
          .from(DbTables.rentalItems)
          .update({'status': status.name})
          .eq('id', id);
      return const Success(null);
    } catch (e) {
      return Fail(mapException(e));
    }
  }
}
