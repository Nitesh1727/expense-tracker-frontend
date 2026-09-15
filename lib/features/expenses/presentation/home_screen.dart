import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../domain/expense.dart';
import 'expense_history_screen.dart';
import 'expense_providers.dart';
import 'widgets/expense_form_sheet.dart';
import 'widgets/expense_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Buckets the (already most-recent-first) list into Today / Yesterday /
  /// Earlier this week sections, preserving order within each — see
  /// frontend/docs/DESIGN_SYSTEM.md navigation notes.
  Map<String, List<Expense>> _grouped(List<Expense> expenses) {
    final groups = <String, List<Expense>>{};
    for (final expense in expenses) {
      final label = Formatters.relativeDayLabel(expense.date);
      groups.putIfAbsent(label, () => []).add(expense);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentExpensesProvider);
    final todaySummaryAsync = ref.watch(todaySummaryProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showExpenseFormSheet(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentExpensesProvider);
          ref.invalidate(todaySummaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
          children: [
            Text("Today's spending", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xs),
            todaySummaryAsync.when(
              loading: () => const SizedBox(height: 40),
              error: (_, _) => Text('—', style: textTheme.displayLarge),
              data: (summary) => Text(Formatters.currency(summary.total), style: textTheme.displayLarge)
                  .animate()
                  .fadeIn()
                  .slideY(begin: 0.1, end: 0),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent', style: textTheme.titleLarge),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen()),
                  ),
                  child: const Text('View all'),
                ),
              ],
            ),
            recentAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Could not load expenses: $e'),
              ),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses yet',
                      subtitle: 'Tap + to log your first one.',
                    ),
                  );
                }

                final groups = _grouped(expenses);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
                        child: Text(
                          entry.key,
                          style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      for (final expense in entry.value)
                        ExpenseTile(
                          expense: expense,
                          onTap: () => showExpenseFormSheet(context, existing: expense),
                        ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.03, end: 0),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
