import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';

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

    setState(() => _verifying = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(widget.phone, _codeController.text.trim());
      // On success AuthController's state flips to AsyncData(user); the
      // router redirects away from auth screens automatically (see app_router.dart).
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                style: textTheme.headlineSmall?.copyWith(letterSpacing: 12),
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
    );
  }
}
