import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../export/presentation/export_controller.dart';
import 'auth_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _exporting = false;
  bool _deleting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await ref.read(exportControllerProvider.notifier).shareCsv();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not export expenses';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _logout() => ref.read(authControllerProvider.notifier).logout();

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This permanently deletes your account and every expense you\'ve logged. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not delete account';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.person_outline, color: colorScheme.primary, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? 'Welcome', style: textTheme.titleLarge),
                  if (user?.phone != null)
                    Text(user!.phone!, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: const Text('Export as CSV'),
                  subtitle: const Text('Opens in Google Sheets, Mail, etc.'),
                  trailing: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  onTap: _exporting ? null : _export,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
              title: Text('Delete account', style: TextStyle(color: colorScheme.error)),
              subtitle: const Text('Permanently deletes your account and data'),
              trailing: _deleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onTap: _deleting ? null : _deleteAccount,
            ),
          ),
        ],
      ),
    );
  }
}
