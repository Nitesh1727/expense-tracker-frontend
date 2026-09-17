import 'package:flutter/material.dart';

/// Screen-title text for an AppBar, always rendered at the theme's heading
/// size regardless of the user's text-size setting (Settings → Appearance →
/// Text size) — per explicit user request that the top-left screen headings
/// ("Home", "Analytics", "Display", ...) stay visually fixed while every
/// other piece of text in the app still respects that setting normally.
/// `textScaler: TextScaler.noScaling` opts this one widget out of the
/// ambient MediaQuery text scaler set in app.dart's MaterialApp.builder.
class AppBarTitle extends StatelessWidget {
  final String text;

  const AppBarTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, textScaler: TextScaler.noScaling);
  }
}
