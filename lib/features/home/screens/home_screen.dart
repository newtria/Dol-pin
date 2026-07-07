import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/concert_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/load_more_indicator.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/concert_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      ref.read(paginatedUpcomingConcertsProvider(null).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final concertsAsync = ref.watch(paginatedUpcomingConcertsProvider(null));

    return SafeArea(
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              l.appTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l.comingSoon)));
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                l.upcomingConcerts,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          concertsAsync.when(
            data: (paginatedState) {
              final concerts = paginatedState.items;
              if (concerts.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        l.noUpcomingConcerts,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= concerts.length) {
                      return const LoadMoreIndicator();
                    }
                    final concert = concerts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ConcertCard(
                        concert: concert,
                        onTap: () => context.pushNamed(
                          'explore',
                          queryParameters: {'concertId': concert.id},
                        ),
                      ),
                    );
                  },
                  childCount:
                      concerts.length + (paginatedState.isLoadingMore ? 1 : 0),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: LoadingIndicator()),
            error: (e, _) => SliverToBoxAdapter(
              child: ErrorView(
                message: l.couldNotLoadConcerts,
                onRetry: () =>
                    ref.invalidate(paginatedUpcomingConcertsProvider(null)),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
