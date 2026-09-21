import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/local/local_database.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/analytics/data/local_analytics_api.dart';
import 'package:frontend/features/categories/data/local_category_api.dart';
import 'package:frontend/features/expenses/data/local_expense_api.dart';
import 'package:frontend/features/export/data/local_export_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime utc(String s) => DateTime.parse(s);

Future<void> expectApiError(Future<Object?> f, int status, [String? message]) async {
  try {
    await f;
  } on ApiException catch (e) {
    expect(e.statusCode, status);
    if (message != null) expect(e.message, message);
    return;
  }
  fail('expected ApiException($status)');
}

void main() {
  sqfliteFfiInit();
  late LocalDatabase local;
  late LocalExpenseApi expenses;
  late LocalCategoryApi categories;
  late LocalAnalyticsApi analytics;
  late String food, other;

  setUp(() async {
    local = LocalDatabase.withOpener(() => databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, singleInstance: false, onCreate: LocalDatabase.createSchema),
        ));
    expenses = LocalExpenseApi(local);
    categories = LocalCategoryApi(local);
    analytics = LocalAnalyticsApi(local);
    final all = await categories.list();
    food = all.firstWhere((c) => c.name == 'Food').id;
    other = all.firstWhere((c) => c.name == 'Other').id;
  });

  group('categories', () {
    test('seeded on first run in the backend order, Other not deletable', () async {
      final all = await categories.list();
      expect(all.map((c) => c.name), ['Food', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Other']);
      expect(all.where((c) => !c.isDeletable).map((c) => c.name), ['Other']);
    });

    test('name unique case-insensitively, incl. on rename', () async {
      await expectApiError(categories.create(name: 'food', icon: 'home', color: '#22C55E'), 409, 'Already exists');
      final c = await categories.create(name: 'Gym', icon: 'fitness_center', color: '#22C55E');
      await expectApiError(categories.update(c.id, name: 'FOOD'), 409, 'Already exists');
    });

    test('name trimmed, 1-30 chars; icon/colour must be curated', () async {
      expect((await categories.create(name: '  Pets  ', icon: 'pets', color: '#22C55E')).name, 'Pets');
      await expectApiError(categories.create(name: '   ', icon: 'pets', color: '#22C55E'), 400);
      await expectApiError(categories.create(name: 'x' * 31, icon: 'pets', color: '#22C55E'), 400);
      await expectApiError(categories.create(name: 'A', icon: 'nope', color: '#22C55E'), 400);
      await expectApiError(categories.create(name: 'B', icon: 'pets', color: '#000000'), 400);
    });

    test('deleting reassigns expenses to Other; Other cannot be deleted', () async {
      final e = await expenses.create(amount: 10, description: 'lunch', categoryId: food);
      await categories.delete(food);
      final after = await expenses.list();
      expect(after.items.single.id, e.id);
      expect(after.items.single.category.id, other);
      await expectApiError(categories.delete(other), 400,
          '"Other" is required as a fallback category and cannot be deleted');
      await expectApiError(categories.delete('nope'), 404, 'Category not found');
    });
  });

  group('expenses', () {
    test('validation and error messages', () async {
      await expectApiError(expenses.create(amount: 0, description: 'a', categoryId: food), 400);
      await expectApiError(expenses.create(amount: -1, description: 'a', categoryId: food), 400);
      await expectApiError(expenses.create(amount: 1, description: '', categoryId: food), 400);
      await expectApiError(expenses.create(amount: 1, description: 'x' * 31, categoryId: food), 400);
      await expectApiError(expenses.create(amount: 1, description: 'a', categoryId: 'missing'), 400, 'Category not found');
      await expectApiError(expenses.update('missing', amount: 5), 404, 'Expense not found');
      await expectApiError(expenses.delete('missing'), 404, 'Expense not found');
    });

    test('decimals are exact and totals add up', () async {
      await expenses.create(amount: 0.1, description: 'a', categoryId: food);
      await expenses.create(amount: 0.2, description: 'b', categoryId: food);
      await expenses.create(amount: 199.99, description: 'c', categoryId: food);
      final r = await expenses.list();
      expect(r.totalAmount, closeTo(200.29, 1e-9));
      expect((await expenses.list(q: '199.99')).items.single.description, 'c');
      expect((await expenses.list(q: '0.1')).items.single.description, 'a');
    });

    test('update patches only what is sent; date defaults to now', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 2));
      final e = await expenses.create(amount: 5, description: 'Tea', categoryId: food);
      expect(e.date.isAfter(before), isTrue);
      final u = await expenses.update(e.id, amount: 7.5, description: 'Chai');
      expect((u.amount, u.description, u.category.id, u.date), (7.5, 'Chai', food, e.date));
      expect((await expenses.list(q: 'chai')).total, 1);
      expect((await expenses.list(q: 'tea')).total, 0);
    });

    test('search: case-insensitive substring, wildcards literal, exact amount not substring', () async {
      await expenses.create(amount: 500, description: 'Coffee (2)', categoryId: food);
      await expenses.create(amount: 1500, description: '100% juice', categoryId: food);
      await expenses.create(amount: 50, description: 'Café au lait', categoryId: food);
      expect((await expenses.list(q: 'COFFEE')).total, 1);
      expect((await expenses.list(q: '(2)')).total, 1);
      expect((await expenses.list(q: '%')).total, 1);
      expect((await expenses.list(q: '_')).total, 0);
      expect((await expenses.list(q: 'CAFÉ')).total, 1);
      expect((await expenses.list(q: '500')).items.single.amount, 500); // not 1500
    });

    test('from inclusive, to exclusive', () async {
      final t = utc('2026-05-10T10:00:00Z');
      await expenses.create(amount: 1, description: 'x', categoryId: food, date: t);
      expect((await expenses.list(from: t)).total, 1);
      expect((await expenses.list(to: t)).total, 0);
      expect((await expenses.list(to: t.add(const Duration(milliseconds: 1)))).total, 1);
    });

    test('categoryIds beats categoryId', () async {
      await expenses.create(amount: 1, description: 'x', categoryId: food);
      await expenses.create(amount: 2, description: 'y', categoryId: other);
      final r = await expenses.list(categoryId: food, categoryIds: [other]);
      expect(r.items.single.amount, 2);
    });

    test('pagination: totals span all pages; newest first', () async {
      for (var i = 1; i <= 25; i++) {
        await expenses.create(amount: i.toDouble(), description: 'e$i', categoryId: food, date: utc('2026-05-01T00:00:00Z').add(Duration(hours: i)));
      }
      final p2 = await expenses.list(page: 2, limit: 10);
      expect((p2.total, p2.totalAmount, p2.items.length, p2.hasMore), (25, 325.0, 10, true));
      expect(p2.items.first.description, 'e15');
      expect((await expenses.list(page: 3, limit: 10)).hasMore, isFalse);
    });

    test('daily summary buckets by IST day: 23:30 vs 00:15 IST', () async {
      // 18:00Z = 23:30 IST on Mar 1; 18:45Z = 00:15 IST on Mar 2.
      await expenses.create(amount: 10, description: 'late', categoryId: food, date: utc('2026-03-01T18:00:00Z'));
      await expenses.create(amount: 20, description: 'early', categoryId: food, date: utc('2026-03-01T18:45:00Z'));
      final d = await expenses.dailySummary();
      expect(d.days.map((x) => (x.total, x.count)), [(20.0, 1), (10.0, 1)]);
      // Each day's bucket instant is that IST midnight (Mar 2 00:00 IST = Mar 1 18:30Z).
      expect(d.days[0].date.toUtc(), utc('2026-03-01T18:30:00Z'));
      expect(d.days[1].date.toUtc(), utc('2026-02-28T18:30:00Z'));
    });

    test('daily summary paginates by days, total over all days', () async {
      for (var i = 0; i < 5; i++) {
        for (var j = 0; j < 3; j++) {
          await expenses.create(amount: 1, description: 'x', categoryId: food, date: utc('2026-05-0${i + 1}T06:0$j:00Z'));
        }
      }
      final p1 = await expenses.dailySummary(page: 1, limit: 2);
      expect((p1.days.length, p1.hasMore, p1.totalAmount), (2, true, 15.0));
      expect(p1.days.every((d) => d.count == 3), isTrue);
      expect((await expenses.dailySummary(page: 3, limit: 2)).hasMore, isFalse);
    });
  });

  group('analytics ranges (IST)', () {
    test('week starts Monday IST; Sunday night vs Monday 00:15', () async {
      // Sun 20 Sep 2026 23:30 IST -> week of Mon 14 Sep.
      final sun = await analytics.summary('week', anchor: utc('2026-09-20T18:00:00Z'));
      expect(sun.range.start.toUtc(), utc('2026-09-13T18:30:00Z')); // Mon 14 Sep 00:00 IST
      expect(sun.range.end.toUtc(), utc('2026-09-20T18:30:00Z'));
      // Mon 21 Sep 00:15 IST -> new week.
      final mon = await analytics.summary('week', anchor: utc('2026-09-20T18:45:00Z'));
      expect(mon.range.start.toUtc(), utc('2026-09-20T18:30:00Z'));
    });

    test('month/year edges', () async {
      final feb = await analytics.summary('month', anchor: utc('2028-02-29T12:00:00Z')); // leap year
      expect(feb.range.start.toUtc(), utc('2028-01-31T18:30:00Z'));
      expect(feb.range.end.toUtc(), utc('2028-02-29T18:30:00Z'));
      final dec = await analytics.summary('year', anchor: utc('2026-12-31T18:45:00Z')); // already Jan 1 IST
      expect(dec.range.start.toUtc(), utc('2026-12-31T18:30:00Z'));
      final day = await analytics.summary('day', anchor: utc('2026-12-31T18:29:59Z'));
      expect(day.range.start.toUtc(), utc('2026-12-30T18:30:00Z'));
    });

    test('summary: sorted by total desc, empty categories omitted; trend units', () async {
      await expenses.create(amount: 5, description: 'a', categoryId: food, date: utc('2026-09-15T06:00:00Z'));
      await expenses.create(amount: 50, description: 'b', categoryId: other, date: utc('2026-09-16T06:00:00Z'));
      final s = await analytics.summary('month', anchor: utc('2026-09-20T06:00:00Z'));
      expect(s.byCategory.map((c) => c.category.name), ['Other', 'Food']);
      expect(s.total, 55);
      final t = await analytics.trend('year', anchor: utc('2026-09-20T06:00:00Z'));
      expect((t.bucketUnit, t.series.length, t.series.single.total), ('month', 1, 55.0));
      expect((await analytics.trend('week', anchor: utc('2026-09-15T06:00:00Z'))).bucketUnit, 'day');
    });
  });

  group('export', () {
    test('workbook layout, styling, sheet name', () async {
      await expenses.create(amount: 100, description: 'Lunch', categoryId: food, date: utc('2026-09-15T20:00:00Z')); // 16 Sep 01:30 IST
      final bytes = await LocalExportApi(local).downloadXlsx(from: utc('2026-08-31T18:30:00Z'), to: utc('2026-09-30T18:30:00Z'), label: 'September 2026');
      final x = Excel.decodeBytes(bytes);
      expect(x.tables.keys.single, 'September 2026');
      final s = x.tables.values.single;
      expect(s.cell(CellIndex.indexByString('A1')).value.toString(), 'Expenses — September 2026');
      expect(s.cell(CellIndex.indexByString('A3')).cellStyle?.backgroundColor.colorHex, 'FFCC5F3B');
      expect(s.cell(CellIndex.indexByString('A4')).value.toString(), '2026-09-16'); // IST date, not UTC's 15th
      expect(s.cell(CellIndex.indexByString('D4')).cellStyle?.numberFormat.formatCode, '"₹"#,##0.00');
      expect(s.cell(CellIndex.indexByString('A6')).value.toString(), 'Total');
    });
  });

  test('fast at 50k rows: filtered list+totals, search, daily summary, summary', () async {
    final db = await local.instance;
    final batch = db.batch();
    final base = utc('2022-01-01T00:00:00Z').millisecondsSinceEpoch;
    for (var i = 0; i < 50000; i++) {
      batch.insert('expenses', {
        'id': 'id$i',
        'amount': (i % 900) + 0.5,
        'description': 'item ${i % 50}',
        'description_lc': 'item ${i % 50}',
        'category_id': i.isEven ? food : other,
        'date': base + i * 1800000,
      });
    }
    await batch.commit(noResult: true);

    Future<int> ms(Future<void> Function() f) async {
      final sw = Stopwatch()..start();
      await f();
      return sw.elapsedMilliseconds;
    }

    final timings = {
      'list+total': await ms(() => expenses.list(categoryIds: [food], page: 3)),
      'search': await ms(() => expenses.list(q: 'item 7')),
      'amount search': await ms(() => expenses.list(q: '450.5')),
      'daily': await ms(() => expenses.dailySummary()),
      'summary': await ms(() => analytics.summary('year', anchor: utc('2023-06-01T00:00:00Z'))),
    };
    // ignore: avoid_print
    print('50k-row timings (ms, desktop sqlite): $timings');
    for (final e in timings.entries) {
      expect(e.value, lessThan(500), reason: e.key);
    }
  });
}
