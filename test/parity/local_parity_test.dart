// Loads the cloud account's dataset (captured by tool/capture_parity_fixture.dart)
// into SQLite and checks the local implementation returns what the cloud
// backend returned for the same query.
import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/local/local_database.dart';
import 'package:frontend/features/analytics/data/local_analytics_api.dart';
import 'package:frontend/features/analytics/domain/analytics_summary.dart';
import 'package:frontend/features/expenses/data/local_expense_api.dart';
import 'package:frontend/features/expenses/domain/expense.dart';
import 'package:frontend/features/export/data/local_export_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _eps = 1e-6;

DateTime? _d(String? s) => s == null ? null : DateTime.parse(s);
List<String>? _ids(String? s) => s?.split(',');

void main() {
  sqfliteFfiInit();
  final fixture = jsonDecode(File('test/parity/fixtures.json').readAsStringSync()) as Map<String, dynamic>;
  late LocalDatabase local;

  setUpAll(() async {
    local = LocalDatabase.withOpener(() => databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, onCreate: LocalDatabase.createSchema),
        ));
    final db = await local.instance;
    // Replace the seeded categories with the cloud account's own (same ids,
    // same order) so results can be compared id-for-id.
    await db.delete('categories');
    for (final c in fixture['categories'] as List) {
      await db.insert('categories', {
        'id': c['_id'],
        'name': c['name'],
        'name_key': (c['name'] as String).toLowerCase(),
        'icon': c['icon'],
        'color': c['color'],
        'is_deletable': (c['isDeletable'] as bool) ? 1 : 0,
      });
    }
    final batch = db.batch();
    for (final e in fixture['expenses'] as List) {
      batch.insert('expenses', {
        'id': e['_id'],
        'amount': (e['amount'] as num).toDouble(),
        'description': e['description'],
        'description_lc': (e['description'] as String).toLowerCase(),
        'category_id': e['category']['_id'],
        'date': DateTime.parse(e['date']).millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
  });

  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  for (final c in cases) {
    final q = (c['query'] as Map).cast<String, String>();
    final expected = c['expected'] as Map<String, dynamic>;

    test('${c['op']}: ${c['name']}', () async {
      switch (c['op']) {
        case 'list':
          final got = await LocalExpenseApi(local).list(
            from: _d(q['from']),
            to: _d(q['to']),
            categoryId: q['categoryId'],
            categoryIds: _ids(q['categoryIds']),
            q: q['q'],
            page: int.tryParse(q['page'] ?? '') ?? 1,
            limit: int.tryParse(q['limit'] ?? '') ?? 20,
          );
          final want = (expected['items'] as List).map((j) => Expense.fromJson(j)).toList();
          expect(got.total, expected['total'], reason: 'total');
          expect(got.totalAmount, closeTo((expected['totalAmount'] as num).toDouble(), _eps), reason: 'totalAmount');
          expect(got.items.length, want.length, reason: 'page size');
          for (var i = 0; i < want.length; i++) {
            expect(got.items[i].id, want[i].id, reason: 'item $i id');
            expect(got.items[i].date.millisecondsSinceEpoch, want[i].date.millisecondsSinceEpoch);
            expect(got.items[i].amount, want[i].amount);
            expect(got.items[i].description, want[i].description);
            expect(got.items[i].category.id, want[i].category.id);
            expect(got.items[i].category.name, want[i].category.name);
          }
        case 'daily':
          final got = await LocalExpenseApi(local).dailySummary(
            from: _d(q['from']),
            to: _d(q['to']),
            categoryIds: _ids(q['categoryIds']) ?? (q['categoryId'] == null ? null : [q['categoryId']!]),
            page: int.tryParse(q['page'] ?? '') ?? 1,
            limit: int.tryParse(q['limit'] ?? '') ?? 15,
          );
          final want = expected['days'] as List;
          expect(got.hasMore, expected['hasMore'], reason: 'hasMore');
          expect(got.totalAmount, closeTo((expected['totalAmount'] as num).toDouble(), _eps), reason: 'totalAmount');
          expect(got.days.length, want.length);
          for (var i = 0; i < want.length; i++) {
            expect(got.days[i].date.millisecondsSinceEpoch, DateTime.parse(want[i]['date']).millisecondsSinceEpoch, reason: 'day $i');
            expect(got.days[i].total, closeTo((want[i]['total'] as num).toDouble(), _eps));
            expect(got.days[i].count, want[i]['count']);
          }
        case 'summary':
          final got = await LocalAnalyticsApi(local).summary(q['period']!, anchor: _d(q['anchor']));
          final want = AnalyticsSummary.fromJson(expected);
          expect(got.range.start.millisecondsSinceEpoch, want.range.start.millisecondsSinceEpoch, reason: 'range.start');
          expect(got.range.end.millisecondsSinceEpoch, want.range.end.millisecondsSinceEpoch, reason: 'range.end');
          expect(got.total, closeTo(want.total, _eps));
          expect(got.byCategory.length, want.byCategory.length);
          for (var i = 0; i < want.byCategory.length; i++) {
            expect(got.byCategory[i].category.id, want.byCategory[i].category.id);
            expect(got.byCategory[i].total, closeTo(want.byCategory[i].total, _eps));
            expect(got.byCategory[i].count, want.byCategory[i].count);
          }
        case 'trend':
          final got = await LocalAnalyticsApi(local).trend(q['period']!, anchor: _d(q['anchor']));
          final want = AnalyticsTrend.fromJson(expected);
          expect(got.bucketUnit, want.bucketUnit);
          expect(got.series.length, want.series.length);
          for (var i = 0; i < want.series.length; i++) {
            expect(got.series[i].bucket.millisecondsSinceEpoch, want.series[i].bucket.millisecondsSinceEpoch, reason: 'bucket $i');
            expect(got.series[i].total, closeTo(want.series[i].total, _eps));
          }
      }
    });
  }

  for (final ex in (fixture['exports'] as List).cast<Map<String, dynamic>>()) {
    final q = (ex['query'] as Map).cast<String, String>();
    test('export xlsx: ${q['label']}', () async {
      final cloud = Excel.decodeBytes(base64Decode(ex['xlsxBase64']));
      final mine = Excel.decodeBytes(
          await LocalExportApi(local).downloadXlsx(from: _d(q['from']), to: _d(q['to']), label: q['label']));

      expect(mine.tables.keys.toList(), cloud.tables.keys.toList(), reason: 'sheet name');
      List<List<Object?>> grid(Excel x) => x.tables.values.first.rows
          .map((r) => r.map((c) => c?.value is DoubleCellValue ? (c!.value as DoubleCellValue).value : c?.value?.toString()).toList())
          .toList();
      // Expenses sharing an exact timestamp have no defined order in the cloud
      // (Mongo's sort isn't stable), so data rows are compared in a canonical
      // order; title, headers, total and the category breakdown stay strict.
      final isData = RegExp(r'^\d{4}-\d\d-\d\d$');
      List<List<Object?>> canonical(List<List<Object?>> g) {
        final data = g.where((r) => r.first is String && isData.hasMatch(r.first as String)).toList()
          ..sort((x, y) => x.join('|').compareTo(y.join('|')));
        var k = 0;
        return [for (final r in g) (r.first is String && isData.hasMatch(r.first as String)) ? data[k++] : r];
      }

      final a = canonical(grid(mine)), b = canonical(grid(cloud));
      expect(a.length, b.length, reason: 'row count');
      for (var i = 0; i < b.length; i++) {
        for (var j = 0; j < b[i].length; j++) {
          final x = a[i].length > j ? a[i][j] : null, y = b[i][j];
          if (x is double && y is double) {
            expect(x, closeTo(y, _eps), reason: 'cell r$i c$j');
          } else {
            expect(x, y, reason: 'cell r$i c$j');
          }
        }
      }
    });
  }
}
