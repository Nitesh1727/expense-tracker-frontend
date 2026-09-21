import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

abstract class ExportApi {
  /// Returns the raw `.xlsx` bytes for the period the user is viewing;
  /// [label] is the on-screen period label, reused as the sheet name.
  Future<List<int>> downloadXlsx({DateTime? from, DateTime? to, String? label});
}

class RemoteExportApi implements ExportApi {
  final ApiClient _client;

  RemoteExportApi(this._client);

  /// Returns the raw `.xlsx` bytes — small enough (personal expense data)
  /// that there's no need to stream to disk directly from Dio. [from]/[to]
  /// scope the export to whatever period the user is currently viewing on
  /// the Analytics screen — "export what I'm looking at", not a separate,
  /// unrelated all-time dump. [label] is the human period label already
  /// shown on-screen (e.g. "September 2026") — the backend reuses it
  /// verbatim as the workbook's sheet name.
  @override
  Future<List<int>> downloadXlsx({DateTime? from, DateTime? to, String? label}) async {
    try {
      final res = await _client.dio.get<List<int>>(
        '/export/xlsx',
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (label != null) 'label': label,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? const [];
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
