import '../../../core/local/ist.dart';
import '../../../core/local/local_database.dart';
import '../../categories/domain/category.dart';
import '../domain/analytics_summary.dart';
import 'analytics_api.dart';

/// SQLite implementation of [AnalyticsApi]; ranges and buckets are IST-based
/// (see [Ist]) exactly like the backend's.
class LocalAnalyticsApi implements AnalyticsApi {
  final LocalDatabase _local;

  LocalAnalyticsApi(this._local);

  @override
  Future<AnalyticsSummary> summary(String period, {DateTime? anchor}) async {
    final db = await _local.instance;
    final range = Ist.range(period, anchor);

    final rows = await db.rawQuery('''
      SELECT c.id, c.name, c.icon, c.color, SUM(e.amount) AS total, COUNT(*) AS n
      FROM expenses e JOIN categories c ON c.id = e.category_id
      WHERE e.date >= ? AND e.date < ?
      GROUP BY c.id
      ORDER BY total DESC
    ''', [range.start.millisecondsSinceEpoch, range.end.millisecondsSinceEpoch]);

    final byCategory = rows
        .map((r) => CategoryBreakdown(
              // The cloud's analytics payload carries no isDeletable, which
              // the model defaults to true — keep that so both modes match.
              category: Category(
                id: r['id'] as String,
                name: r['name'] as String,
                icon: r['icon'] as String,
                color: r['color'] as String,
                isDeletable: true,
              ),
              total: (r['total'] as num).toDouble(),
              count: r['n'] as int,
            ))
        .toList();

    return AnalyticsSummary(
      period: period,
      total: byCategory.fold(0.0, (sum, c) => sum + c.total),
      byCategory: byCategory,
      range: DateRange(start: range.start.toLocal(), end: range.end.toLocal()),
    );
  }

  @override
  Future<AnalyticsTrend> trend(String period, {DateTime? anchor}) async {
    final db = await _local.instance;
    final range = Ist.range(period, anchor);
    final byMonth = period == 'year';
    final shifted = 'CAST((e.date + ${Ist.offsetMs}) / 1000 AS INTEGER)';
    final bucketExpr = byMonth
        ? "strftime('%Y-%m', $shifted, 'unixepoch')"
        : '((e.date + ${Ist.offsetMs}) / ${Ist.dayMs})';

    final rows = await db.rawQuery('''
      SELECT $bucketExpr AS b, SUM(e.amount) AS total
      FROM expenses e
      WHERE e.date >= ? AND e.date < ?
      GROUP BY b ORDER BY b ASC
    ''', [range.start.millisecondsSinceEpoch, range.end.millisecondsSinceEpoch]);

    return AnalyticsTrend(
      period: period,
      bucketUnit: byMonth ? 'month' : 'day',
      series: rows.map((r) {
        final DateTime instant;
        if (byMonth) {
          final parts = (r['b'] as String).split('-');
          instant = Ist.monthStart(int.parse(parts[0]), int.parse(parts[1]));
        } else {
          instant = Ist.instantOfDayIndex(r['b'] as int);
        }
        return TrendPoint(bucket: instant.toLocal(), total: (r['total'] as num).toDouble());
      }).toList(),
    );
  }
}
