import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
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

  Future<void> _export(DateRange range) async {
    setState(() => _exporting = true);
    try {
      await ref.read(exportControllerProvider.notifier).shareCsv(
            from: range.start,
            to: range.end.subtract(const Duration(milliseconds: 1)),
          );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not export expenses';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(analyticsPeriodProvider);
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // No own Scaffold/AppBar — one page of RootShell's PageView.
    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(analyticsSummaryProvider.future),
        ref.refresh(analyticsTrendProvider.future),
      ]),
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
                  if (summary.byCategory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: EmptyState(icon: Icons.pie_chart_outline, title: 'Nothing logged for this period'),
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                              const SizedBox(height: AppSpacing.xs),
                              Text(Formatters.currency(summary.total), style: textTheme.displayLarge),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: _exporting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.ios_share_outlined),
                          tooltip: 'Export this period as CSV',
                          onPressed: _exporting ? null : () => _export(summary.range),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _CategoryPieChart(summary: summary),
                    const SizedBox(height: AppSpacing.lg),
                    for (final entry in summary.byCategory) _CategoryBreakdownRow(entry: entry, total: summary.total),
                    if (period != 'day') ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Trend', style: textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.md),
                      const _TrendChart(),
                    ],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final AnalyticsSummary summary;

  const _CategoryPieChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: [
            for (final entry in summary.byCategory)
              PieChartSectionData(
                value: entry.total,
                color: AppColors.fromHex(entry.category.color),
                title: '',
                radius: 40,
              ),
          ],
        ),
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

class _TrendChart extends ConsumerWidget {
  const _TrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(analyticsTrendProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return trendAsync.when(
      loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(height: 80, child: Center(child: Text('Could not load trend: $e'))),
      data: (trend) {
        if (trend.series.isEmpty) {
          return const SizedBox(height: 80, child: Center(child: Text('No data')));
        }

        final maxY = trend.series.map((p) => p.total).reduce((a, b) => a > b ? a : b);

        return SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 1 : maxY * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= trend.series.length) return const SizedBox.shrink();
                      final bucket = trend.series[index].bucket;
                      final label = trend.bucketUnit == 'month' ? Formatters.monthYear(bucket) : Formatters.dayMonth(bucket);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < trend.series.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: trend.series[i].total,
                        color: colorScheme.primary,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
