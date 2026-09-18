import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../settings/presentation/settings_screen.dart';
import 'auth_controller.dart';
import 'widgets/edit_profile_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _deleting = false;

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
    final initial = (user?.name?.isNotEmpty ?? false) ? user!.name![0].toUpperCase() : '👋';

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.65)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: colorScheme.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(initial, style: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'Add your name', style: textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                    if (user?.phone != null)
                      Text(user!.phone!, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    if (user?.email != null)
                      Text(user!.email!, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: user == null ? null : () => showEditProfileSheet(context, user),
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.05, end: 0),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune_outlined),
                  title: const Text('Display settings'),
                  subtitle: const Text('Text size and font'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  onTap: _logout,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
              title: Text('Delete account', style: TextStyle(color: colorScheme.error)),
              subtitle: const Text('Permanently deletes your account and data'),
              trailing: _deleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onTap: _deleting ? null : _deleteAccount,
            ),
          ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.05, end: 0),
        ],
      ),
    );
  }
}
