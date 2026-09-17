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

  /// Warm near-black used as text/icon color on every accent's dark-mode
  /// variant below. Each dark variant is deliberately a light/pastel tint of
  /// its hue (not hue-tuned individually) specifically so one shared near-black
  /// reads clearly on all of them, rather than needing a bespoke onPrimary per color.
  static const onAccentDark = Color(0xFF20201D);

  /// Curated accent (primary) color choices — each pair is a saturated tone
  /// for light mode (legible with white text) and a soft pastel tone for
  /// dark mode (legible with [onAccentDark]). See AccentColorOption in
  /// features/settings/domain/app_settings.dart for the picker enum.
  static const accentTerracottaLight = primaryLight;
  static const accentTerracottaDark = primaryDark;
  static const accentBlueLight = Color(0xFF2563EB);
  static const accentBlueDark = Color(0xFF93C5FD);
  static const accentGreenLight = Color(0xFF15803D);
  static const accentGreenDark = Color(0xFF86EFAC);
  static const accentPurpleLight = Color(0xFF7C3AED);
  static const accentPurpleDark = Color(0xFFC4B5FD);
  static const accentPinkLight = Color(0xFFDB2777);
  static const accentPinkDark = Color(0xFFF9A8D4);
  static const accentTealLight = Color(0xFF0F766E);
  static const accentTealDark = Color(0xFF5EEAD4);
  // Was an amber/brown tone (#B45309) that read as "brown" in light mode —
  // too close to the default terracotta accent, which is also a brown-
  // adjacent hue. Shifted to a true yellow hue (not just a lighter amber) in
  // both modes so it reads as a genuinely distinct color choice.
  static const accentGoldLight = Color(0xFFCA8A04);
  static const accentGoldDark = Color(0xFFFDE047);

  /// "No color" option for anyone who doesn't want a color accent at all —
  /// renders the Home tile (and every other primary-colored element) in
  /// shades of grey instead. Warm-toned greys, not neutral cool grays, to
  /// stay consistent with the rest of the app's warm palette.
  static const accentMonochromeLight = Color(0xFF44403C);
  static const accentMonochromeDark = Color(0xFFD6D3D1);

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
