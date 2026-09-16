import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_bottom_sheet.dart';
import '../../domain/user.dart';
import '../auth_controller.dart';

/// Same fields as the optional post-signup prompt (ProfilePromptScreen), but
/// pre-filled and always shown when the user taps to edit — not skippable
/// here since they're actively choosing to open it.
Future<void> showEditProfileSheet(BuildContext context, User user) {
  return showGlassBottomSheet(context, builder: (context) => _EditProfileSheet(user: user));
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final User user;

  const _EditProfileSheet({required this.user});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.user.name ?? '');
  late final _emailController = TextEditingController(text: widget.user.email ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            name: name.isNotEmpty ? name : null,
            email: email.isNotEmpty ? email : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not save profile';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit profile', style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Nitesh Yadav'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return null;
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: 'Save', onPressed: _save, loading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
