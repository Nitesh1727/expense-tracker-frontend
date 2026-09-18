import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/user.dart';
import 'auth_controller.dart';

/// Shown once, right after a *new* phone signup — optional, skippable. Not
/// shown for email signup (that form collects the name upfront) or for an
/// existing user logging back in. Whatever happens here (save or skip),
/// AuthController.completeOnboarding is what actually drops the user into
/// the app — see auth_controller.dart's class comment for why.
class ProfilePromptScreen extends ConsumerStatefulWidget {
  final User user;

  const ProfilePromptScreen({super.key, required this.user});

  @override
  ConsumerState<ProfilePromptScreen> createState() => _ProfilePromptScreenState();
}

class _ProfilePromptScreenState extends ConsumerState<ProfilePromptScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _finish(User user) {
    // Same reasoning as OtpVerifyScreen's popUntil: this screen was reached
    // via WelcomeScreen -> PhoneEntryScreen -> (pushReplacement)
    // ProfilePromptScreen, two levels above AuthGate's content — a single
    // pop() would only reveal PhoneEntryScreen again.
    ref.read(authControllerProvider.notifier).completeOnboarding(user);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _skip() => _finish(widget.user);

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty && email.isEmpty) {
      _skip();
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await ref.read(authApiProvider).updateProfile(
            name: name.isNotEmpty ? name : null,
            email: email.isNotEmpty ? email : null,
          );
      if (!mounted) return;
      _finish(updated);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not save — you can add this later in Profile';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        // See WelcomeScreen's build() for why a centered Column alone isn't
        // safe here — the name field autofocuses (keyboard opens
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
              Text('Welcome 👋', style: textTheme.headlineMedium).animate().fadeIn().slideY(begin: 0.1, end: 0),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tell us a bit about you — totally optional, you can add or change this later in Profile.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Nitesh Yadav'),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Continue', onPressed: _save, loading: _saving).animate().fadeIn(delay: 250.ms),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _skip,
                  child: const Text('Skip for now'),
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
