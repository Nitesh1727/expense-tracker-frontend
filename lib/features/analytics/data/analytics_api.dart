import '../../../core/network/api_client.dart';
import '../domain/analytics_summary.dart';

class AnalyticsApi {
  final ApiClient _client;

  AnalyticsApi(this._client);

  Future<AnalyticsSummary> summary(String period) async {
    try {
      final res = await _client.dio.get('/analytics/summary', queryParameters: {'period': period});
      return AnalyticsSummary.fromJson(res.data);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<AnalyticsTrend> trend(String period) async {
    try {
      final res = await _client.dio.get('/analytics/trend', queryParameters: {'period': period});
      return AnalyticsTrend.fromJson(res.data);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
