import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/database.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../datasources/supabase_client.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(supabaseProvider));
});

class ReportRepository {
  ReportRepository(this._client);
  final SupabaseClient _client;

  Future<Result<void>> submitReport({
    required String reporterId,
    String? reportedUserId,
    String? reportedItemId,
    required String reason,
    String? description,
  }) async {
    try {
      await _client.from(DbTables.reports).insert({
        'reporter_id': reporterId,
        'reported_user_id': reportedUserId,
        'reported_item_id': reportedItemId,
        'reason': reason,
        'description': description,
      });
      return const Success(null);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<void>> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _client.from(DbTables.userBlocks).upsert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
      return const Success(null);
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<void>> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _client
          .from(DbTables.userBlocks)
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId);
      return const Success(null);
    } catch (e) {
      return Fail(mapException(e));
    }
  }
}
