import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_controller.dart';
import '../data/expense_api.dart';
import '../domain/expense.dart';
import '../domain/expense_history_filter.dart';
import 'expense_providers.dart';
import 'widgets/day_tile.dart';
import 'widgets/expense_form_sheet.dart';
import 'widgets/expense_history_filter_sheet.dart';
import 'widgets/expense_tile.dart';

/// Search by description/amount, and/or a category/period Filters sheet —
/// this used to be two separate entry points from Home (Search and Filter)
/// doing almost the same thing; merged into one per explicit user feedback.
/// The Filters sheet (category multi-select + time period, including
/// custom range) is the exact same [showExpenseHistoryFilterSheet] widget,
/// reused as-is rather than duplicated — its state lives in
/// [expenseHistoryFilterProvider] so it round-trips correctly regardless of
/// which screen opens the sheet.
///
/// Two distinct results views — see [_wantsFlatList]:
/// - **Time period only, or no filter at all**: the same grouped day-tiles
///   Home uses (literally reuses [DayTile], passing the active category
///   filter — empty in this branch — through to its own per-day fetch too)
///   — "show me what I spent these dates" reads naturally as the familiar
///   day-grouped view, not a flat list.
/// - **A category filter and/or a text query is active**: a flat list of
///   matching expenses directly instead — "all Food expenses" or "all Pizza
///   this month" is about reading the specific matches, not browsing by day.
///   Per explicit user feedback: day-tiles should only appear for a pure
///   time-period browse, not once something more specific is being asked for.
///
/// Deliberately not paginated with "load more" like a full history list
/// would be — search results are typically a narrower slice already; this
/// fetches one generous page (the max the backend allows) rather than
/// adding a second parallel infinite-scroll mode on top of an already
/// dual-mode screen.
class ExpenseSearchScreen extends ConsumerStatefulWidget {
  const ExpenseSearchScreen({super.key});

  @override
  ConsumerState<ExpenseSearchScreen> createState() => _ExpenseSearchScreenState();
}

class _ExpenseSearchScreenState extends ConsumerState<ExpenseSearchScreen> {
  final _queryController = TextEditingController();
  final _queryFocusNode = FocusNode();
  Timer? _debounce;

  String _query = '';
  bool _loading = false;
  String? _error;
  DailySummaryResult? _dailyResult;
  ExpenseListResult? _listResult;

  bool get _hasQuery => _query.trim().isNotEmpty;

  /// Grouped day-tiles only make sense for "browse by date" — the moment a
  /// category filter (or a text query) narrows things down to something
  /// specific, a flat list of the actual matches is more useful than a
  /// day-by-day total. So: day-tiles when only a time period (or nothing)
  /// is filtering; a flat list the moment a category and/or text query is
  /// also in play. Per explicit user feedback.
  bool _wantsFlatList(ExpenseHistoryFilter filter) => _hasQuery || filter.categoryIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusOnceSheetSettles());
  }

  // Same reasoning as the add-expense sheet's amount field — requesting the
  // keyboard the instant this screen builds races its own push transition.
  void _focusOnceSheetSettles() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _queryFocusNode.requestFocus();
      return;
    }
    void listener(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(listener);
      if (mounted) _queryFocusNode.requestFocus();
    }

    animation.addStatusListener(listener);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _query = value);
      _runSearch();
    });
  }

  Future<void> _runSearch() async {
    final filter = ref.read(expenseHistoryFilterProvider);
    if (!_hasQuery && !filter.isActive) {
      setState(() {
        _dailyResult = null;
        _listResult = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_wantsFlatList(filter)) {
        final result = await ref.read(expenseApiProvider).list(
              q: _hasQuery ? _query.trim() : null,
              categoryIds: filter.categoryIds.toList(),
              from: filter.from,
              to: filter.to,
              limit: 100,
            );
        if (!mounted) return;
        setState(() {
          _listResult = result;
          _dailyResult = null;
          _loading = false;
        });
      } else {
        final result = await ref.read(expenseApiProvider).dailySummary(
              categoryIds: filter.categoryIds.toList(),
              from: filter.from,
              to: filter.to,
              limit: 60,
            );
        if (!mounted) return;
        setState(() {
          _dailyResult = result;
          _listResult = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not search';
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  Future<void> _openFilters() async {
    await showExpenseHistoryFilterSheet(context);
    // Whether Apply, Clear, or a back-gesture closed it — re-running is a
    // harmless no-op if nothing actually changed.
    _runSearch();
  }

  Future<void> _editExpense(Expense expense) async {
    await showExpenseFormSheet(context, existing: expense);
    _runSearch();
  }

  Future<void> _deleteExpense(String id) async {
    try {
      await ref.read(expenseMutationControllerProvider.notifier).delete(id);
      await _runSearch();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not delete expense';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final filter = ref.watch(expenseHistoryFilterProvider);
    final categories = ref.watch(categoryControllerProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    focusNode: _queryFocusNode,
                    onChanged: _onQueryChanged,
                    decoration: const InputDecoration(
                      hintText: 'Description / amount',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: Badge(isLabelVisible: filter.isActive, smallSize: 8, child: const Icon(Icons.tune)),
                  tooltip: 'Filters',
                  onPressed: _openFilters,
                ),
              ],
            ),
          ),
          if (filter.isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: _openFilters,
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
                        Icon(Icons.filter_alt, size: 14, color: colorScheme.primary),
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
                          onTap: () {
                            ref.read(expenseHistoryFilterProvider.notifier).set(const ExpenseHistoryFilter());
                            _runSearch();
                          },
                          child: Icon(Icons.close, size: 14, color: colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildResults(context, filter)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, ExpenseHistoryFilter filter) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (!_hasQuery && !filter.isActive) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Search your expenses',
        subtitle: 'Type a description or amount, or use Filters to browse by category/date.',
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Could not search: $_error'));

    // Time-period-only (or no) filter: same grouped day-tile view as Home.
    // A category filter or text query switches to the flat list below —
    // see _wantsFlatList.
    if (!_wantsFlatList(filter)) {
      final days = _dailyResult?.days ?? const [];
      if (days.isEmpty) {
        return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Nothing logged for this filter');
      }
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        children: [
          for (final day in days)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: DayTile(
                key: ValueKey(day.date.toIso8601String()),
                summary: day,
                categoryIds: filter.categoryIds,
                onExpenseChanged: _runSearch,
              ),
            ),
        ],
      );
    }

    // Category filter and/or text query: a flat list of matches, not
    // grouped by day.
    final items = _listResult?.items ?? const [];
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.search_off, title: 'No matching expenses', subtitle: 'Try a different search or filter.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      itemCount: items.length + 1, // +1 for the total footer
      itemBuilder: (context, index) {
        if (index < items.length) {
          final expense = items[index];
          return Dismissible(
            key: ValueKey(expense.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Icon(Icons.delete_outline, color: colorScheme.error),
            ),
            onDismissed: (_) => _deleteExpense(expense.id),
            child: ExpenseTile(expense: expense, onTap: () => _editExpense(expense)),
          );
        }

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
                    Formatters.currency(_listResult!.totalAmount),
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}
