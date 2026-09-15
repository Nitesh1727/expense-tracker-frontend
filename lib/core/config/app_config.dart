import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Points at the local backend during development. `10.0.2.2` is the
/// Android emulator's alias for the host machine's `localhost` — a physical
/// device or iOS simulator uses `localhost` directly, EXCEPT a physical
/// Android/iOS device can't reach the dev machine's `localhost` at all (it's
/// a different computer on the network) — it needs the dev machine's LAN IP
/// instead, passed via `--dart-define=API_BASE_URL=http://<lan-ip>:4000/api`
/// when running `flutter run` against a real device. Swap this for a real
/// deployed URL before any release build.
class AppConfig {
  AppConfig._();

  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:4000/api';
    }
    return 'http://localhost:4000/api';
  }
}
