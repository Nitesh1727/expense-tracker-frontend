import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/value_notifier_provider.dart';
import '../data/analytics_api.dart';
import '../domain/analytics_summary.dart';

final analyticsApiProvider = Provider<AnalyticsApi>((ref) => AnalyticsApi(ref.watch(apiClientProvider)));

/// Selected period for the Analytics screen — Day/Week/Month/Year segmented control.
final analyticsPeriodProvider = simpleValueProvider<String>('week');

/// null = "current" period (today/this week/this month/this year, server
/// default). Set to a specific instant when the user navigates to a
/// previous/next period via the chevrons — see AnalyticsScreen's
/// _goToAdjacentPeriod, which computes the new anchor from the *previous*
/// fetch's authoritative `range.start` rather than doing its own calendar
/// math, so month-length/leap-year edge cases are never this file's problem.
final analyticsAnchorProvider = simpleValueProvider<DateTime?>(null);

final analyticsSummaryProvider = FutureProvider.autoDispose<AnalyticsSummary>((ref) {
  final period = ref.watch(analyticsPeriodProvider);
  final anchor = ref.watch(analyticsAnchorProvider);
  return ref.watch(analyticsApiProvider).summary(period, anchor: anchor);
});

// Trend chart was removed from the Analytics screen (kept simple, per the
// user) — analyticsTrendProvider used to live here. The backend's
// GET /analytics/trend endpoint and AnalyticsApi.trend()/AnalyticsTrend
// model are left in place (harmless, and a straightforward re-add if a
// trend view is wanted later), just no longer wired to any UI.

/// Home screen's big total-spend number — its own switchable period
/// (Today/This week/This month), defaulting to month, deliberately
/// independent of [analyticsPeriodProvider] (the Analytics tab's own
/// selector) so switching one never changes the other.
final homeSummaryPeriodProvider = simpleValueProvider<String>('month');

final homeSummaryProvider = FutureProvider.autoDispose<AnalyticsSummary>((ref) {
  final period = ref.watch(homeSummaryPeriodProvider);
  return ref.watch(analyticsApiProvider).summary(period);
});

/// Trend has no "day" view server-side (a single day has nothing to trend
/// against) — the Analytics screen only requests this for week/month/year.
final analyticsTrendProvider = FutureProvider.autoDispose<AnalyticsTrend>((ref) {
  final period = ref.watch(analyticsPeriodProvider);
  final anchor = ref.watch(analyticsAnchorProvider);
  return ref.watch(analyticsApiProvider).trend(period == 'day' ? 'week' : period, anchor: anchor);
});
