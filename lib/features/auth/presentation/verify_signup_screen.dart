import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';

/// Step 2 of email signup. The account does not exist yet at this point —
/// entering the emailed code is what creates it (and logs the user in), so
/// backing out of this screen can't leave anyone half signed up, and a code
/// that never arrives can't leave a stuck account behind that then blocks
/// signing up again with the same address.
class VerifySignupScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifySignupScreen({super.key, required this.email});

  @override
  ConsumerState<VerifySignupScreen> createState() => _VerifySignupScreenState();
}

class _VerifySignupScreenState extends ConsumerState<VerifySignupScreen> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length != 6) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _verifying = true);
    try {
      await ref.read(authControllerProvider.notifier).verifySignup(email: widget.email, code: _codeController.text.trim());
      // AuthGate swaps to RootShell underneath the auth screens stacked on
      // top of it — popUntil (not pop) for the same reason as EmailAuthScreen.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Something went wrong';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _resending = true);
    try {
      await ref.read(authControllerProvider.notifier).resendSignupCode(widget.email);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verify your email', style: textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter the 6-digit code we sent to ${widget.email} to finish creating your account.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: textTheme.titleLarge?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(counterText: ''),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Verify & create account', onPressed: _verify, loading: _verifying),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _resending ? null : _resend,
                  child: Text(_resending ? 'Sending...' : "Didn't get it? Resend code"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
