import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/app_button.dart';
import 'backup_controller.dart';

/// Local mode has no server and no login, so there's nothing to re-download
/// if the phone is lost or replaced — this screen is the only safety net.
/// Reachable only from Settings when [AppConfig.isLocal] (see
/// SettingsScreen), since cloud mode's data already lives on the server.
class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  bool _backingUp = false;
  bool _restoring = false;

  Future<void> _backup() async {
    setState(() => _backingUp = true);
    try {
      await ref.read(backupControllerProvider.notifier).backupNow();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create a backup')));
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _restore() async {
    final picked = (await FilePicker.pickFiles()).firstOrNull;
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data on this phone?'),
        content: const Text(
          'This replaces every expense and category currently on this device with what\'s in the backup file. '
          'If you haven\'t backed up what\'s here now, do that first — this cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Replace', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _restoring = true);
    try {
      // Read via the picker's own XFile rather than trusting `picked.path`
      // directly — a file picked from a cloud provider (e.g. Google Drive)
      // has no local path at all, only a content URI this can still read
      // from. Writing it into our own temp dir gives restoreFromFile an
      // ordinary file path to work with either way.
      final bytes = await picked.readAsBytes();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${picked.name}';
      await File(path).writeAsBytes(bytes);
      await ref.read(backupControllerProvider.notifier).restore(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data restored')));
    } catch (e) {
      if (!mounted) return;
      final message = e is FormatException
          ? e.message
          : e is ApiException
              ? e.message
              : 'Could not restore this backup';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Everything you log lives only on this phone — there\'s no account and nothing syncs anywhere on its own. '
            'Back up to a file you keep yourself: save it to Google Drive, email it to yourself, or move it to a new phone.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Back up now', onPressed: _backup, loading: _backingUp),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: _restoring ? null : _restore, child: const Text('Restore from backup')),
          if (_restoring) ...[
            const SizedBox(height: AppSpacing.md),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
