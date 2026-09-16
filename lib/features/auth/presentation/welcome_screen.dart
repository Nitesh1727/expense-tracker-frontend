import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_spacing.dart';
import 'email_auth_screen.dart';
import 'phone_entry_screen.dart';

/// The signed-out landing screen — picks phone+OTP or email+password before
/// committing to either flow. Both create the same shape of account (see
/// backend/docs/ARCHITECTURE.md auth flow).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: colorScheme.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 36, color: Colors.white),
              ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: AppSpacing.lg),
              Text('SpendWise', style: textTheme.displayLarge)
                  .animate()
                  .fadeIn(delay: 100.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Track your spending, effortlessly.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
                ),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Continue with phone'),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
                ),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Continue with email'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: colorScheme.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}
