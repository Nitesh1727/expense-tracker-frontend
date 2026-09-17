import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/presentation/category_controller.dart';
import 'expense_providers.dart';
import 'widgets/expense_form_sheet.dart';
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

  Future<void> _deleteExpense(String id) async {
    try {
      await ref.read(expenseMutationControllerProvider.notifier).delete(id);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not delete expense';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(expenseHistoryControllerProvider);
    final categoriesAsync = ref.watch(categoryControllerProvider);
    final activeFilter = ref.watch(expenseHistoryFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('All expenses')),
      body: Column(
        children: [
          categoriesAsync.maybeWhen(
            data: (categories) => SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: activeFilter == null,
                      onSelected: (_) => ref.read(expenseHistoryFilterProvider.notifier).set(null),
                    ),
                  ),
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        avatar: CategoryAvatar(icon: category.icon, colorHex: category.color, size: 20),
                        label: Text(category.name),
                        selected: activeFilter == category.id,
                        onSelected: (_) => ref.read(expenseHistoryFilterProvider.notifier).set(category.id),
                      ),
                    ),
                ],
              ),
            ),
            orElse: () => const SizedBox(height: 44),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load expenses: $e')),
              data: (result) {
                if (result.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses found',
                    subtitle: 'Try a different filter.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(expenseHistoryControllerProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    itemCount: result.items.length + (result.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= result.items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final expense = result.items[index];
                      return Dismissible(
                        key: ValueKey(expense.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                        ),
                        onDismissed: (_) => _deleteExpense(expense.id),
                        child: ExpenseTile(
                          expense: expense,
                          onTap: () => showExpenseFormSheet(context, existing: expense),
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
