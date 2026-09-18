/// A named quick period, or a user-picked custom range, or no date filter
/// at all. Kept as an explicit enum (rather than inferring "which preset is
/// this" by comparing computed from/to values back against what each preset
/// would currently produce) so the filter sheet can unambiguously highlight
/// which chip is selected.
enum HistoryPeriodPreset { all, today, week, month, custom }

extension HistoryPeriodPresetLabel on HistoryPeriodPreset {
  String get label => switch (this) {
        HistoryPeriodPreset.all => 'All time',
        HistoryPeriodPreset.today => 'Today',
        HistoryPeriodPreset.week => 'This week',
        HistoryPeriodPreset.month => 'This month',
        HistoryPeriodPreset.custom => 'Custom',
      };
}

/// History screen's active filter — category and time period compose
/// (both apply together, not either/or). `from`/`to` are only meaningful
/// when [period] isn't [HistoryPeriodPreset.all]; for [HistoryPeriodPreset.custom]
/// they're whatever the user picked, for the other presets they're computed
/// fresh each time the filter is applied (see ExpenseHistoryFilterSheet).
class ExpenseHistoryFilter {
  final String? categoryId; // null = All categories
  final HistoryPeriodPreset period;
  final DateTime? from;
  final DateTime? to; // exclusive, matching the API convention everywhere else

  const ExpenseHistoryFilter({this.categoryId, this.period = HistoryPeriodPreset.all, this.from, this.to});

  bool get isActive => categoryId != null || period != HistoryPeriodPreset.all;

  ExpenseHistoryFilter copyWith({
    String? categoryId,
    bool clearCategoryId = false,
    HistoryPeriodPreset? period,
    DateTime? from,
    DateTime? to,
  }) =>
      ExpenseHistoryFilter(
        categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
        period: period ?? this.period,
        from: from ?? this.from,
        to: to ?? this.to,
      );

  /// Computes {from, to} for a named preset in local (device) time — the API
  /// client's `.toUtc()` on the way out handles the conversion, matching how
  /// every other client-side date (e.g. the add-expense date picker) already
  /// works. Weeks start Monday, matching the backend's own convention
  /// (dateRange.util.js). Returns null for [HistoryPeriodPreset.all] and
  /// [HistoryPeriodPreset.custom] — the caller already has explicit from/to
  /// for custom, and "all" means no date filter at all.
  static (DateTime, DateTime)? rangeFor(HistoryPeriodPreset preset, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    switch (preset) {
      case HistoryPeriodPreset.today:
        return (startOfToday, startOfToday.add(const Duration(days: 1)));
      case HistoryPeriodPreset.week:
        final daysSinceMonday = startOfToday.weekday - DateTime.monday;
        final start = startOfToday.subtract(Duration(days: daysSinceMonday));
        return (start, start.add(const Duration(days: 7)));
      case HistoryPeriodPreset.month:
        final start = DateTime(today.year, today.month, 1);
        final end = DateTime(today.year, today.month + 1, 1);
        return (start, end);
      case HistoryPeriodPreset.all:
      case HistoryPeriodPreset.custom:
        return null;
    }
  }
}
