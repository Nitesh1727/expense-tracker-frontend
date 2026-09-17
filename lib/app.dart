import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/core_providers.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/root_shell.dart';
import 'core/widgets/splash_screen.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/settings/presentation/settings_controller.dart';

class ExpenseTrackerApp extends ConsumerWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp(
      title: 'SpendWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(fontFamily: settings.font.fontFamily, primary: settings.accentColor.light),
      darkTheme: AppTheme.dark(fontFamily: settings.font.fontFamily, primary: settings.accentColor.dark),
      themeMode: settings.themeMode,
      // Text-size setting is applied as a global scale factor rather than
      // baked into the theme's font sizes, so it uniformly affects every
      // widget (including ones that don't read AppTypography, like default
      // Material components) exactly the way a user expects "text size" to work.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(settings.textSize.scale)),
        child: child!,
      ),
      home: const AuthGate(),
    );
  }
}

/// Swaps between the signed-out and signed-in halves of the app based on
/// [authControllerProvider]. Wired here (rather than in main()) once, on
/// first build, is where [ApiClient.onUnauthorized] gets connected to
/// [AuthController.logout] — see the widget below.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    // A 401 from any API call (expired token, or the account was deleted
    // elsewhere) should drop the user back to the phone-entry screen from
    // one place, not be handled ad hoc per screen.
    ref.read(apiClientProvider).onUnauthorized = () {
      ref.read(authControllerProvider.notifier).logout();
    };
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    final child = authState.when(
      loading: () => const SplashScreen(),
      error: (_, _) => const WelcomeScreen(),
      data: (user) => user == null ? const WelcomeScreen() : const RootShell(),
    );

    return AnimatedSwitcher(
      duration: AppMotion.emphasized,
      switchInCurve: AppMotion.emphasizedCurve,
      child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child),
    );
  }
}
