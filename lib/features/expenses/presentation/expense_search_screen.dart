import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/expense_api.dart';
import '../domain/expense_history_filter.dart';
import 'expense_providers.dart';
import 'widgets/day_tile.dart';
import 'widgets/expense_form_sheet.dart';
import 'widgets/expense_tile.dart';

/// Search by description/amount, and/or a date filter — a different entry
/// point from the History screen's category+period Filters sheet
/// (deliberately separate, per explicit request), though it reuses the same
/// [HistoryPeriodPreset] date-range logic for consistency.
///
/// Two distinct results views, chosen by whether there's a text query:
/// - **Date only** (no text typed): the same grouped day-tiles Home uses
///   (literally reuses [DayTile]), scoped to the picked range — "show me
///   what I spent these dates" reads naturally as the familiar day-grouped
///   view, not a flat list.
/// - **Text query present** (with or without a date filter): a flat list of
///   matching expenses directly — "all Pizza expenses" or "everything ₹500"
///   doesn't group by day the way browsing history does, the point is to
///   read the matches directly.
///
/// Deliberately not paginated with "load more" like the History screen —
/// search results are typically a narrow slice already; this fetches one
/// generous page (the max the backend allows) rather than adding a second
/// parallel infinite-scroll mode on top of an already-dual-mode screen.
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
  HistoryPeriodPreset _period = HistoryPeriodPreset.all;
  DateTime? _from;
  DateTime? _to;

  bool _loading = false;
  String? _error;
  DailySummaryResult? _dailyResult;
  ExpenseListResult? _listResult;

  bool get _hasQuery => _query.trim().isNotEmpty;
  bool get _hasDateFilter => _period != HistoryPeriodPreset.all;
  bool get _hasAnyFilter => _hasQuery || _hasDateFilter;

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
    if (!_hasAnyFilter) {
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
      if (_hasQuery) {
        final result = await ref.read(expenseApiProvider).list(
              q: _query.trim(),
              from: _from,
              to: _to,
              limit: 100,
            );
        if (!mounted) return;
        setState(() {
          _listResult = result;
          _dailyResult = null;
          _loading = false;
        });
      } else {
        final result = await ref.read(expenseApiProvider).dailySummary(from: _from, to: _to, limit: 60);
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

  Future<void> _pickPeriod() async {
    final picked = await showModalBottomSheet<(HistoryPeriodPreset, DateTime?, DateTime?)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PeriodPickerSheet(current: _period, currentFrom: _from, currentTo: _to),
    );
    if (picked == null) return;
    setState(() {
      _period = picked.$1;
      _from = picked.$2;
      _to = picked.$3;
    });
    _runSearch();
  }

  void _clearDateFilter() {
    setState(() {
      _period = HistoryPeriodPreset.all;
      _from = null;
      _to = null;
    });
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

  String _dateFilterLabel() {
    if (_period == HistoryPeriodPreset.custom && _from != null && _to != null) {
      return '${Formatters.dayMonth(_from!)} – ${Formatters.dayMonth(_to!.subtract(const Duration(days: 1)))}';
    }
    return _period.label;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

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
                      hintText: 'Search by description or amount',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: Badge(isLabelVisible: _hasDateFilter, smallSize: 8, child: const Icon(Icons.calendar_today_outlined)),
                  tooltip: 'Pick a date range',
                  onPressed: _pickPeriod,
                ),
              ],
            ),
          ),
          if (_hasDateFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: _pickPeriod,
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
                        Icon(Icons.calendar_today, size: 14, color: colorScheme.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _dateFilterLabel(),
                          style: textTheme.labelLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        InkWell(onTap: _clearDateFilter, child: Icon(Icons.close, size: 14, color: colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (!_hasAnyFilter) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Search your expenses',
        subtitle: 'Type a description or amount, or pick a date range.',
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Could not search: $_error'));

    // Date-only: same grouped day-tile view as Home.
    if (!_hasQuery) {
      final days = _dailyResult?.days ?? const [];
      if (days.isEmpty) {
        return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Nothing logged for this period');
      }
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        children: [
          for (final day in days)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: DayTile(key: ValueKey(day.date.toIso8601String()), summary: day),
            ),
        ],
      );
    }

    // Text query: a flat list of matches, not grouped by day.
    final items = _listResult?.items ?? const [];
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.search_off, title: 'No matching expenses', subtitle: 'Try a different search or date range.');
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
            child: ExpenseTile(expense: expense, onTap: () => showExpenseFormSheet(context, existing: expense)),
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

/// Date-only period picker — the same [HistoryPeriodPreset] chips as the
/// History screen's Filters sheet, minus the category section (this screen
/// has its own separate text-search field for that kind of narrowing).
class _PeriodPickerSheet extends StatefulWidget {
  final HistoryPeriodPreset current;
  final DateTime? currentFrom;
  final DateTime? currentTo;

  const _PeriodPickerSheet({required this.current, required this.currentFrom, required this.currentTo});

  @override
  State<_PeriodPickerSheet> createState() => _PeriodPickerSheetState();
}

class _PeriodPickerSheetState extends State<_PeriodPickerSheet> {
  late HistoryPeriodPreset _period = widget.current;
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    if (widget.current == HistoryPeriodPreset.custom) {
      _customFrom = widget.currentFrom;
      _customTo = widget.currentTo;
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = (_customFrom != null && _customTo != null)
        ? DateTimeRange(start: _customFrom!, end: _customTo!.subtract(const Duration(days: 1)))
        : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: initial,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _period = HistoryPeriodPreset.custom;
      _customFrom = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _customTo = DateTime(picked.end.year, picked.end.month, picked.end.day).add(const Duration(days: 1));
    });
  }

  void _apply() {
    final (from, to) = switch (_period) {
      HistoryPeriodPreset.custom => (_customFrom, _customTo),
      HistoryPeriodPreset.all => (null, null),
      _ => ExpenseHistoryFilter.rangeFor(_period) ?? (null, null),
    };
    Navigator.of(context).pop((_period, from, to));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date range', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final preset in HistoryPeriodPreset.values)
                    ChoiceChip(
                      label: Text(preset.label),
                      selected: _period == preset,
                      onSelected: (_) {
                        if (preset == HistoryPeriodPreset.custom) {
                          _pickCustomRange();
                        } else {
                          setState(() => _period = preset);
                        }
                      },
                    ),
                ],
              ),
              if (_period == HistoryPeriodPreset.custom && _customFrom != null && _customTo != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    '${Formatters.dayMonthYear(_customFrom!)} – '
                    '${Formatters.dayMonthYear(_customTo!.subtract(const Duration(days: 1)))}',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop((HistoryPeriodPreset.all, null, null)),
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
