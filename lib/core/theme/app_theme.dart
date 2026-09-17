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

  /// The serif used for screen/section headings (AppBar titles, "Track your
  /// spending", sheet titles, etc.) — matches the Claude app's own heading
  /// treatment (a serif set against an otherwise sans-serif UI) per explicit
  /// user request. Deliberately not user-configurable like [AppFontOption]:
  /// the ask was "by default make headings look like Claude's", not a
  /// pickable option, so this stays fixed while the body font stays curated
  /// and user-selectable in Settings.
  static const headingFontFamily = 'Source Serif 4';

  /// Applies the heading serif to an existing text style while keeping its
  /// size/height/color — exposed publicly so a one-off large heading that
  /// intentionally uses a bigger token (e.g. the splash screen's app name on
  /// `displayLarge`, which this theme otherwise reserves for numbers so they
  /// stay in the legible sans body font) can still opt into the serif.
  static TextStyle? headingStyle(TextStyle? base, {FontWeight weight = FontWeight.w600}) =>
      base == null ? null : GoogleFonts.getFont(headingFontFamily, textStyle: base, fontWeight: weight);

  // `primary` is a plain Color, not the settings feature's AccentColorOption
  // enum — core/theme shouldn't depend on a feature. app.dart resolves the
  // user's selected AccentColorOption to a Color before calling these.
  static ThemeData light({String fontFamily = 'Inter', Color? primary}) => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        border: AppColors.lightBorder,
        primary: primary ?? AppColors.primaryLight,
        onPrimary: Colors.white,
        error: AppColors.error,
        fontFamily: fontFamily,
      );

  static ThemeData dark({String fontFamily = 'Inter', Color? primary}) => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        border: AppColors.darkBorder,
        primary: primary ?? AppColors.primaryDark,
        // A shared warm near-black works across every accent's dark-mode
        // variant since each is deliberately a light pastel tint — see
        // AppColors.onAccentDark.
        onPrimary: AppColors.onAccentDark,
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
    var textTheme = GoogleFonts.getTextTheme(
      fontFamily,
      brightness == Brightness.light ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    ).apply(bodyColor: textPrimary, displayColor: textPrimary);

    // Screen/section headings (AppBar titles, "Track your spending", sheet
    // titles) use the Claude-style serif; body text, buttons, and numbers
    // (displayLarge, titleLarge/Medium) stay in the user-selected sans font.
    // Deliberately not headlineSmall's actual use in the OTP code entry field
    // or headlineMedium's use in the amount input — those two call sites
    // explicitly opt back out to a sans style at the widget level.
    textTheme = textTheme.copyWith(
      headlineLarge: headingStyle(textTheme.headlineLarge),
      headlineMedium: headingStyle(textTheme.headlineMedium),
      headlineSmall: headingStyle(textTheme.headlineSmall),
    );

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
        // Fixed at 21.06 (= the confirmed-correct 23.4 base * the Small
        // setting's 0.9 multiplier) — this is the exact size the user
        // confirmed against a screenshot. Screen-title headings are now
        // deliberately locked to this size regardless of the text-size
        // setting (see AppBarTitle, which opts out of the ambient text
        // scaler) per explicit request: every other piece of text still
        // scales with Small/Normal/Large as before, only this heading size
        // stays constant. This only touches the AppBar's titleTextStyle, not
        // headlineSmall itself, so other headlineSmall usage (e.g. the
        // profile avatar's initial letter) is unaffected.
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 21.06, color: textPrimary),
      ),
      // Flat, bordered surfaces rather than drop-shadowed "premium" tiles —
      // matches the calm, minimal card treatment of the Claude app (a hairline
      // border and a barely-there shadow read as considered, not decorated).
      // Material3's default surfaceTint (a wash of primary color at higher
      // elevations) is turned off so cards stay a clean, unmuddied surface color.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 1,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
