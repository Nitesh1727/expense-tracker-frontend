import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';

const _codeLength = 6;
const _resendCooldownSeconds = 30;

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
  final _focusNode = FocusNode();
  Timer? _cooldownTimer;
  int _cooldownLeft = _resendCooldownSeconds; // a code was just sent to get here
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    _focusNode.addListener(() => setState(() {})); // repaints the active-box highlight
    _codeController.addListener(() {
      setState(() => _error = null);
      if (_codeController.text.length == _codeLength) _verify();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownLeft <= 1) {
        timer.cancel();
      }
      if (mounted) setState(() => _cooldownLeft = _cooldownLeft - 1);
    });
  }

  Future<void> _verify() async {
    if (_verifying || _codeController.text.length != _codeLength) return;

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifySignup(email: widget.email, code: _codeController.text);
      // AuthGate swaps to RootShell underneath the auth screens stacked on
      // top of it — popUntil (not pop) for the same reason as EmailAuthScreen.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      _codeController.clear();
      setState(() => _error = e is ApiException ? e.message : 'Something went wrong. Please try again.');
      _focusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resendSignupCode(widget.email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('A new code is on its way')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Could not send a new code. Please try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final canResend = _cooldownLeft <= 0 && !_resending;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.mark_email_unread_outlined, size: 34, color: colorScheme.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Check your inbox', style: textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "We've sent a 6-digit verification code to",
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                widget.email,
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xl),
              _CodeBoxes(controller: _codeController, focusNode: _focusNode, hasError: _error != null, enabled: !_verifying),
              SizedBox(
                height: 36,
                child: Center(
                  child: _error != null
                      ? Text(_error!, style: textTheme.bodySmall?.copyWith(color: colorScheme.error), textAlign: TextAlign.center)
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Verify & create account',
                onPressed: _codeController.text.length == _codeLength ? _verify : null,
                loading: _verifying,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "Didn't receive it? Check your spam folder, or request a new code.",
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: canResend ? _resend : null,
                child: Text(
                  _resending
                      ? 'Sending...'
                      : _cooldownLeft > 0
                          ? 'Resend code in 0:${_cooldownLeft.toString().padLeft(2, '0')}'
                          : 'Resend code',
                ),
              ),
              TextButton(
                onPressed: _verifying ? null : () => Navigator.of(context).pop(),
                child: const Text('Wrong email? Go back'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your account is created only after your email is verified. The code expires in 5 minutes.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six digit boxes driven by one invisible text field laid over them — keeps
/// normal keyboard/paste/autofill behavior while looking like a code entry
/// row, instead of one long stretched text field.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final bool enabled;

  const _CodeBoxes({required this.controller, required this.focusNode, required this.hasError, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final text = controller.text;

    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _codeLength; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _Box(
                  char: i < text.length ? text[i] : '',
                  active: focusNode.hasFocus && i == text.length.clamp(0, _codeLength - 1),
                  hasError: hasError,
                  colorScheme: colorScheme,
                  textStyle: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                enabled: enabled,
                keyboardType: TextInputType.number,
                maxLength: _codeLength,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showCursor: false,
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final String char;
  final bool active;
  final bool hasError;
  final ColorScheme colorScheme;
  final TextStyle? textStyle;

  const _Box({
    required this.char,
    required this.active,
    required this.hasError,
    required this.colorScheme,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? colorScheme.error
        : active
            ? colorScheme.primary
            : colorScheme.outline;

    return Container(
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: active || hasError ? 2 : 1),
      ),
      child: Text(char, style: textStyle),
    );
  }
}
