import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bar_title.dart';
import 'account_settings_screen.dart';
import 'display_settings_screen.dart';
import 'notification_settings_screen.dart';

/// Top-level Settings hub — categories that each drill into their own
/// sub-screen, the way Apple's Settings app is organized, rather than one
/// long flat page. Deliberately structured to scale: a new settings area
/// just needs one more row here plus its own sub-screen, instead of a
/// growing flat list on either this screen or Profile.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune_outlined),
                  title: const Text('Display'),
                  subtitle: const Text('Theme, accent color, text size, font'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DisplaySettingsScreen())),
                ),
                // Monthly email reports and change-password only make sense with
                // an emailed account, which local mode doesn't have.
                if (!AppConfig.isLocal) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: const Text('Monthly email reports'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Account'),
                  subtitle: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
                ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
