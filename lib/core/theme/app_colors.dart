import 'package:flutter/material.dart';

/// Color tokens — see frontend/docs/DESIGN_SYSTEM.md for the rationale
/// behind each value. Widgets should never hardcode a color; always pull
/// from here (or from `Theme.of(context).colorScheme` where it maps
/// cleanly) so light/dark mode and future palette tweaks stay one-line
/// changes instead of a hunt through every screen.
class AppColors {
  AppColors._();

  // Light
  static const lightBackground = Color(0xFFFAFAFA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF111827);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightBorder = Color(0xFFE5E7EB);

  // Dark
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkTextPrimary = Color(0xFFF5F5F5);
  static const darkTextSecondary = Color(0xFFA1A1AA);
  static const darkBorder = Color(0xFF2A2A2A);

  // Shared across both modes
  static const primaryLight = Color(0xFF16A34A);
  static const primaryDark = Color(0xFF22C55E);
  static const error = Color(0xFFDC2626);
  static const errorDark = Color(0xFFF87171);

  /// The curated palette every category color/chart segment is picked
  /// from — mirrors backend/src/constants/categoryPresets.js exactly, so
  /// a hex the backend sends always maps to a name here.
  static const curatedPalette = <String, Color>{
    'amber': Color(0xFFF59E0B),
    'blue': Color(0xFF3B82F6),
    'violet': Color(0xFF8B5CF6),
    'red-orange': Color(0xFFEF4444),
    'pink': Color(0xFFEC4899),
    'teal': Color(0xFF14B8A6),
    'gray': Color(0xFF6B7280),
    'green': Color(0xFF22C55E),
    'indigo': Color(0xFF6366F1),
    'brown': Color(0xFF92400E),
  };

  /// Parses a "#RRGGBB" hex string (as sent by the backend) into a Color.
  static Color fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
