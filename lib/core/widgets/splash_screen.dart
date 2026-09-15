import 'package:flutter/material.dart';

/// Shown only during the brief startup check for a stored, still-valid
/// token (see AuthController.build in auth_controller.dart).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Icon(
          Icons.account_balance_wallet_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
