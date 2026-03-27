import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/result.dart';
import '../core/utils/paginated_notifier.dart';
import '../core/utils/paginated_state.dart';
import '../data/models/rental_item_model.dart';
import '../data/repositories/rental_repository.dart';

final rentalsByConcertProvider = FutureProvider.autoDispose
    .family<List<RentalItemModel>, String>((ref, concertId) async {
  final result =
      await ref.watch(rentalRepositoryProvider).getByConcert(concertId);
  return result.when(
    success: (items) => items,
    failure: (f) => throw f,
  );
});

final rentalsByCategoryProvider = FutureProvider.autoDispose
    .family<List<RentalItemModel>, String>((ref, category) async {
  final result =
      await ref.watch(rentalRepositoryProvider).getByCategory(category);
  return result.when(
    success: (items) => items,
    failure: (f) => throw f,
  );
});

final rentalDetailProvider = FutureProvider.autoDispose
    .family<RentalItemModel, String>((ref, id) async {
  final result = await ref.watch(rentalRepositoryProvider).getById(id);
  return result.when(
    success: (item) => item,
    failure: (f) => throw f,
  );
});

final myRentalsProvider = FutureProvider.autoDispose
    .family<List<RentalItemModel>, String>((ref, lenderId) async {
  final result =
      await ref.watch(rentalRepositoryProvider).getByLender(lenderId);
  return result.when(
    success: (items) => items,
    failure: (f) => throw f,
  );
});

final rentalSearchProvider = FutureProvider.autoDispose
    .family<List<RentalItemModel>, String>((ref, query) async {
  final result = await ref.watch(rentalRepositoryProvider).search(query);
  return result.when(
    success: (items) => items,
    failure: (f) => throw f,
  );
});

// ---------------------------------------------------------------------------
// Paginated variants
// ---------------------------------------------------------------------------

final paginatedRentalsByCategoryProvider = AsyncNotifierProvider.autoDispose
    .family<PaginatedRentalsByCategoryNotifier, PaginatedState<RentalItemModel>,
        String>(
  PaginatedRentalsByCategoryNotifier.new,
);

class PaginatedRentalsByCategoryNotifier
    extends PaginatedFamilyAsyncNotifier<RentalItemModel, String> {
  @override
  Future<PaginatedState<RentalItemModel>> build(String arg) => buildInitial();

  @override
  Future<Result<List<RentalItemModel>>> fetchPage(int offset, int limit) {
    return ref
        .read(rentalRepositoryProvider)
        .getByCategory(arg, limit: limit, offset: offset);
  }
}

final paginatedRentalsByConcertProvider = AsyncNotifierProvider.autoDispose
    .family<PaginatedRentalsByConcertNotifier, PaginatedState<RentalItemModel>,
        String>(
  PaginatedRentalsByConcertNotifier.new,
);

class PaginatedRentalsByConcertNotifier
    extends PaginatedFamilyAsyncNotifier<RentalItemModel, String> {
  @override
  Future<PaginatedState<RentalItemModel>> build(String arg) => buildInitial();

  @override
  Future<Result<List<RentalItemModel>>> fetchPage(int offset, int limit) {
    return ref
        .read(rentalRepositoryProvider)
        .getByConcert(arg, limit: limit, offset: offset);
  }
}
