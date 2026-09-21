import '../../../core/network/api_client.dart';
import '../domain/analytics_summary.dart';

abstract class AnalyticsApi {
  Future<AnalyticsSummary> summary(String period, {DateTime? anchor});
  Future<AnalyticsTrend> trend(String period, {DateTime? anchor});
}

class RemoteAnalyticsApi implements AnalyticsApi {
  final ApiClient _client;

  RemoteAnalyticsApi(this._client);

  @override
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

  @override
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
