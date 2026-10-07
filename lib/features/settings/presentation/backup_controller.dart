import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/core_providers.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../categories/presentation/category_controller.dart';
import '../../expenses/presentation/expense_providers.dart';

/// Local mode only — cloud mode's data already lives on the server, so there
/// is nothing here to back up. Backs the on-device database up to (or
/// restores it from) a plain file the user keeps themselves: copied to
/// another phone, uploaded to Drive/iCloud by hand, or emailed to themselves.
/// There is no automatic sync — see docs/DATA_MODES.md for why that's out of
/// scope for now.
class BackupController extends Notifier<void> {
  @override
  void build() {}

  /// Writes a snapshot to the temp dir and opens the native share sheet, so
  /// the user picks where it goes — Drive, Files, email, anywhere — the same
  /// pattern as the existing Excel export, and for the same reason: never
  /// writes to shared/external storage directly.
  Future<void> backupNow() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/SpendWise Backup - $stamp.db');
    await ref.read(localDatabaseProvider).exportSnapshotTo(file.path);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/octet-stream')], subject: 'SpendWise backup'),
    );
  }

  /// Replaces every expense and category on this device with what's in
  /// [backupFilePath]. Every screen/provider reading local data gets
  /// invalidated afterward so nothing on screen is left showing data that no
  /// longer exists.
  Future<void> restore(String backupFilePath) async {
    await ref.read(localDatabaseProvider).restoreFromFile(backupFilePath);

    ref.invalidate(categoryControllerProvider);
    ref.invalidate(homeFeedControllerProvider);
    ref.invalidate(expenseHistoryFilterProvider);
    ref.invalidate(expenseFiltersEverAppliedProvider);
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(analyticsSummaryProvider);
    ref.invalidate(analyticsTrendProvider);
  }
}

final backupControllerProvider = NotifierProvider<BackupController, void>(BackupController.new);
