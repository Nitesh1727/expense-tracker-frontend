import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/friendly_date_range_picker.dart';
import '../../../core/widgets/amount_tile.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../export/presentation/export_controller.dart';
import '../domain/analytics_summary.dart';
import 'analytics_providers.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _exporting = false;

  /// Computes the previous/next period's anchor from the *current* fetch's
  /// authoritative `range.start` rather than doing calendar math on
  /// `DateTime.now()` — avoids reimplementing "what's the 1st of next
  /// month" edge cases (month length, leap years) since the backend already
  /// solved that once for the range it returned.
  DateTime _adjacentAnchor(String period, DateTime start, {required bool forward}) {
    final sign = forward ? 1 : -1;
    switch (period) {
      case 'day':
        return start.add(Duration(days: sign));
      case 'week':
        return start.add(Duration(days: 7 * sign));
      case 'month':
        return DateTime(start.year, start.month + sign, 1);
      case 'year':
      default:
        return DateTime(start.year + sign, 1, 1);
    }
  }

  void _goToPeriod(String period, DateTime start, {required bool forward}) {
    ref.read(analyticsAnchorProvider.notifier).set(_adjacentAnchor(period, start, forward: forward));
  }

  Future<void> _exportRange({required DateTime from, required DateTime to, required String label}) async {
    setState(() => _exporting = true);
    try {
      // `to` is exclusive everywhere in this API (see backend/docs/API.md) —
      // callers picking a calendar day range (a `range.end` from the
      // backend, or a date-range-picker's last day) add one day themselves
      // rather than this method guessing which case it's in.
      await ref.read(exportControllerProvider.notifier).shareXlsx(from: from, to: to, label: label);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not export expenses';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCustomRange() async {
    final now = DateTime.now();
    final picked = await pickFriendlyDateRange(
      context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initial: DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked == null || !mounted) return;

    // The picker returns calendar days inclusive of both ends — add a day
    // to the end so the exclusive `to` boundary covers all of the last day.
    final lastDay = DateTime(picked.end.year, picked.end.month, picked.end.day);
    final to = lastDay.add(const Duration(days: 1));
    final from = DateTime(picked.start.year, picked.start.month, picked.start.day);
    final label = from.year == lastDay.year && from.month == lastDay.month && from.day == lastDay.day
        ? Formatters.dayMonthYear(from)
        : '${Formatters.dayMonthYear(from)} – ${Formatters.dayMonthYear(lastDay)}';
    await _exportRange(from: from, to: to, label: label);
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(analyticsPeriodProvider);
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // No own Scaffold/AppBar — one page of RootShell's PageView.
    return RefreshIndicator(
      onRefresh: () => ref.refresh(analyticsSummaryProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false, // the checkmark ate into "Week"/"Month"/"Year"'s width — the fill color already shows the selection
            style: const ButtonStyle(visualDensity: VisualDensity(horizontal: -4)),
            segments: const [
              ButtonSegment(value: 'day', label: Text('Day')),
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
              ButtonSegment(value: 'year', label: Text('Year')),
            ],
            selected: {period},
            onSelectionChanged: (selection) {
              ref.read(analyticsPeriodProvider.notifier).set(selection.first);
              ref.read(analyticsAnchorProvider.notifier).set(null); // switching period always resets to "current"
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          summaryAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Could not load analytics: $e'),
            ),
            data: (summary) {
              final now = DateTime.now();
              final nextAnchor = _adjacentAnchor(period, summary.range.start, forward: true);
              final canGoForward = !nextAnchor.isAfter(now);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Which month/week/year we're looking at, with prev/next —
                  // shown even when there's nothing logged, so it's always
                  // clear what an empty state is empty *for*.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _goToPeriod(period, summary.range.start, forward: false),
                      ),
                      Expanded(
                        child: Text(
                          Formatters.periodLabel(period, summary.range.start, summary.range.end),
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: canGoForward ? () => _goToPeriod(period, summary.range.start, forward: true) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AmountTile(
                    header: Text('Total', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    amountText: Formatters.currency(summary.total),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (summary.byCategory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: EmptyState(icon: Icons.receipt_long_outlined, title: 'Nothing logged for this period'),
                    )
                  else
                    for (final entry in summary.byCategory) _CategoryBreakdownRow(entry: entry, total: summary.total),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        // Defaults to whatever period is currently on screen
                        // (the label above the total, e.g. "September 2026")
                        // — "Choose a custom date range instead" below is
                        // where that gets overridden, so the button itself
                        // doesn't need to spell either behavior out in its
                        // own label; the info tooltip next to it does.
                        onPressed: _exporting
                            ? null
                            : () => _exportRange(
                                  from: summary.range.start,
                                  to: summary.range.end,
                                  label: Formatters.periodLabel(period, summary.range.start, summary.range.end),
                                ),
                        icon: _exporting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.ios_share_outlined),
                        label: Text(_exporting ? 'Exporting...' : 'Export Excel Sheet'),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Tooltip(
                        message: 'Exports expenses for the period shown above '
                            '(${Formatters.periodLabel(period, summary.range.start, summary.range.end)})',
                        // Defaults to long-press on mobile, which isn't a
                        // discoverable gesture on its own — a plain tap
                        // reveals it immediately instead.
                        triggerMode: TooltipTriggerMode.tap,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(Icons.info_outline, size: 20, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _exporting ? null : _exportCustomRange,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Choose a custom date range instead'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownRow extends StatelessWidget {
  final CategoryBreakdown entry;
  final double total;

  const _CategoryBreakdownRow({required this.entry, required this.total});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final percent = total == 0 ? 0 : (entry.total / total * 100);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          CategoryAvatar(icon: entry.category.icon, colorHex: entry.category.color, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(entry.category.name, style: textTheme.bodyLarge)),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(Formatters.currency(entry.total), style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
