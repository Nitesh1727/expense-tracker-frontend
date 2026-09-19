import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import 'email_auth_screen.dart';

/// The signed-out landing screen. Phone+OTP sign-in used to be offered
/// alongside email+password here (see git history / backend's still-intact
/// `/auth/otp/*` routes) — dropped from the UI "for now" per explicit user
/// request, since real SMS delivery costs money at every provider and
/// there's no free gateway to wire up yet. Re-adding it later is a frontend-
/// only change: the backend OTP flow was left running, just unreachable
/// from here.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        // A plain centered Column here overflows if the content is ever
        // taller than the viewport (landscape rotation, a larger text-size
        // setting, a short device) since nothing about it can shrink or
        // scroll. LayoutBuilder + a minHeight-constrained scroll view keeps
        // the exact same centered look when everything fits (the Column is
        // *at least* as tall as the screen, so centering still applies) and
        // only starts scrolling once it doesn't.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The app's real logo (assets/icon/app_icon.png — also the
              // launcher icon, see pubspec.yaml's flutter_launcher_icons
              // config) rather than a generic Material icon standing in for
              // one. It's a full-bleed square with its own gradient baked
              // in, so this just clips the corners and adds the same
              // colored shadow the placeholder version had.
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: colorScheme.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  // The source PNG is 1024x1024 (it doubles as the launcher
                  // icon) but only ever renders at 72x72 here — without
                  // cacheWidth/Height, Flutter decodes the full-resolution
                  // bitmap into memory (~4MB) and downscales it on every
                  // paint, instead of decoding once at roughly the size it's
                  // actually shown at.
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    cacheWidth: (72 * MediaQuery.of(context).devicePixelRatio).round(),
                    cacheHeight: (72 * MediaQuery.of(context).devicePixelRatio).round(),
                  ),
                ),
              ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: AppSpacing.lg),
              // displayLarge's size, but opted into the heading serif — AppTheme
              // reserves the bare displayLarge token for numbers (AmountTile), so
              // the app's wordmark asks for the serif explicitly here instead.
              Text('SpendWise', style: AppTheme.headingStyle(textTheme.displayLarge, weight: FontWeight.w700))
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
                  MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
                ),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Continue with email'),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
