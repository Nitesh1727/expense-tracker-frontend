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
enum AppFontOption {
  inter,
  manrope,
  poppins,
  nunito;

  String get fontFamily => switch (this) {
        AppFontOption.inter => 'Inter',
        AppFontOption.manrope => 'Manrope',
        AppFontOption.poppins => 'Poppins',
        AppFontOption.nunito => 'Nunito',
      };
}

class AppSettings {
  final TextSizeOption textSize;
  final AppFontOption font;

  const AppSettings({required this.textSize, required this.font});

  static const defaults = AppSettings(textSize: TextSizeOption.normal, font: AppFontOption.inter);

  AppSettings copyWith({TextSizeOption? textSize, AppFontOption? font}) =>
      AppSettings(textSize: textSize ?? this.textSize, font: font ?? this.font);
}
