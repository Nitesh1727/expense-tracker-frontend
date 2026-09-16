import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class ExportApi {
  final ApiClient _client;

  ExportApi(this._client);

  /// Returns the raw CSV text — small enough (personal expense data) that
  /// there's no need to stream to disk directly from Dio. [from]/[to] scope
  /// the export to whatever period the user is currently viewing on the
  /// Analytics screen — "export what I'm looking at", not a separate,
  /// unrelated all-time dump.
  Future<String> downloadCsv({DateTime? from, DateTime? to}) async {
    try {
      final res = await _client.dio.get<String>(
        '/export/csv',
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
        },
        options: Options(responseType: ResponseType.plain),
      );
      return res.data ?? '';
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
