import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'profile_prompt_screen.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;

  /// Only populated when the backend is running in dev mode (no real SMS
  /// provider configured) — pre-fills the field for fast local testing.
  final String? devCode;

  const OtpVerifyScreen({super.key, required this.phone, this.devCode});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  late final _codeController = TextEditingController(text: widget.devCode);
  bool _verifying = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length != 6) return;

    // See EmailAuthScreen._submit — clears a stale error from a previous
    // failed attempt so it can't linger onto the screen this navigates to.
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _verifying = true);
    try {
      final result = await ref.read(authControllerProvider.notifier).verifyOtp(widget.phone, _codeController.text.trim());
      if (!mounted) return;

      if (result.isNewUser) {
        // A new signup: AuthController deliberately hasn't flipped to
        // logged-in yet (see its class comment) — show the optional name
        // prompt first, replacing this screen so back-navigation can't
        // return to "enter the code" once already verified.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ProfilePromptScreen(user: result.user)),
        );
      } else {
        // Existing user: AuthController's state already flipped to
        // AsyncData(user), which makes AuthGate (lib/app.dart) swap its
        // content to RootShell underneath — but this screen sits on top of
        // it via WelcomeScreen -> PhoneEntryScreen -> OtpVerifyScreen (two
        // pushes deep). A single pop() only revealed PhoneEntryScreen again
        // — a real regression from adding WelcomeScreen, caught live: phone
        // login looked like it looped back to "enter your number" forever.
        // popUntil(isFirst) clears the whole auth stack regardless of depth.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Something went wrong';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(widget.phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New code sent')));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Something went wrong';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        // See WelcomeScreen's build() for why a centered Column alone isn't
        // safe here — the code field autofocuses (keyboard opens
        // immediately), which combined with a landscape rotation or a
        // larger text-size setting is exactly the kind of short-viewport
        // case this guards against. Keeps the same centered look when
        // everything fits and only scrolls once it doesn't.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Enter the code', style: textTheme.headlineMedium).animate().fadeIn().slideY(begin: 0.1, end: 0),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'We sent a 6-digit code to ${widget.phone}',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                // titleLarge, not headlineSmall — this is a numeric PIN entry, not a
                // heading, so it should stay in the sans body font, not the serif
                // AppTheme applies to headline* styles. fontSize matches headlineSmall's
                // default so the box doesn't visually shrink from this swap.
                style: textTheme.titleLarge?.copyWith(letterSpacing: 12, fontSize: 24, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(counterText: ''),
                onSubmitted: (_) => _verify(),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Verify', onPressed: _verify, loading: _verifying)
                  .animate()
                  .fadeIn(delay: 200.ms),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _resending ? null : _resend,
                  child: Text(_resending ? 'Sending...' : 'Resend code'),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}


