import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/rental_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/load_more_indicator.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/category_chips.dart';
import '../widgets/rental_item_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.concertId});

  final String? concertId;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String? _selectedCategory;
  String? _searchQuery;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final filter = _currentFilter;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      ref.read(paginatedRentalsFilterProvider(filter).notifier).loadMore();
    }
  }

  RentalFilter get _currentFilter {
    return RentalFilter(
      concertId: widget.concertId,
      category: _selectedCategory,
      searchQuery: _searchQuery,
    );
  }

  void _onSearch(String query) {
    // Strip control chars + cap length before the repository sees it. The
    // repository performs an additional pass to remove PostgREST-significant
    // characters (`%_,():*`); both layers exist as defense in depth.
    final sanitized = Validators.sanitizeSearch(query);
    if (sanitized.isEmpty) {
      setState(() => _searchQuery = null);
      return;
    }
    setState(() {
      _searchQuery = sanitized;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final filter = _currentFilter;
    final itemsAsync = ref.watch(paginatedRentalsFilterProvider(filter));

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearch,
              decoration: InputDecoration(
                hintText: l.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = null);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surfaceLight,
              ),
            ),
          ),
          CategoryChips(
            selected: _selectedCategory,
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: itemsAsync.when(
              data: (paginatedState) {
                final items = paginatedState.items;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      l.noItemsInCategory,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                // Total count: items + optional loading indicator
                final itemCount =
                    items.length + (paginatedState.isLoadingMore ? 1 : 0);
                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index >= items.length) {
                      return const LoadMoreIndicator();
                    }
                    final item = items[index];
                    return RentalItemCard(
                      item: item,
                      onTap: () => context.pushNamed(
                        'itemDetail',
                        pathParameters: {'id': item.id},
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorView(
                message: l.couldNotLoadItems,
                onRetry: () =>
                    ref.invalidate(paginatedRentalsFilterProvider(filter)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
