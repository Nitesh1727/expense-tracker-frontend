import 'package:flutter/material.dart';

/// Primary action button — thin wrapper over the themed ElevatedButton that
/// adds a built-in loading state, since almost every button in this app
/// triggers a network call.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AppButton({super.key, required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Text(label),
    );
  }
}
