import '../../../core/network/api_client.dart';
import '../domain/expense.dart';

class ExpenseListResult {
  final List<Expense> items;
  final int page;
  final int limit;
  final int total;

  ExpenseListResult({required this.items, required this.page, required this.limit, required this.total});

  bool get hasMore => items.length + (page - 1) * limit < total;
}

class ExpenseApi {
  final ApiClient _client;

  ExpenseApi(this._client);

  Future<ExpenseListResult> list({DateTime? from, DateTime? to, String? categoryId, int page = 1, int limit = 20}) async {
    try {
      final res = await _client.dio.get('/expenses', queryParameters: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
        if (categoryId != null) 'categoryId': categoryId,
        'page': page,
        'limit': limit,
      });
      return ExpenseListResult(
        items: (res.data['items'] as List).map((e) => Expense.fromJson(e)).toList(),
        page: res.data['page'] as int,
        limit: res.data['limit'] as int,
        total: res.data['total'] as int,
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
        if (date != null) 'date': date.toIso8601String(),
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
        if (date != null) 'date': date.toIso8601String(),
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
