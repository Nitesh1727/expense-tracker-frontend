import '../../../core/network/api_client.dart';
import '../domain/daily_summary.dart';
import '../domain/expense.dart';

class ExpenseListResult {
  final List<Expense> items;
  final int page;
  final int limit;
  final int total;
  // Sum of `amount` across every matching document for the current filter,
  // not just the items loaded so far — lets the History screen show an
  // accurate running total without needing every page fetched first.
  final double totalAmount;

  ExpenseListResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalAmount,
  });

  bool get hasMore => items.length + (page - 1) * limit < total;
}

class DailySummaryResult {
  final List<DailySummary> days;
  final int page;
  final int limit;
  final bool hasMore;

  DailySummaryResult({required this.days, required this.page, required this.limit, required this.hasMore});
}

/// A DateTime serialized without `.toUtc()` first sends ambiguous wall-clock
/// digits with no offset — `new Date(str)` on the Node side then interprets
/// it as local time *in whatever timezone the server process runs in*, which
/// silently corrupts date-range filters if that's not the device's timezone.
/// This is the exact bug class already found and fixed on the backend
/// (dateRange.util.js) — every date leaving this API client goes through
/// here so it can't recur from a call site forgetting `.toUtc()`.
String _toUtcIso(DateTime date) => date.toUtc().toIso8601String();

class ExpenseApi {
  final ApiClient _client;

  ExpenseApi(this._client);

  Future<ExpenseListResult> list({
    DateTime? from,
    DateTime? to,
    String? categoryId,
    String? q,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _client.dio.get('/expenses', queryParameters: {
        if (from != null) 'from': _toUtcIso(from),
        if (to != null) 'to': _toUtcIso(to),
        if (categoryId != null) 'categoryId': categoryId,
        if (q != null) 'q': q,
        'page': page,
        'limit': limit,
      });
      return ExpenseListResult(
        items: (res.data['items'] as List).map((e) => Expense.fromJson(e)).toList(),
        page: res.data['page'] as int,
        limit: res.data['limit'] as int,
        total: res.data['total'] as int,
        totalAmount: (res.data['totalAmount'] as num).toDouble(),
      );
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Powers Home's collapsible day-tiles — one entry per day with expenses,
  /// paginated by day count. See backend/docs/API.md. [from]/[to] (optional)
  /// scope the whole summary to a range — used by the Search screen's
  /// date-only results view; Home's own call omits them for full history.
  Future<DailySummaryResult> dailySummary({DateTime? from, DateTime? to, int page = 1, int limit = 15}) async {
    try {
      final res = await _client.dio.get('/expenses/daily-summary', queryParameters: {
        if (from != null) 'from': _toUtcIso(from),
        if (to != null) 'to': _toUtcIso(to),
        'page': page,
        'limit': limit,
      });
      return DailySummaryResult(
        days: (res.data['days'] as List).map((d) => DailySummary.fromJson(d)).toList(),
        page: res.data['page'] as int,
        limit: res.data['limit'] as int,
        hasMore: res.data['hasMore'] as bool,
      );
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Expense> create({required double amount, required String description, required String categoryId, DateTime? date}) async {
    try {
      final res = await _client.dio.post('/expenses', data: {
        'amount': amount,
        'description': description,
        'categoryId': categoryId,
        if (date != null) 'date': _toUtcIso(date),
      });
      return Expense.fromJson(res.data['expense']);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Expense> update(String id, {double? amount, String? description, String? categoryId, DateTime? date}) async {
    try {
      final res = await _client.dio.put('/expenses/$id', data: {
        if (amount != null) 'amount': amount,
        if (description != null) 'description': description,
        if (categoryId != null) 'categoryId': categoryId,
        if (date != null) 'date': _toUtcIso(date),
      });
      return Expense.fromJson(res.data['expense']);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.dio.delete('/expenses/$id');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
