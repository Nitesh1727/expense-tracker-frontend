import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_controller.dart';
import '../domain/expense_history_filter.dart';
import 'expense_providers.dart';
import 'widgets/expense_form_sheet.dart';
import 'widgets/expense_history_filter_sheet.dart';
import 'widgets/expense_tile.dart';

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  ConsumerState<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
        ref.read(expenseHistoryControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// A single name if one category is picked, a joined list for two, or a
  /// count for three or more — keeps the filter-summary chip from growing
  /// unboundedly long once several categories are selected.
  String? _categoryNamesLabel(Set<String> categoryIds, List<Category> categories) {
    if (categoryIds.isEmpty) return null;
    final names = categories.where((c) => categoryIds.contains(c.id)).map((c) => c.name).toList();
    if (names.isEmpty) return null;
    if (names.length <= 2) return names.join(', ');
    return '${names.length} categories';
  }

  String _filterSummary(ExpenseHistoryFilter filter, List<Category> categories) {
    final parts = <String>[];
    if (filter.period == HistoryPeriodPreset.custom && filter.from != null && filter.to != null) {
      parts.add('${Formatters.dayMonth(filter.from!)} – ${Formatters.dayMonth(filter.to!.subtract(const Duration(days: 1)))}');
    } else if (filter.period != HistoryPeriodPreset.all) {
      parts.add(filter.period.label);
    }
    final categoryLabel = _categoryNamesLabel(filter.categoryIds, categories);
    if (categoryLabel != null) parts.add(categoryLabel);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(expenseHistoryControllerProvider);
    final categories = ref.watch(categoryControllerProvider).value ?? const [];
    final filter = ref.watch(expenseHistoryFilterProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle('All expenses'),
        actions: [
          IconButton(
            icon: Badge(isLabelVisible: filter.isActive, smallSize: 8, child: const Icon(Icons.tune)),
            tooltip: 'Filters',
            onPressed: () => showExpenseHistoryFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (filter.isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: InkWell(
                onTap: () => showExpenseHistoryFilterSheet(context),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_alt, size: 16, color: colorScheme.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          _filterSummary(filter, categories),
                          style: textTheme.labelLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      InkWell(
                        onTap: () => ref.read(expenseHistoryFilterProvider.notifier).set(const ExpenseHistoryFilter()),
                        child: Icon(Icons.close, size: 16, color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load expenses: $e')),
              data: (result) {
                if (result.items.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses found',
                    subtitle: filter.isActive ? 'Try a different filter.' : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(expenseHistoryControllerProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    // +1 for the loading spinner (while more of this filter's
                    // pages are still loading) and +1 for the total footer,
                    // which always renders last regardless of hasMore — the
                    // total is already known in full from `totalAmount`, it
                    // doesn't need every page loaded first.
                    itemCount: result.items.length + (result.hasMore ? 1 : 0) + 1,
                    itemBuilder: (context, index) {
                      if (index < result.items.length) {
                        final expense = result.items[index];
                        // No swipe-to-delete here — tapping opens the edit
                        // sheet, which has its own delete action, so the
                        // swipe gesture was a redundant second way to do the
                        // same thing (per explicit user feedback).
                        return ExpenseTile(
                          key: ValueKey(expense.id),
                          expense: expense,
                          onTap: () => showExpenseFormSheet(context, existing: expense),
                        );
                      }

                      if (result.hasMore && index == result.items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      // The total footer — a line, then the sum, like the
                      // bottom of a receipt.
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Divider(color: colorScheme.outline),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: textTheme.titleMedium),
                                Text(
                                  Formatters.currency(result.totalAmount),
                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
