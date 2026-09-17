import 'package:flutter/material.dart';

/// Color tokens — see frontend/docs/DESIGN_SYSTEM.md for the rationale
/// behind each value. Widgets should never hardcode a color; always pull
/// from here (or from `Theme.of(context).colorScheme` where it maps
/// cleanly) so light/dark mode and future palette tweaks stay one-line
/// changes instead of a hunt through every screen.
class AppColors {
  AppColors._();

  // Light — warm neutrals (ivory/paper background, warm-black text) rather
  // than cool grays, matching the Claude app's palette per explicit request.
  static const lightBackground = Color(0xFFFAF9F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF2D2A26);
  static const lightTextSecondary = Color(0xFF7A776D);
  static const lightBorder = Color(0xFFE8E5DD);

  // Dark — Claude's signature warm charcoal, not a cool blue-gray.
  static const darkBackground = Color(0xFF262624);
  static const darkSurface = Color(0xFF30302E);
  static const darkTextPrimary = Color(0xFFF2F0EA);
  static const darkTextSecondary = Color(0xFFA8A599);
  static const darkBorder = Color(0xFF3E3D38);

  // Shared across both modes — warm terracotta/orange (Claude's own accent
  // color), swapped in from the original green per the user's request.
  static const primaryLight = Color(0xFFCC5F3B);
  static const primaryDark = Color(0xFFE8875F);
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
