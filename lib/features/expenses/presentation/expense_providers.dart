import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/value_notifier_provider.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../data/expense_api.dart';
import '../domain/expense.dart';

final expenseApiProvider = Provider<ExpenseApi>((ref) => ExpenseApi(ref.watch(apiClientProvider)));

/// Home screen's "recent" list — last 14 days, most recent first, grouped
/// client-side into Today/Yesterday/Earlier by the UI. Kept separate from
/// the paginated history list below since it has no filters/pagination of
/// its own.
final recentExpensesProvider = FutureProvider.autoDispose<List<Expense>>((ref) async {
  final api = ref.watch(expenseApiProvider);
  final from = DateTime.now().subtract(const Duration(days: 14));
  final result = await api.list(from: from, limit: 50);
  return result.items;
});

/// History screen's active category filter (null = all categories). Lives
/// in its own provider rather than as field state on
/// ExpenseHistoryController — that controller gets invalidated after every
/// create/update/delete (see ExpenseMutationController below), which
/// recreates the instance and would otherwise silently drop the filter.
final expenseHistoryFilterProvider = simpleValueProvider<String?>(null);

/// Full expense history: paginated, optionally filtered by category. Used
/// by the "View all" drill-down from Home and wherever edit/delete needs
/// the complete list, not just the last two weeks.
class ExpenseHistoryController extends AsyncNotifier<ExpenseListResult> {
  @override
  Future<ExpenseListResult> build() {
    final categoryId = ref.watch(expenseHistoryFilterProvider);
    return ref.read(expenseApiProvider).list(categoryId: categoryId, page: 1);
  }

  Future<void> refresh() async {
    final categoryId = ref.read(expenseHistoryFilterProvider);
    state = await AsyncValue.guard(() => ref.read(expenseApiProvider).list(categoryId: categoryId, page: 1));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;

    final categoryId = ref.read(expenseHistoryFilterProvider);
    final next = await ref.read(expenseApiProvider).list(categoryId: categoryId, page: current.page + 1);
    state = AsyncData(ExpenseListResult(
      items: [...current.items, ...next.items],
      page: next.page,
      limit: next.limit,
      total: next.total,
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
    _invalidateDependents();
  }

  /// Named updateExpense, not update — Riverpod 3's Notifier base class
  /// already defines an `update` method (its optimistic-update helper), and
  /// a method with the same name but a different signature is an invalid
  /// override, not a harmless shadow.
  Future<void> updateExpense(String id, {double? amount, String? description, String? categoryId, DateTime? date}) async {
    await ref.read(expenseApiProvider).update(id, amount: amount, description: description, categoryId: categoryId, date: date);
    _invalidateDependents();
  }

  Future<void> delete(String id) async {
    await ref.read(expenseApiProvider).delete(id);
    _invalidateDependents();
  }

  void _invalidateDependents() {
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(expenseHistoryControllerProvider);
    ref.invalidate(analyticsSummaryProvider);
    ref.invalidate(analyticsTrendProvider);
    ref.invalidate(todaySummaryProvider);
  }
}

final expenseMutationControllerProvider = NotifierProvider<ExpenseMutationController, void>(ExpenseMutationController.new);
