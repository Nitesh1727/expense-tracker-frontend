import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/value_notifier_provider.dart';
import '../data/analytics_api.dart';
import '../domain/analytics_summary.dart';

final analyticsApiProvider = Provider<AnalyticsApi>((ref) => AnalyticsApi(ref.watch(apiClientProvider)));

/// Selected period for the Analytics screen — Day/Week/Month/Year segmented control.
final analyticsPeriodProvider = simpleValueProvider<String>('week');

final analyticsSummaryProvider = FutureProvider.autoDispose<AnalyticsSummary>((ref) {
  final period = ref.watch(analyticsPeriodProvider);
  return ref.watch(analyticsApiProvider).summary(period);
});

/// Home screen's "today's spending" card — deliberately independent of
/// [analyticsPeriodProvider] (the Analytics tab's own period selector), so
/// switching periods on the Analytics screen never changes what Home shows.
final todaySummaryProvider = FutureProvider.autoDispose<AnalyticsSummary>(
  (ref) => ref.watch(analyticsApiProvider).summary('day'),
);

/// Trend has no "day" view server-side (a single day has nothing to trend
/// against) — the Analytics screen only requests this for week/month/year.
final analyticsTrendProvider = FutureProvider.autoDispose<AnalyticsTrend>((ref) {
  final period = ref.watch(analyticsPeriodProvider);
  return ref.watch(analyticsApiProvider).trend(period == 'day' ? 'week' : period);
});
