import '../../../core/network/api_client.dart';
import '../domain/analytics_summary.dart';

class AnalyticsApi {
  final ApiClient _client;

  AnalyticsApi(this._client);

  Future<AnalyticsSummary> summary(String period, {DateTime? anchor}) async {
    try {
      final res = await _client.dio.get('/analytics/summary', queryParameters: {
        'period': period,
        if (anchor != null) 'anchor': anchor.toUtc().toIso8601String(),
      });
      return AnalyticsSummary.fromJson(res.data);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<AnalyticsTrend> trend(String period, {DateTime? anchor}) async {
    try {
      final res = await _client.dio.get('/analytics/trend', queryParameters: {
        'period': period,
        if (anchor != null) 'anchor': anchor.toUtc().toIso8601String(),
      });
      return AnalyticsTrend.fromJson(res.data);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
