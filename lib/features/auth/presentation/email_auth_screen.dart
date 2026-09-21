import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'forgot_password_screen.dart';
import 'verify_signup_screen.dart';

/// Sign up and log in share one screen with a toggle — same fields layout,
/// only the name field and the submit label differ, so a separate route per
/// mode would just duplicate the form.
class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Defaults to login, not signup — most taps on "Continue with email" are
  // an existing user coming back, not someone creating a new account.
  bool _isSignup = false;
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Clears any error SnackBar left over from a previous failed attempt —
    // ScaffoldMessenger is shared app-wide, so without this a stale "wrong
    // password" banner from a first try could still be mid-display (its
    // default duration) when a fast retry succeeds and navigates to Home,
    // making it look like login failed even though it just succeeded.
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _submitting = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final notifier = ref.read(authControllerProvider.notifier);

    try {
      if (_isSignup) {
        final name = _nameController.text.trim();
        // Sends the code but creates no account yet — that only happens once
        // it's confirmed on the next screen, so there's nothing to skip past
        // and nothing left behind if the email never arrives.
        await notifier.requestSignup(email: email, password: password, name: name.isNotEmpty ? name : null);
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerifySignupScreen(email: email)));
        }
        return;
      }

      await notifier.loginEmail(email: email, password: password);
      // AuthController's state is now logged-in; AuthGate (lib/app.dart) swaps
      // its content to RootShell underneath this screen (pushed on top of it),
      // so pop to reveal it. popUntil(isFirst), not a plain pop() — a single
      // pop only removes one level, and screens stack deeper than one here
      // (see ProfileScreen._logout for the same lesson in reverse).
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isSignup ? 'Create your account' : 'Welcome back', style: textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _isSignup ? 'Takes less than a minute.' : 'Log in with your email and password.',
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_isSignup) ...[
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    // Matches the backend's own cap (auth.validator.js).
                    maxLength: 50,
                    decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'e.g. Nitesh Yadav'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: [_isSignup ? AutofillHints.newPassword : AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (_isSignup && (value?.length ?? 0) < 8) return 'At least 8 characters';
                    if (!_isSignup && (value?.isEmpty ?? true)) return 'Password is required';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (!_isSignup) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _isSignup ? 'Create account' : 'Log in',
                  onPressed: _submit,
                  loading: _submitting,
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: _submitting ? null : () => setState(() => _isSignup = !_isSignup),
                    child: Text(_isSignup ? 'Already have an account? Log in' : "New here? Create an account"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
