import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/local/local_database.dart';
import 'package:frontend/features/categories/data/local_category_api.dart';
import 'package:frontend/features/expenses/data/local_expense_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  // File-based (not in-memory) so VACUUM INTO and the raw file copy in
  // restoreFromFile are exercising real file I/O, the same as on a phone.
  late Directory tmp;
  late LocalDatabase local;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('spendwise-backup-test');
    local = LocalDatabase.withOpener(
      () => databaseFactoryFfi.openDatabase(
        '${tmp.path}/main.db',
        options: OpenDatabaseOptions(version: 1, singleInstance: false, onCreate: LocalDatabase.createSchema),
      ),
      openReadOnly: (path) => databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(readOnly: true)),
    );
  });

  tearDown(() async {
    await local.close();
    await tmp.delete(recursive: true);
  });

  test('export then restore round-trips every expense and category', () async {
    final expenses = LocalExpenseApi(local);
    final categories = LocalCategoryApi(local);
    final food = (await categories.list()).firstWhere((c) => c.name == 'Food').id;
    await categories.create(name: 'Side hustle', icon: 'home', color: '#22C55E');
    await expenses.create(amount: 12.5, description: 'Coffee', categoryId: food);
    await expenses.create(amount: 980, description: 'Rent share', categoryId: food);

    final backupPath = '${tmp.path}/backup.db';
    await local.exportSnapshotTo(backupPath);
    expect(await File(backupPath).exists(), isTrue);

    // Wipe the live database so the restore below can't accidentally pass
    // just because the old data was still sitting there.
    await local.eraseAll();
    final reseededFood = (await categories.list()).firstWhere((c) => c.name == 'Food').id;
    await expenses.create(amount: 1, description: 'should disappear', categoryId: reseededFood);

    await local.restoreFromFile(backupPath);

    final restoredCategories = await categories.list();
    expect(restoredCategories.map((c) => c.name), containsAll(['Food', 'Side hustle']));
    final restoredExpenses = await expenses.list(limit: 50);
    expect(restoredExpenses.total, 2);
    expect(restoredExpenses.items.map((e) => e.description), containsAll(['Coffee', 'Rent share']));
    expect(restoredExpenses.items.any((e) => e.description == 'should disappear'), isFalse);
  });

  test('restoring a file that is not a SpendWise backup leaves existing data untouched', () async {
    final expenses = LocalExpenseApi(local);
    final categories = LocalCategoryApi(local);
    final food = (await categories.list()).firstWhere((c) => c.name == 'Food').id;
    await expenses.create(amount: 42, description: 'Still here', categoryId: food);

    final notABackup = File('${tmp.path}/not-a-backup.db');
    await notABackup.writeAsBytes([1, 2, 3, 4]);

    await expectLater(local.restoreFromFile(notABackup.path), throwsA(isA<FormatException>()));

    final after = await expenses.list();
    expect(after.items.single.description, 'Still here');
  });

  test('backup file is a valid, independent SQLite database (not a lock on the live one)', () async {
    final expenses = LocalExpenseApi(local);
    final categories = LocalCategoryApi(local);
    final food = (await categories.list()).firstWhere((c) => c.name == 'Food').id;
    await expenses.create(amount: 5, description: 'x', categoryId: food);

    final backupPath = '${tmp.path}/backup2.db';
    await local.exportSnapshotTo(backupPath);

    final opened = await databaseFactoryFfi.openDatabase(backupPath, options: OpenDatabaseOptions(readOnly: true));
    final rows = await opened.query('expenses');
    expect(rows, hasLength(1));
    await opened.close();

    // The live database is still perfectly usable afterward.
    expect((await expenses.list()).total, 1);
  });
}
