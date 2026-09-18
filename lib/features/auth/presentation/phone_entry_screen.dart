import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'otp_verify_screen.dart';

/// Entry point of the app for a signed-out user. One field, one action —
/// signup and login are the same flow (see backend/docs/ARCHITECTURE.md).
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      return 'Enter a valid phone number with country code, e.g. +919876543210';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // See EmailAuthScreen._submit — clears a stale error from a previous
    // failed attempt so it can't linger onto the screen this navigates to.
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _submitting = true);
    final phone = _phoneController.text.trim();

    try {
      final devCode = await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpVerifyScreen(phone: phone, devCode: devCode)),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Something went wrong';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        // See WelcomeScreen's build() for why a centered Column alone isn't
        // safe here (landscape rotation, a larger text-size setting, a short
        // device) — this keeps the same centered look when everything fits
        // and only scrolls once it doesn't.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_rounded, size: 48, color: colorScheme.primary)
                    .animate()
                    .fadeIn()
                    .scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: AppSpacing.lg),
                Text('Track your spending', style: textTheme.headlineMedium)
                    .animate()
                    .fadeIn(delay: 100.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Enter your phone number to get a one-time code.',
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  // Matches the backend's own format (auth.validator.js): a
                  // '+' plus up to 15 digits.
                  maxLength: 16,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+919876543210',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: _validatePhone,
                  onFieldSubmitted: (_) => _submit(),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: 'Continue', onPressed: _submit, loading: _submitting)
                    .animate()
                    .fadeIn(delay: 250.ms),
              ],
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
