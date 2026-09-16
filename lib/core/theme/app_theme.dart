import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Assembles the light/dark ThemeData from the design tokens. Screens should
/// read colors/text styles via `Theme.of(context)` rather than importing
/// AppColors/AppTypography directly wherever a Material role already covers
/// it — `colorScheme.onSurfaceVariant` doubles as our "textSecondary" token,
/// `colorScheme.surface` as card backgrounds, etc.
class AppTheme {
  AppTheme._();

  static ThemeData light({String fontFamily = 'Inter'}) => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        border: AppColors.lightBorder,
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        error: AppColors.error,
        fontFamily: fontFamily,
      );

  static ThemeData dark({String fontFamily = 'Inter'}) => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        border: AppColors.darkBorder,
        primary: AppColors.primaryDark,
        onPrimary: const Color(0xFF0B1F14),
        error: AppColors.errorDark,
        fontFamily: fontFamily,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
    required Color primary,
    required Color onPrimary,
    required Color error,
    required String fontFamily,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      error: error,
      onError: Colors.white,
      outline: border,
      outlineVariant: border,
    );

    // getTextTheme takes the font family as a runtime string (Settings screen
    // lets the user pick from a curated set — see features/settings) rather
    // than a hardcoded GoogleFonts.xTextTheme() call per font.
    final textTheme = GoogleFonts.getTextTheme(
      fontFamily,
      brightness == Brightness.light ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    ).apply(bodyColor: textPrimary, displayColor: textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: textPrimary),
      ),
      // Real elevation + a soft shadow, not a flat bordered rectangle — this
      // is most of what "premium tiles" comes down to visually. Material3's
      // default surfaceTint (a wash of primary color at higher elevations)
      // is turned off so cards stay a clean, unmuddied surface color instead.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 3,
        shadowColor: brightness == Brightness.light ? Colors.black.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.4),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.4),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
