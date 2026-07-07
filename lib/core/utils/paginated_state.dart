/// Generic state holder for paginated data.
class PaginatedState<T> {
  final List<T> items;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;

  const PaginatedState({
    this.items = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 0,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
  }) => PaginatedState(
    items: items ?? this.items,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    page: page ?? this.page,
  );
}
