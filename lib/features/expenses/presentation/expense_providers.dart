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
    if (current == null || !current.hasMore) return;

    final next = await ref.read(expenseApiProvider).dailySummary(page: current.page + 1, limit: _pageSize);
    state = AsyncData(DailySummaryResult(
      days: [...current.days, ...next.days],
      page: next.page,
      limit: next.limit,
      hasMore: next.hasMore,
    ));
  }
}

final homeFeedControllerProvider = AsyncNotifierProvider<HomeFeedController, DailySummaryResult>(HomeFeedController.new);

/// History screen's active filter (category + time period, composed
/// together). Lives in its own provider rather than as field state on
/// ExpenseHistoryController — that controller gets invalidated after every
/// create/update/delete (see ExpenseMutationController below), which
/// recreates the instance and would otherwise silently drop the filter.
final expenseHistoryFilterProvider = simpleValueProvider<ExpenseHistoryFilter>(const ExpenseHistoryFilter());

/// Full expense history: paginated, optionally filtered by category and/or
/// time period. Used by the "View all" drill-down from Home and wherever
/// edit/delete needs the complete list, not just the last two weeks. When a
/// period filter is active, pagination is naturally bounded to it — `from`/
/// `to` scope every query (count, sum, and the page itself), so "load more"
/// simply runs out once that period's data is exhausted.
class ExpenseHistoryController extends AsyncNotifier<ExpenseListResult> {
  @override
  Future<ExpenseListResult> build() {
    final filter = ref.watch(expenseHistoryFilterProvider);
    return ref.read(expenseApiProvider).list(categoryId: filter.categoryId, from: filter.from, to: filter.to, page: 1);
  }

  Future<void> refresh() async {
    final filter = ref.read(expenseHistoryFilterProvider);
    state = await AsyncValue.guard(
      () => ref.read(expenseApiProvider).list(categoryId: filter.categoryId, from: filter.from, to: filter.to, page: 1),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;

    final filter = ref.read(expenseHistoryFilterProvider);
    final next = await ref.read(expenseApiProvider).list(
          categoryId: filter.categoryId,
          from: filter.from,
          to: filter.to,
          page: current.page + 1,
        );
    state = AsyncData(ExpenseListResult(
      items: [...current.items, ...next.items],
      page: next.page,
      limit: next.limit,
      total: next.total,
      totalAmount: next.totalAmount,
    ));
  }
}

final expenseHistoryControllerProvider =
    AsyncNotifierProvider<ExpenseHistoryController, ExpenseListResult>(ExpenseHistoryController.new);

/// Create/update/delete live here rather than on either list controller
/// above, since a mutation needs to invalidate *both* the recent list and
/// the history list (and analytics) — not just whichever screen triggered it.
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
    // Not awaited: the history list isn't visible while a mutation sheet is
    // open, so it just needs to be marked stale for whenever it's next shown.
    ref.invalidate(expenseHistoryControllerProvider);
  }
}

final expenseMutationControllerProvider = NotifierProvider<ExpenseMutationController, void>(ExpenseMutationController.new);
