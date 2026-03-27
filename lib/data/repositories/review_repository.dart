import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/database.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../datasources/supabase_client.dart';
import '../models/review_model.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(supabaseProvider));
});

class ReviewRepository {
  ReviewRepository(this._client);
  final SupabaseClient _client;

  Future<Result<List<ReviewModel>>> getByUser(String userId) async {
    try {
      final data = await _client
          .from(DbTables.reviews)
          .select()
          .eq('reviewee_id', userId)
          .order('created_at', ascending: false);
      return Success(data.map((e) => ReviewModel.fromJson(e)).toList());
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<ReviewModel>> create(Map<String, dynamic> review) async {
    try {
      final data = await _client
          .from(DbTables.reviews)
          .insert(review)
          .select()
          .single();
      return Success(ReviewModel.fromJson(data));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  Future<Result<double>> getAverageRating(String userId) async {
    try {
      final data = await _client
          .from(DbTables.reviews)
          .select('rating')
          .eq('reviewee_id', userId);
      if (data.isEmpty) return const Success(0);
      final sum = data.fold<int>(0, (sum, e) => sum + (e['rating'] as int));
      return Success(sum / data.length);
    } catch (e) {
      return Fail(mapException(e));
    }
  }
}
