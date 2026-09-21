import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/avatar_glyph.dart';
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

  /// Profile is a *pushed* screen (not a tab of RootShell) — flipping the
  /// auth state to logged-out swaps what AuthGate shows underneath, but
  /// doesn't by itself pop *this* screen off the stack, so it stayed on
  /// top hiding the swapped-in WelcomeScreen instead of visibly returning
  /// to it. popUntil clears back to the root regardless of how deep this
  /// screen was reached from.
  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Local mode has no account to delete — the same slot erases the on-device
  // data instead, worded so it can't be mistaken for anything milder.
  static final _local = AppConfig.isLocal;

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_local ? 'Erase all data?' : 'Delete account?'),
        content: Text(_local
            ? 'This permanently erases every expense and custom category on this device and resets your profile. This cannot be undone.'
            : 'This permanently deletes your account and every expense you\'ve logged. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_local ? 'Erase' : 'Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      // Same reasoning as _logout — pop this pushed screen off so the
      // swapped-in WelcomeScreen is actually visible. (Local mode stays
      // signed in, so there it just returns to the app.)
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : _local ? 'Could not erase data' : 'Could not delete account';
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
                child: AvatarGlyph(avatar: user?.avatar, name: user?.name, size: 64, color: Colors.white),
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
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  subtitle: Text(_local ? 'Display' : 'Display, notifications, and account'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                if (!_local) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Log out'),
                    onTap: _logout,
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
              title: Text(_local ? 'Erase all data' : 'Delete account', style: TextStyle(color: colorScheme.error)),
              subtitle: Text(_local ? 'Permanently erases all data on this device' : 'Permanently deletes your account and data'),
              trailing: _deleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onTap: _deleting ? null : _deleteAccount,
            ),
          ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.05, end: 0),
        ],
      ),
    );
  }
}
