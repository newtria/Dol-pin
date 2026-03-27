import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/database.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../datasources/supabase_client.dart';
import '../models/concert_model.dart';

final concertRepositoryProvider = Provider<ConcertRepository>((ref) {
  return ConcertRepository(ref.watch(supabaseProvider));
});

class ConcertRepository {
  ConcertRepository(this._client);
  final SupabaseClient _client;

  static const _defaultLimit = 20;

  Future<Result<List<ConcertModel>>> getUpcoming({
    String? country,
    int limit = _defaultLimit,
    int offset = 0,
  }) async {
    try {
      var query = _client
          .from(DbTables.concerts)
          .select()
          .gte('concert_date', DateTime.now().toIso8601String());

      if (country != null) {
        query = query.eq('country', country);
      }

      final data = await query
          .order('concert_date')
          .range(offset, offset + limit - 1);
      return Success(data.map((e) => ConcertModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<ConcertModel>> getById(String id) async {
    try {
      final data = await _client
          .from(DbTables.concerts)
          .select()
          .eq('id', id)
          .single();
      return Success(ConcertModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<List<ConcertModel>>> searchByArtist(
    String artist, {
    int limit = _defaultLimit,
    int offset = 0,
  }) async {
    try {
      final data = await _client
          .from(DbTables.concerts)
          .select()
          .ilike('artist', '%$artist%')
          .order('concert_date')
          .range(offset, offset + limit - 1);
      return Success(data.map((e) => ConcertModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }
}
