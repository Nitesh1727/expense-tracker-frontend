import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/swipeable_amount_tile.dart';
import '../../analytics/presentation/analytics_providers.dart';
import 'expense_providers.dart';
import 'expense_search_screen.dart';
import 'widgets/day_tile.dart';

const _homePeriodLabels = {'day': 'Today', 'week': 'This week', 'month': 'This month'};

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
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        ref.read(homeFeedControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedControllerProvider);
    final summaryAsync = ref.watch(homeSummaryProvider);
    final period = ref.watch(homeSummaryPeriodProvider);
    final textTheme = Theme.of(context).textTheme;

    // No own Scaffold/AppBar/FAB — this is one page of RootShell's PageView,
    // which owns the shared AppBar and FAB (action swaps per page).
    return RefreshIndicator(
      onRefresh: () async {
        // Awaited, not just invalidated — the pull-to-refresh spinner should
        // stay visible until the new data has actually arrived, not
        // disappear the instant the request is fired.
        await Future.wait([
          ref.read(homeFeedControllerProvider.notifier).refresh(),
          ref.refresh(homeSummaryProvider.future),
        ]);
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
        children: [
          SwipeableAmountTile<String>(
            options: [for (final entry in _homePeriodLabels.entries) (entry.key, entry.value)],
            selected: period,
            onChanged: (value) => ref.read(homeSummaryPeriodProvider.notifier).set(value),
            amountFor: (periodKey) => summaryAsync.when(
              loading: () => '···',
              error: (_, _) => '—',
              data: (summaries) => Formatters.currency(summaries[periodKey]?.total ?? 0),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent', style: textTheme.titleLarge),
              // Search and Filter used to be two separate entry points doing
              // almost the same thing — merged into one (Search now has its
              // own Filters button for category/period, see
              // ExpenseSearchScreen) per explicit user feedback.
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExpenseSearchScreen()),
                ),
              ),
            ],
          ),
          feedAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Could not load expenses: $e'),
            ),
            data: (feed) {
              if (feed.days.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses yet',
                    subtitle: 'Tap + to log your first one.',
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < feed.days.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: DayTile(key: ValueKey(feed.days[i].date.toIso8601String()), summary: feed.days[i])
                          .animate()
                          .fadeIn(duration: 200.ms, delay: (i * 20).ms)
                          .slideY(begin: 0.02, end: 0),
                    ),
                  // Tied to isLoadingMore (a fetch actually in flight), not
                  // hasMore (which stays true the whole time more pages
                  // exist) — this is what fixes scrolling into blank space
                  // before the next page arrives; the spinner now shows the
                  // moment a fetch starts, since it starts well before the
                  // user reaches the true bottom (see the scroll listener's
                  // 300px threshold above).
                  if (feed.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
