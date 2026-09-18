import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/daily_summary.dart';
import '../../domain/expense.dart';
import '../expense_providers.dart';
import 'expense_form_sheet.dart';
import 'expense_tile.dart';

/// Collapsed by default, showing just the day's total — tapping expands it
/// to lazily fetch and show that day's actual expenses. Per
/// frontend/docs/DESIGN_SYSTEM.md: closed-by-default keeps Home scannable
/// even once someone has scrolled back through months of history.
class DayTile extends ConsumerStatefulWidget {
  final DailySummary summary;

  const DayTile({super.key, required this.summary});

  @override
  ConsumerState<DayTile> createState() => _DayTileState();
}

class _DayTileState extends ConsumerState<DayTile> {
  bool _expanded = false;
  List<Expense>? _items;
  bool _loading = false;
  String? _error;

  String get _headerLabel {
    final relative = Formatters.relativeDayLabel(widget.summary.date);
    final dateStr = Formatters.dayMonth(widget.summary.date);
    // relativeDayLabel already falls back to the date string itself once an
    // entry is old enough that "Today"/"Yesterday"/a weekday no longer
    // applies — showing both would just repeat "14 Sep · 14 Sep".
    return relative == dateStr ? dateStr : '$relative · $dateStr';
  }

  Future<void> _toggle() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && _items == null && !_loading) {
      await _fetchItems();
    }
  }

  Future<void> _fetchItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = widget.summary.date;
      final to = from.add(const Duration(days: 1));
      final result = await ref.read(expenseApiProvider).list(from: from, to: to, limit: 100);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load — pull to refresh and try again';
        _loading = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant DayTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This widget is keyed by date (see home_screen.dart), so the same
    // State instance survives across a HomeFeedController refresh — the
    // day's count/total in `widget.summary` update correctly on every
    // rebuild, but the *expanded item list* was fetched once and cached
    // forever, so adding/editing/deleting an expense on an already-expanded
    // day updated the outer total but silently left the stale item list
    // showing underneath it. A changed count or total means this day's
    // expenses changed elsewhere, so the cache is stale — clear it, and if
    // currently expanded, refetch immediately rather than waiting for the
    // user to collapse/reopen the tile.
    final changed = oldWidget.summary.count != widget.summary.count || oldWidget.summary.total != widget.summary.total;
    if (changed) {
      _items = null;
      if (_expanded) _fetchItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_headerLabel, style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          widget.summary.count == 1 ? '1 expense' : '${widget.summary.count} expenses',
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.currency(widget.summary.total),
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppMotion.standard,
                    curve: AppMotion.standardCurve,
                    child: Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.standard,
            curve: AppMotion.standardCurve,
            child: _expanded ? _buildBody(context) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }

    final items = _items ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
      child: Column(
        children: [
          const Divider(height: 1),
          for (final expense in items)
            ExpenseTile(
              expense: expense,
              showDate: false,
              onTap: () => showExpenseFormSheet(context, existing: expense),
            ),
        ],
      ),
    );
  }
}
