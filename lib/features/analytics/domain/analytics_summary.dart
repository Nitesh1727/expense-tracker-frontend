import '../../categories/domain/category.dart';

class CategoryBreakdown {
  final Category category;
  final double total;
  final int count;

  CategoryBreakdown({required this.category, required this.total, required this.count});

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) => CategoryBreakdown(
        category: Category.fromJson(json['category'] as Map<String, dynamic>),
        total: (json['total'] as num).toDouble(),
        count: json['count'] as int,
      );
}

class AnalyticsSummary {
  final String period;
  final double total;
  final List<CategoryBreakdown> byCategory;

  AnalyticsSummary({required this.period, required this.total, required this.byCategory});

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) => AnalyticsSummary(
        period: json['period'] as String,
        total: (json['total'] as num).toDouble(),
        byCategory: (json['byCategory'] as List).map((c) => CategoryBreakdown.fromJson(c)).toList(),
      );
}

class TrendPoint {
  final DateTime bucket;
  final double total;

  TrendPoint({required this.bucket, required this.total});

  // .toLocal() matters here: the backend buckets in IST and returns a UTC
  // instant string (see backend/src/utils/dateRange.util.js) — without
  // converting to the device's local time before formatting, the date label
  // shown to the user is off by one for anything near a day boundary. Caught
  // live: an expense logged "today" showed under yesterday's date on the
  // trend chart until this was added (matches the fix to Expense.fromJson's
  // `date` field below, which already had it).
  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        bucket: DateTime.parse(json['bucket'] as String).toLocal(),
        total: (json['total'] as num).toDouble(),
      );
}

class AnalyticsTrend {
  final String period;
  final String bucketUnit;
  final List<TrendPoint> series;

  AnalyticsTrend({required this.period, required this.bucketUnit, required this.series});

  factory AnalyticsTrend.fromJson(Map<String, dynamic> json) => AnalyticsTrend(
        period: json['period'] as String,
        bucketUnit: json['bucketUnit'] as String,
        series: (json['series'] as List).map((p) => TrendPoint.fromJson(p)).toList(),
      );
}
