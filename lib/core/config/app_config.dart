import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Points at the local backend during development. `10.0.2.2` is the
/// Android emulator's alias for the host machine's `localhost` — a physical
/// device or iOS simulator uses `localhost` directly. Swap this for a real
/// deployed URL before any release build; consider promoting this to a
/// build-time `--dart-define` once a staging/prod backend exists so it's
/// not a hand-edit per build.
class AppConfig {
  AppConfig._();

  static String get apiBaseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:4000/api';
    }
    return 'http://localhost:4000/api';
  }
}
