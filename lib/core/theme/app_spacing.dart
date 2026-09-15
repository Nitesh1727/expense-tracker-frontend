/// 4px-base spacing scale — every margin/padding in the app should be one
/// of these, not an arbitrary number. "Spacious" comes from generous use
/// of lg/xl between sections, not one-off large values per screen.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radius scale.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double full = 999;
}
