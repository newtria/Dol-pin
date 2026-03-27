import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/result.dart';
import '../core/utils/paginated_notifier.dart';
import '../core/utils/paginated_state.dart';
import '../data/models/concert_model.dart';
import '../data/repositories/concert_repository.dart';

final upcomingConcertsProvider = FutureProvider.autoDispose
    .family<List<ConcertModel>, String?>((ref, country) async {
  final result =
      await ref.watch(concertRepositoryProvider).getUpcoming(country: country);
  return result.when(
    success: (concerts) => concerts,
    failure: (f) => throw f,
  );
});

final concertDetailProvider = FutureProvider.autoDispose
    .family<ConcertModel, String>((ref, id) async {
  final result = await ref.watch(concertRepositoryProvider).getById(id);
  return result.when(
    success: (concert) => concert,
    failure: (f) => throw f,
  );
});

// ---------------------------------------------------------------------------
// Paginated variants
// ---------------------------------------------------------------------------

final paginatedUpcomingConcertsProvider = AsyncNotifierProvider.autoDispose
    .family<PaginatedUpcomingConcertsNotifier, PaginatedState<ConcertModel>,
        String?>(
  PaginatedUpcomingConcertsNotifier.new,
);

class PaginatedUpcomingConcertsNotifier
    extends PaginatedFamilyAsyncNotifier<ConcertModel, String?> {
  @override
  Future<PaginatedState<ConcertModel>> build(String? arg) => buildInitial();

  @override
  Future<Result<List<ConcertModel>>> fetchPage(int offset, int limit) {
    return ref
        .read(concertRepositoryProvider)
        .getUpcoming(country: arg, limit: limit, offset: offset);
  }
}
