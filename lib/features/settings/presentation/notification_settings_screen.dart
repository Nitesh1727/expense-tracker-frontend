import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../auth/presentation/auth_controller.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.mail_outline),
              title: const Text('Monthly email reports'),
              subtitle: const Text('A spending summary + spreadsheet, sent after each month ends'),
              // Only meaningful for an email-based account — a phone-only
              // one has no address to send it to. Defaults true (off is the
              // explicit choice, not the starting point) so it's disabled
              // rather than hidden if there's no email yet, matching how
              // the rest of this row would look once one's added.
              value: user?.email != null && user!.monthlyReportEnabled,
              onChanged: user?.email == null
                  ? null
                  : (value) => ref.read(authControllerProvider.notifier).updateProfile(monthlyReportEnabled: value),
            ),
          ),
        ],
      ),
    );
  }
}
