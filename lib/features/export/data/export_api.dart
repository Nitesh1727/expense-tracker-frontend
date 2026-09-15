import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class ExportApi {
  final ApiClient _client;

  ExportApi(this._client);

  /// Returns the raw CSV text — small enough (personal expense data) that
  /// there's no need to stream to disk directly from Dio.
  Future<String> downloadCsv() async {
    try {
      final res = await _client.dio.get<String>(
        '/export/csv',
        options: Options(responseType: ResponseType.plain),
      );
      return res.data ?? '';
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
