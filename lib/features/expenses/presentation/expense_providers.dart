import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/value_notifier_provider.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../data/expense_api.dart';
import '../domain/expense_history_filter.dart';

final expenseApiProvider = Provider<ExpenseApi>((ref) => ExpenseApi(ref.watch(apiClientProvider)));

/// Home screen's collapsible day-tile feed — paginated by number of days
/// (not expenses), newest first. Each tile only carries its date/total/count
/// until expanded; DayTile lazily fetches that day's actual items itself via
/// [expenseApiProvider].list with a one-day range, so the payload here stays
/// small even for a user scrolled deep into their history.
class HomeFeedController extends AsyncNotifier<DailySummaryResult> {
  static const _pageSize = 15;

  @override
  Future<DailySummaryResult> build() => ref.read(expenseApiProvider).dailySummary(page: 1, limit: _pageSize);

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(expenseApiProvider).dailySummary(page: 1, limit: _pageSize));
  }

  Future<void> loadMore() async {
    final current = state.value;
    // The `isLoadingMore` check guards against the scroll listener firing
    // loadMore() again before the first call resolves — without it, fast/
    // continuous scrolling could fire several overlapping fetches for the
    // same next page.
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref.read(expenseApiProvider).dailySummary(page: current.page + 1, limit: _pageSize);
      state = AsyncData(DailySummaryResult(
        days: [...current.days, ...next.days],
        page: next.page,
        limit: next.limit,
        hasMore: next.hasMore,
        totalAmount: next.totalAmount,
      ));
    } catch (_) {
      // Clears the loading flag so scrolling again retries instead of being
      // stuck behind a permanently-stalled spinner after a failed fetch.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final homeFeedControllerProvider = AsyncNotifierProvider<HomeFeedController, DailySummaryResult>(HomeFeedController.new);

/// The Search screen's active filter (category + time period, composed
/// together — the search text box itself is separate, plain local state on
/// that screen, not a provider). Lives in its own provider rather than as
/// field state on the screen so it survives that screen being popped and
/// reopened, and so ExpenseHistoryFilterSheet (opened from Search) can read/
/// write it without a reference to the screen itself.
final expenseHistoryFilterProvider = simpleValueProvider<ExpenseHistoryFilter>(const ExpenseHistoryFilter());

/// Whether the Filters sheet has actually been applied at least once —
/// distinct from `expenseHistoryFilterProvider.isActive`, which is false
/// both for "never touched" *and* for an explicit "All categories, All
/// time" choice. Those need to read differently (see ExpenseSearchScreen:
/// the former shows a "search your expenses" prompt, the latter shows every
/// expense, unfiltered) per explicit user feedback that pressing Apply on
/// the untouched defaults did nothing. Lives in a provider rather than
/// local screen state for the same reason expenseHistoryFilterProvider
/// does — it needs to survive the Search screen being popped and reopened,
/// not silently reset to "pristine" every time.
final expenseFiltersEverAppliedProvider = simpleValueProvider<bool>(false);

/// Create/update/delete live here rather than on any list controller, since
/// a mutation needs to refresh *every* place a total could be showing (Home,
/// Analytics) — not just whichever screen triggered it. The Search screen's
/// own results aren't a provider (it fetches locally, since its results view
/// shape depends on whether a text query is active) so it isn't refreshed
/// from here — see ExpenseSearchScreen/DayTile's onExpenseChanged instead.
class ExpenseMutationController extends Notifier<void> {
  @override
  void build() {}

  Future<void> create({required double amount, required String description, required String categoryId, DateTime? date}) async {
    await ref.read(expenseApiProvider).create(amount: amount, description: description, categoryId: categoryId, date: date);
    await _refreshDependents();
  }

  /// Named updateExpense, not update — Riverpod 3's Notifier base class
  /// already defines an `update` method (its optimistic-update helper), and
  /// a method with the same name but a different signature is an invalid
  /// override, not a harmless shadow.
  Future<void> updateExpense(String id, {double? amount, String? description, String? categoryId, DateTime? date}) async {
    await ref.read(expenseApiProvider).update(id, amount: amount, description: description, categoryId: categoryId, date: date);
    await _refreshDependents();
  }

  Future<void> delete(String id) async {
    await ref.read(expenseApiProvider).delete(id);
    await _refreshDependents();
  }

  /// `ref.invalidate()` alone only *marks* a provider dirty — it doesn't wait
  /// for the refetch, so the caller (e.g. the add-expense sheet) would pop
  /// itself and reveal Home before the new data had actually arrived,
  /// making it look like nothing happened until some later, unrelated
  /// rebuild caught up. Awaiting the real refetch here means Home is
  /// guaranteed current by the time the sheet closes.
  Future<void> _refreshDependents() async {
    await Future.wait([
      ref.read(homeFeedControllerProvider.notifier).refresh(),
      ref.refresh(homeSummaryProvider.future),
      ref.refresh(analyticsSummaryProvider.future),
    ]);
  }
}

final expenseMutationControllerProvider = NotifierProvider<ExpenseMutationController, void>(ExpenseMutationController.new);
