import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Text style tokens, built on Inter — clean, highly legible, and close in
/// spirit to the system font on iOS, which fits the "smooth Apple-app" feel
/// this UI is going for. Swapping the whole app's typeface later is a
/// one-line change here (see frontend/docs/DESIGN_SYSTEM.md).
class AppTypography {
  AppTypography._();

  static TextStyle _base({required double size, required FontWeight weight, required Color color}) {
    return GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: 1.3);
  }

  static TextStyle displayLarge(Color color) => _base(size: 32, weight: FontWeight.w700, color: color);
  static TextStyle headline(Color color) => _base(size: 22, weight: FontWeight.w600, color: color);
  static TextStyle title(Color color) => _base(size: 17, weight: FontWeight.w600, color: color);
  static TextStyle body(Color color) => _base(size: 15, weight: FontWeight.w400, color: color);
  static TextStyle bodyStrong(Color color) => _base(size: 15, weight: FontWeight.w600, color: color);
  static TextStyle caption(Color color) => _base(size: 13, weight: FontWeight.w400, color: color);
}
