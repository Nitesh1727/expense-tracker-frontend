import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/expense_api.dart';
import '../domain/expense.dart';
import '../domain/expense_history_filter.dart';
import 'expense_providers.dart';
import 'widgets/day_tile.dart';
import 'widgets/expense_form_sheet.dart';
import 'widgets/expense_tile.dart';
import 'widgets/search_filter_chips.dart';

/// Search by description/amount, and/or category and time-period filters shown
/// directly under the search box as chips ([SearchFilterChips]) that apply the
/// instant they're tapped. Every chip can be switched off again, down to
/// nothing selected at all; the filter itself lives in
/// [expenseHistoryFilterProvider] so it survives the screen being popped and
/// reopened. With no text and nothing selected there is nothing to search
/// for, so the screen shows a prompt rather than silently listing everything.
///
/// Two distinct results views — see [_wantsFlatList]:
/// - **Time period only, or no filter at all**: the same grouped day-tiles
///   Home uses (literally reuses [DayTile], passing the active category
///   filter — empty in this branch — through to its own per-day fetch too)
///   — "show me what I spent these dates" reads naturally as the familiar
///   day-grouped view, not a flat list. Also shows a "Total" footer, same
///   as the flat list — the grand total across every matching day, not
///   just the ones loaded so far (see DailySummaryResult.totalAmount).
/// - **A category filter and/or a text query is active**: a flat list of
///   matching expenses directly instead — "all Food expenses" or "all Pizza
///   this month" is about reading the specific matches, not browsing by day.
///   Per explicit user feedback: day-tiles should only appear for a pure
///   time-period browse, not once something more specific is being asked for.
///
/// Both views are paginated with "load more" on scroll (same pattern as
/// Home's day-tile feed) — per explicit user feedback that a single
/// unbounded fetch wouldn't scale once someone has a lot of history. The
/// bottom loading row is driven by `isLoadingMore` (a fetch actually in
/// flight), not just "more could be fetched" — see
/// DailySummaryResult/ExpenseListResult.isLoadingMore for why that
/// distinction is what avoids a scroll-into-blank-space jank.
class ExpenseSearchScreen extends ConsumerStatefulWidget {
  const ExpenseSearchScreen({super.key});

  @override
  ConsumerState<ExpenseSearchScreen> createState() => _ExpenseSearchScreenState();
}

class _ExpenseSearchScreenState extends ConsumerState<ExpenseSearchScreen> {
  static const _listPageSize = 20;
  static const _dailyPageSize = 15;

  final _queryController = TextEditingController();
  final _queryFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _debounce;

  String _query = '';
  // Chips apply instantly, so searches can overlap; only the latest may land.
  int _searchSeq = 0;
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
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
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
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _query = value);
      _runSearch();
    });
  }

  /// Always fetches page 1, discarding whatever extra pages loadMore() had
  /// appended — the right behavior any time the query, filter, or an
  /// edit/delete means the previous results are stale, since restarting
  /// pagination from the top is the only way to guarantee correctness.
  Future<void> _runSearch() async {
    final filter = ref.read(expenseHistoryFilterProvider);
    final seq = ++_searchSeq;
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
              limit: _listPageSize,
            );
        if (!mounted || seq != _searchSeq) return;
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
              limit: _dailyPageSize,
            );
        if (!mounted || seq != _searchSeq) return;
        setState(() {
          _dailyResult = result;
          _listResult = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      final message = e is ApiException ? e.message : 'Could not search';
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  /// Fetches the next page and appends it, for whichever results view is
  /// currently showing. Guarded by `isLoadingMore` so fast/continuous
  /// scrolling can't fire several overlapping fetches for the same page.
  Future<void> _loadMore() async {
    final filter = ref.read(expenseHistoryFilterProvider);

    if (_wantsFlatList(filter)) {
      final current = _listResult;
      if (current == null || !current.hasMore || current.isLoadingMore) return;

      setState(() => _listResult = current.copyWith(isLoadingMore: true));
      try {
        final next = await ref.read(expenseApiProvider).list(
              q: _hasQuery ? _query.trim() : null,
              categoryIds: filter.categoryIds.toList(),
              from: filter.from,
              to: filter.to,
              page: current.page + 1,
              limit: _listPageSize,
            );
        if (!mounted) return;
        setState(() {
          _listResult = ExpenseListResult(
            items: [...current.items, ...next.items],
            page: next.page,
            limit: next.limit,
            total: next.total,
            totalAmount: next.totalAmount,
          );
        });
      } catch (_) {
        if (!mounted) return;
        // Clears the loading flag so scrolling again retries, instead of
        // being stuck behind a permanently-stalled spinner after a failed
        // fetch.
        setState(() => _listResult = current.copyWith(isLoadingMore: false));
      }
    } else {
      final current = _dailyResult;
      if (current == null || !current.hasMore || current.isLoadingMore) return;

      setState(() => _dailyResult = current.copyWith(isLoadingMore: true));
      try {
        final next = await ref.read(expenseApiProvider).dailySummary(
              categoryIds: filter.categoryIds.toList(),
              from: filter.from,
              to: filter.to,
              page: current.page + 1,
              limit: _dailyPageSize,
            );
        if (!mounted) return;
        setState(() {
          _dailyResult = DailySummaryResult(
            days: [...current.days, ...next.days],
            page: next.page,
            limit: next.limit,
            hasMore: next.hasMore,
            totalAmount: next.totalAmount,
          );
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _dailyResult = current.copyWith(isLoadingMore: false));
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(expenseHistoryFilterProvider);

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
                    // Matches the backend's own cap on `q` (expense.validator.js)
                    // — counterText suppressed since a visible "0/120" reads
                    // oddly on a search box, not a form field.
                    maxLength: 120,
                    decoration: const InputDecoration(
                      hintText: 'Description / amount',
                      prefixIcon: Icon(Icons.search),
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SearchFilterChips(onChanged: _runSearch),
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
        subtitle: 'Type a description or amount, or pick a category or time period.',
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Could not search: $_error'));

    Widget totalFooter(double totalAmount) => Padding(
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
                  Text(Formatters.currency(totalAmount), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );

    const loadingMoreRow = Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
    );

    // Time-period-only (or no) filter: same grouped day-tile view as Home,
    // plus a "Total" footer (the flat list below already had one).
    if (!_wantsFlatList(filter)) {
      final result = _dailyResult;
      final days = result?.days ?? const [];
      if (days.isEmpty) {
        return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Nothing logged for this filter');
      }
      final isLoadingMore = result?.isLoadingMore ?? false;
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        // +1 for the loading row (only while a next page is actually being
        // fetched) and +1 for the total footer, which always renders last —
        // the total is already known in full from `totalAmount`, it doesn't
        // need every page loaded first.
        itemCount: days.length + (isLoadingMore ? 1 : 0) + 1,
        itemBuilder: (context, index) {
          if (index < days.length) {
            final day = days[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: DayTile(
                key: ValueKey(day.date.toIso8601String()),
                summary: day,
                categoryIds: filter.categoryIds,
                onExpenseChanged: _runSearch,
              ),
            );
          }
          if (isLoadingMore && index == days.length) return loadingMoreRow;
          return totalFooter(result!.totalAmount);
        },
      );
    }

    // Category filter and/or text query: a flat list of matches, not
    // grouped by day.
    final result = _listResult;
    final items = result?.items ?? const [];
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.search_off, title: 'No matching expenses', subtitle: 'Try a different search or filter.');
    }
    final isLoadingMore = result?.isLoadingMore ?? false;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      itemCount: items.length + (isLoadingMore ? 1 : 0) + 1,
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
        if (isLoadingMore && index == items.length) return loadingMoreRow;
        return totalFooter(result!.totalAmount);
      },
    );
  }
}
