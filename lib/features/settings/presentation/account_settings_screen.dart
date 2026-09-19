import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/change_password_screen.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    // Only an email/password account has a password to change — a phone
    // (OTP) account has none, and disabling instead of hiding the row keeps
    // this screen's shape stable rather than shifting around per account type.
    final hasPassword = user?.email != null;

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change password'),
              subtitle: hasPassword ? null : const Text('Not available for this sign-in method'),
              enabled: hasPassword,
              onTap: hasPassword
                  ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
