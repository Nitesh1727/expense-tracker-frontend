import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/analytics_summary.dart';
import 'analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodProvider);
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsSummaryProvider);
          ref.invalidate(analyticsTrendProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'day', label: Text('Day')),
                ButtonSegment(value: 'week', label: Text('Week')),
                ButtonSegment(value: 'month', label: Text('Month')),
                ButtonSegment(value: 'year', label: Text('Year')),
              ],
              selected: {period},
              onSelectionChanged: (selection) => ref.read(analyticsPeriodProvider.notifier).set(selection.first),
            ),
            const SizedBox(height: AppSpacing.xl),
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
                if (summary.byCategory.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                    child: EmptyState(
                      icon: Icons.pie_chart_outline,
                      title: 'Nothing logged for this period',
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(Formatters.currency(summary.total), style: textTheme.displayLarge),
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
                );
              },
            ),
          ],
        ),
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
          Expanded(
            child: Text(entry.category.name, style: textTheme.bodyLarge),
          ),
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
