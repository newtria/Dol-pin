import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/result.dart';
import 'paginated_state.dart';

/// Page size shared by all paginated notifiers.
const kPaginatedPageSize = 20;

/// Base class for paginated family async notifiers.
///
/// [T] is the item type, [A] is the family argument type.
/// Subclasses must implement [fetchPage] and [build].
abstract class PaginatedFamilyAsyncNotifier<T, A>
    extends AutoDisposeFamilyAsyncNotifier<PaginatedState<T>, A> {
  /// Fetch a single page of data starting at [offset].
  Future<Result<List<T>>> fetchPage(int offset, int limit);

  /// Helper that fetches the first page and returns the initial state.
  Future<PaginatedState<T>> buildInitial() async {
    final result = await fetchPage(0, kPaginatedPageSize);
    return result.when(
      success: (items) => PaginatedState(
        items: items,
        hasMore: items.length == kPaginatedPageSize,
      ),
      failure: (f) => throw Exception('${f.runtimeType}: ${f.message}'),
    );
  }

  /// Load the next page and append it to the current items.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final offset = current.items.length;
    final result = await fetchPage(offset, kPaginatedPageSize);

    result.when(
      success: (newItems) {
        state = AsyncData(current.copyWith(
          items: [...current.items, ...newItems],
          isLoadingMore: false,
          hasMore: newItems.length == kPaginatedPageSize,
          page: current.page + 1,
        ));
      },
      failure: (f) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      },
    );
  }

  /// Discard current data and re-fetch from the first page.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(buildInitial);
  }
}
