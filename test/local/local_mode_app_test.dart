// Boots the whole app in local mode. Compile-time mode, so this only runs as:
//   flutter test --dart-define=DATA_MODE=local test/local/local_mode_app_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/local/local_database.dart';
import 'package:frontend/core/providers/core_providers.dart';
import 'package:frontend/core/widgets/root_shell.dart';
import 'package:frontend/features/auth/presentation/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('local mode opens straight into the app: no welcome/login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = LocalDatabase.withOpener(() => databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, singleInstance: false, onCreate: LocalDatabase.createSchema),
        ));

    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [localDatabaseProvider.overrideWithValue(db)],
        child: const ExpenseTrackerApp(),
      ));
      // Real async work (SQLite, prefs) happens off the fake clock.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(RootShell), findsOneWidget);
  }, skip: !AppConfig.isLocal);
}
