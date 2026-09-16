import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';

const _textSizeKey = 'settings.textSize';
const _fontKey = 'settings.font';

/// Persisted locally (per-device) via SharedPreferences — this is a display
/// preference, not account data, so it deliberately doesn't sync through the
/// backend/PATCH /auth/me.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return AppSettings.defaults;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final textSizeName = prefs.getString(_textSizeKey);
    final fontName = prefs.getString(_fontKey);

    state = AppSettings(
      textSize: TextSizeOption.values.firstWhere((e) => e.name == textSizeName, orElse: () => TextSizeOption.normal),
      font: AppFontOption.values.firstWhere((e) => e.name == fontName, orElse: () => AppFontOption.inter),
    );
  }

  Future<void> setTextSize(TextSizeOption value) async {
    state = state.copyWith(textSize: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_textSizeKey, value.name);
  }

  Future<void> setFont(AppFontOption value) async {
    state = state.copyWith(font: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, value.name);
  }
}

final settingsControllerProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
