import 'dart:async';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/settings/domain/app_settings.dart';
import 'package:google_fonts/google_fonts.dart';

// The weights the app's text styles ask for (Material's 400/500 plus the
// explicit 600/700 in widgets).
const _usedWeights = [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The offline (local) build has no network permission, so every font the
  // app can request must resolve from bundled assets. With runtime fetching
  // off, a missing family/weight is reported instead of silently downloaded.
  test('every selectable font and used weight is bundled', () async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final logs = <String>[];

    await runZoned(
      () async {
        for (final font in AppFontOption.values) {
          GoogleFonts.getTextTheme(font.fontFamily);
          for (final w in _usedWeights) {
            GoogleFonts.getFont(font.fontFamily, fontWeight: w);
          }
        }
        for (final w in _usedWeights) {
          GoogleFonts.getFont(AppTheme.headingFontFamily, fontWeight: w);
        }
        await GoogleFonts.pendingFonts();
      },
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)),
    );

    expect(logs.where((l) => l.contains('unable to load font')), isEmpty, reason: logs.join('\n'));
  });
}
