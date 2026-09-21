import '../../../core/network/api_client.dart';
import '../domain/category.dart';

abstract class CategoryApi {
  Future<List<Category>> list();
  Future<Category> create({required String name, required String icon, required String color});
  Future<Category> update(String id, {String? name, String? icon, String? color});
  Future<void> delete(String id);
}

class RemoteCategoryApi implements CategoryApi {
  final ApiClient _client;

  RemoteCategoryApi(this._client);

  @override
  Future<List<Category>> list() async {
    try {
      final res = await _client.dio.get('/categories');
      return (res.data['categories'] as List).map((c) => Category.fromJson(c)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  @override
  Future<Category> create({required String name, required String icon, required String color}) async {
    try {
      final res = await _client.dio.post('/categories', data: {'name': name, 'icon': icon, 'color': color});
      return Category.fromJson(res.data['category']);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  @override
  Future<Category> update(String id, {String? name, String? icon, String? color}) async {
    try {
      final res = await _client.dio.put('/categories/$id', data: {
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      });
      return Category.fromJson(res.data['category']);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.dio.delete('/categories/$id');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
