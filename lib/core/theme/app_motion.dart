import 'package:flutter/animation.dart';

/// Motion tokens. Consistency here — not any one flashy animation — is
/// what actually reads as a smooth, premium app. See
/// frontend/docs/DESIGN_SYSTEM.md "Motion" for the usage rules.
class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 250);
  static const emphasized = Duration(milliseconds: 400);

  static const fastCurve = Curves.easeOut;
  static const standardCurve = Curves.easeInOut;
  static const emphasizedCurve = Curves.easeInOutCubic;
}
