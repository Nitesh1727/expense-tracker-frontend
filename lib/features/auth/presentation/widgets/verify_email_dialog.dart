import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../auth_controller.dart';

/// Shown once, right after email signup (see EmailAuthScreen._submit) —
/// there's no persistent "verify your email" entry elsewhere for a user to
/// come back to this later; skipping it here (Cancel) just leaves the
/// account unverified, per "we will not verify everytime". Sends a fresh
/// code the moment it opens, with its own "Resend" in case the first one
/// didn't arrive (e.g. it landed in spam). Returns the same Future
/// `showDialog` does, so the caller can await it finishing (Cancel or a
/// successful verify) before continuing.
Future<void> showVerifyEmailDialog(BuildContext context, WidgetRef ref) {
  return showDialog(context: context, builder: (context) => const _VerifyEmailDialog());
}

class _VerifyEmailDialog extends ConsumerStatefulWidget {
  const _VerifyEmailDialog();

  @override
  ConsumerState<_VerifyEmailDialog> createState() => _VerifyEmailDialogState();
}

class _VerifyEmailDialogState extends ConsumerState<_VerifyEmailDialog> {
  final _codeController = TextEditingController();
  bool _sending = true;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resendVerificationEmail();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not send the code';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length != 6) return;

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(_codeController.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not verify';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Verify your email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sending ? 'Sending a code...' : 'Enter the 6-digit code we sent you.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            enabled: !_sending,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: textTheme.titleLarge?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(counterText: ''),
            onSubmitted: (_) => _verify(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_error!, style: textTheme.bodySmall?.copyWith(color: colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _sending ? null : _resend,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(_sending ? 'Sending...' : 'Resend code'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: 'Verify', onPressed: _sending ? null : _verify, loading: _verifying),
      ],
    );
  }
}
