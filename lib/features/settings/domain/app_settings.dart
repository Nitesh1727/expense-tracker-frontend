import 'package:flutter/material.dart' show Color, ThemeMode;
import '../../../core/theme/app_colors.dart';

enum TextSizeOption {
  small,
  normal,
  large;

  double get scale => switch (this) {
        TextSizeOption.small => 0.9,
        TextSizeOption.normal => 1.0,
        TextSizeOption.large => 1.15,
      };

  String get label => switch (this) {
        TextSizeOption.small => 'Small',
        TextSizeOption.normal => 'Normal',
        TextSizeOption.large => 'Large',
      };
}

/// A curated set, not a free-form font picker — keeps every choice legible
/// and on-brand rather than letting the app end up looking like a ransom
/// note. All available via google_fonts at the exact family name below.
/// Widened beyond the original 4 with fonts several well-known consumer
/// apps use for their body/UI text (DM Sans, Plus Jakarta Sans, Work Sans,
/// Outfit) per explicit user request for "the best fonts some of the best
/// apps use".
enum AppFontOption {
  inter,
  manrope,
  poppins,
  nunito,
  dmSans,
  plusJakartaSans,
  workSans,
  outfit;

  String get fontFamily => switch (this) {
        AppFontOption.inter => 'Inter',
        AppFontOption.manrope => 'Manrope',
        AppFontOption.poppins => 'Poppins',
        AppFontOption.nunito => 'Nunito',
        AppFontOption.dmSans => 'DM Sans',
        AppFontOption.plusJakartaSans => 'Plus Jakarta Sans',
        AppFontOption.workSans => 'Work Sans',
        AppFontOption.outfit => 'Outfit',
      };
}

/// Curated accent (primary) color choices — a picker of hues rather than a
/// free color wheel, same reasoning as [AppFontOption]: every option is
/// pre-checked to stay legible (a saturated tone in light mode against white
/// text, a soft pastel tone in dark mode against [AppColors.onAccentDark])
/// rather than letting a user pick something that washes out the UI.
enum AccentColorOption {
  terracotta,
  blue,
  green,
  purple,
  pink,
  teal,
  gold,
  monochrome;

  Color get light => switch (this) {
        AccentColorOption.terracotta => AppColors.accentTerracottaLight,
        AccentColorOption.blue => AppColors.accentBlueLight,
        AccentColorOption.green => AppColors.accentGreenLight,
        AccentColorOption.purple => AppColors.accentPurpleLight,
        AccentColorOption.pink => AppColors.accentPinkLight,
        AccentColorOption.teal => AppColors.accentTealLight,
        AccentColorOption.gold => AppColors.accentGoldLight,
        AccentColorOption.monochrome => AppColors.accentMonochromeLight,
      };

  Color get dark => switch (this) {
        AccentColorOption.terracotta => AppColors.accentTerracottaDark,
        AccentColorOption.blue => AppColors.accentBlueDark,
        AccentColorOption.green => AppColors.accentGreenDark,
        AccentColorOption.purple => AppColors.accentPurpleDark,
        AccentColorOption.pink => AppColors.accentPinkDark,
        AccentColorOption.teal => AppColors.accentTealDark,
        AccentColorOption.gold => AppColors.accentGoldDark,
        AccentColorOption.monochrome => AppColors.accentMonochromeDark,
      };

  String get label => switch (this) {
        AccentColorOption.terracotta => 'Terracotta',
        AccentColorOption.blue => 'Blue',
        AccentColorOption.green => 'Green',
        AccentColorOption.purple => 'Purple',
        AccentColorOption.pink => 'Pink',
        AccentColorOption.teal => 'Teal',
        AccentColorOption.gold => 'Gold',
        AccentColorOption.monochrome => 'Black & white',
      };
}

/// Flutter's own ThemeMode (system/light/dark) — reused directly rather
/// than wrapping it in a parallel enum, since that's exactly what
/// MaterialApp.themeMode already expects.
extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
        ThemeMode.system => 'Match system',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}

class AppSettings {
  final TextSizeOption textSize;
  final AppFontOption font;
  final ThemeMode themeMode;
  final AccentColorOption accentColor;

  const AppSettings({
    required this.textSize,
    required this.font,
    required this.themeMode,
    required this.accentColor,
  });

  static const defaults = AppSettings(
    textSize: TextSizeOption.normal,
    font: AppFontOption.inter,
    themeMode: ThemeMode.system,
    accentColor: AccentColorOption.terracotta,
  );

  AppSettings copyWith({
    TextSizeOption? textSize,
    AppFontOption? font,
    ThemeMode? themeMode,
    AccentColorOption? accentColor,
  }) =>
      AppSettings(
        textSize: textSize ?? this.textSize,
        font: font ?? this.font,
        themeMode: themeMode ?? this.themeMode,
        accentColor: accentColor ?? this.accentColor,
      );
}
