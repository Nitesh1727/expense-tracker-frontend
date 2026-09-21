import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/core_providers.dart';
import '../data/export_api.dart';
import '../data/local_export_api.dart';
import '../../../core/config/app_config.dart';

final exportApiProvider = Provider<ExportApi>(
    (ref) => AppConfig.isLocal ? LocalExportApi(ref.watch(localDatabaseProvider)) : RemoteExportApi(ref.watch(apiClientProvider)));

class ExportController extends Notifier<void> {
  @override
  void build() {}

  /// Downloads the `.xlsx`, writes it to the app's temp directory, and opens
  /// the native share sheet — lets the user save to Files/Drive/email it, or
  /// open it directly in Excel/Google Sheets. Never writes to shared/
  /// external storage directly, which would need extra Android permissions
  /// that complicate Play Store review (see backend/docs/API.md export
  /// notes). [label] (e.g. "September 2026") names both the file itself and
  /// — via the API call — the workbook's sheet, so what the user sees in
  /// their Files app/share sheet matches what they see once they open it.
  Future<void> shareXlsx({DateTime? from, DateTime? to, required String label}) async {
    final bytes = await ref.read(exportApiProvider).downloadXlsx(from: from, to: to, label: label);
    final dir = await getTemporaryDirectory();
    final safeLabel = label.replaceAll(RegExp(r'[/\\:*?"<>|]'), '');
    final file = File('${dir.path}/Expenses - $safeLabel.xlsx');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'My expenses',
      ),
    );
  }
}

final exportControllerProvider = NotifierProvider<ExportController, void>(ExportController.new);
