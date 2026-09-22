import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/result.dart';
import '../core/utils/paginated_notifier.dart';
import '../core/utils/paginated_state.dart';
import '../data/models/rental_item_model.dart';
import '../data/repositories/rental_repository.dart';

class RentalFilter {
  const RentalFilter({this.concertId, this.category, this.searchQuery});

  final String? concertId;
  final String? category;
  final String? searchQuery;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentalFilter &&
          runtimeType == other.runtimeType &&
          concertId == other.concertId &&
          category == other.category &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(concertId, category, searchQuery);
}

final rentalsByConcertProvider = FutureProvider.autoDispose
    .family<List<RentalItemModel>, String>((ref, concertId) async {
      final result = await ref
          .watch(rentalRepositoryProvider)
          .getByConcert(concertId);
      return result.when(success: (items) => items, failure: (f) => throw f);
    });

final rentalsByCategoryProvider = FutureProvider.autoDispose
    .family<List<RentalItemModel>, String>((ref, category) async {
      final result = await ref
          .watch(rentalRepositoryProvider)
          .getByCategory(category);
      return result.when(success: (items) => items, failure: (f) => throw f);
    });

final rentalDetailProvider = FutureProvider.autoDispose
    .family<RentalItemModel, String>((ref, id) async {
      final result = await ref.watch(rentalRepositoryProvider).getById(id);
      return result.when(success: (item) => item, failure: (f) => throw f);
    });

final myRentalsProvider = FutureProvider.autoDispose
    .family<List<RentalItemModel>, String>((ref, lenderId) async {
      final result = await ref
          .watch(rentalRepositoryProvider)
          .getByLender(lenderId);
      return result.when(success: (items) => items, failure: (f) => throw f);
    });

final rentalSearchProvider = FutureProvider.autoDispose
    .family<List<RentalItemModel>, String>((ref, query) async {
      final result = await ref.watch(rentalRepositoryProvider).search(query);
      return result.when(success: (items) => items, failure: (f) => throw f);
    });

final paginatedRentalsFilterProvider = AsyncNotifierProvider.autoDispose
    .family<
      PaginatedRentalsFilterNotifier,
      PaginatedState<RentalItemModel>,
      RentalFilter
    >(PaginatedRentalsFilterNotifier.new);

class PaginatedRentalsFilterNotifier
    extends PaginatedFamilyAsyncNotifier<RentalItemModel, RentalFilter> {
  @override
  Future<PaginatedState<RentalItemModel>> build(RentalFilter arg) =>
      buildInitial();

  @override
  Future<Result<List<RentalItemModel>>> fetchPage(int offset, int limit) {
    return ref
        .read(rentalRepositoryProvider)
        .getFiltered(
          concertId: arg.concertId,
          category: arg.category,
          searchQuery: arg.searchQuery,
          limit: limit,
          offset: offset,
        );
  }
}

// ---------------------------------------------------------------------------
// Paginated variants
// ---------------------------------------------------------------------------

final paginatedRentalsByCategoryProvider = AsyncNotifierProvider.autoDispose
    .family<
      PaginatedRentalsByCategoryNotifier,
      PaginatedState<RentalItemModel>,
      String
    >(PaginatedRentalsByCategoryNotifier.new);

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
    .family<
      PaginatedRentalsByConcertNotifier,
      PaginatedState<RentalItemModel>,
      String
    >(PaginatedRentalsByConcertNotifier.new);

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
