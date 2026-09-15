import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/core_providers.dart';
import '../data/export_api.dart';

final exportApiProvider = Provider<ExportApi>((ref) => ExportApi(ref.watch(apiClientProvider)));

class ExportController extends Notifier<void> {
  @override
  void build() {}

  /// Downloads the CSV, writes it to the app's temp directory, and opens
  /// the native share sheet — lets the user save to Files/Drive/email it,
  /// or open it directly in Google Sheets. Never writes to shared/external
  /// storage directly, which would need extra Android permissions that
  /// complicate Play Store review (see backend/docs/API.md export notes).
  Future<void> shareCsv() async {
    final csv = await ref.read(exportApiProvider).downloadCsv();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/expenses-${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: 'My expenses'),
    );
  }
}

final exportControllerProvider = NotifierProvider<ExportController, void>(ExportController.new);
