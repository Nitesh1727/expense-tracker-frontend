class DailySummary {
  final DateTime date;
  final double total;
  final int count;

  DailySummary({required this.date, required this.total, required this.count});

  // .toLocal() matters here for the same reason as Expense.date and
  // TrendPoint.bucket — the backend buckets by IST calendar day and returns
  // a UTC instant string; without converting, date-label formatting and the
  // {from, to} range this tile requests when expanded would be off by a day
  // near midnight.
  factory DailySummary.fromJson(Map<String, dynamic> json) => DailySummary(
        date: DateTime.parse(json['date'] as String).toLocal(),
        total: (json['total'] as num).toDouble(),
        count: json['count'] as int,
      );
}
