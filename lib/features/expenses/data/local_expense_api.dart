import 'package:sqflite/sqflite.dart';
import '../../../core/local/ist.dart';
import '../../../core/local/local_database.dart';
import '../../../core/network/api_exception.dart';
import '../../categories/data/local_category_api.dart';
import '../domain/daily_summary.dart';
import '../domain/expense.dart';
import 'expense_api.dart';

const _selectExpense = '''
  SELECT e.id, e.amount, e.description, e.date,
         c.id AS c_id, c.name AS c_name, c.icon AS c_icon, c.color AS c_color, c.is_deletable AS c_is_deletable
  FROM expenses e JOIN categories c ON c.id = e.category_id
''';

Expense expenseFromRow(Map<String, Object?> r) => Expense(
      id: r['id'] as String,
      amount: (r['amount'] as num).toDouble(),
      description: r['description'] as String,
      category: categoryFromRow(r, prefix: 'c_'),
      date: DateTime.fromMillisecondsSinceEpoch(r['date'] as int),
    );

/// A WHERE clause plus its bound args, shared by list / daily summary /
/// export so all three filter identically (same as the backend's shared
/// filter shape).
class ExpenseFilter {
  final String where;
  final List<Object?> args;

  ExpenseFilter._(this.where, this.args);

  /// [from] inclusive, [to] exclusive. [categoryIds] wins over [categoryId].
  /// [q] is a case-insensitive description substring OR an exact amount.
  factory ExpenseFilter({
    DateTime? from,
    DateTime? to,
    String? categoryId,
    List<String>? categoryIds,
    String? q,
  }) {
    final clauses = <String>[];
    final args = <Object?>[];

    if (from != null) {
      clauses.add('e.date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      clauses.add('e.date < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (categoryIds != null && categoryIds.isNotEmpty) {
      clauses.add('e.category_id IN (${List.filled(categoryIds.length, '?').join(',')})');
      args.addAll(categoryIds);
    } else if (categoryId != null) {
      clauses.add('e.category_id = ?');
      args.add(categoryId);
    }

    final query = q?.trim();
    if (query != null && query.isNotEmpty) {
      final asNumber = double.tryParse(query);
      // instr() over a pre-lowercased column: substring match with no LIKE
      // wildcard escaping. The numeric branch is an exact match, not a
      // substring, same as the backend's search rule.
      if (asNumber != null && asNumber.isFinite) {
        clauses.add('(instr(e.description_lc, ?) > 0 OR e.amount = ?)');
        args..add(query.toLowerCase())..add(asNumber);
      } else {
        clauses.add('instr(e.description_lc, ?) > 0');
        args.add(query.toLowerCase());
      }
    }

    return ExpenseFilter._(clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}', args);
  }
}

/// SQLite implementation of [ExpenseApi]. Filtering, sorting, totals and
/// pagination all happen in SQL so it stays fast at tens of thousands of rows.
class LocalExpenseApi implements ExpenseApi {
  final LocalDatabase _local;

  LocalExpenseApi(this._local);

  @override
  Future<ExpenseListResult> list({
    DateTime? from,
    DateTime? to,
    String? categoryId,
    List<String>? categoryIds,
    String? q,
    int page = 1,
    int limit = 20,
  }) async {
    final db = await _local.instance;
    final f = ExpenseFilter(from: from, to: to, categoryId: categoryId, categoryIds: categoryIds, q: q);

    final items = await db.rawQuery(
      '$_selectExpense ${f.where} ORDER BY e.date DESC LIMIT ? OFFSET ?',
      [...f.args, limit, (page - 1) * limit],
    );
    // Count and sum over every match, not just this page.
    final agg = await db.rawQuery(
      'SELECT COUNT(*) AS n, COALESCE(SUM(e.amount), 0) AS s FROM expenses e ${f.where}',
      f.args,
    );

    return ExpenseListResult(
      items: items.map(expenseFromRow).toList(),
      page: page,
      limit: limit,
      total: agg.first['n'] as int,
      totalAmount: (agg.first['s'] as num).toDouble(),
    );
  }

  @override
  Future<DailySummaryResult> dailySummary({
    DateTime? from,
    DateTime? to,
    List<String>? categoryIds,
    int page = 1,
    int limit = 15,
  }) async {
    final db = await _local.instance;
    final f = ExpenseFilter(from: from, to: to, categoryIds: categoryIds);
    const bucket = '((e.date + ${Ist.offsetMs}) / ${Ist.dayMs})';
    final grouped = 'SELECT $bucket AS d, SUM(e.amount) AS total, COUNT(*) AS n FROM expenses e ${f.where} GROUP BY d';

    final rows = await db.rawQuery(
      '$grouped ORDER BY d DESC LIMIT ? OFFSET ?',
      [...f.args, limit, (page - 1) * limit],
    );
    // Sums the per-day totals (not raw rows) to match the backend's grand total.
    final agg = await db.rawQuery(
      'SELECT COUNT(*) AS days, COALESCE(SUM(total), 0) AS s FROM ($grouped)',
      f.args,
    );
    final totalDays = agg.first['days'] as int;

    return DailySummaryResult(
      days: rows
          .map((r) => DailySummary(
                date: Ist.instantOfDayIndex(r['d'] as int).toLocal(),
                total: (r['total'] as num).toDouble(),
                count: r['n'] as int,
              ))
          .toList(),
      page: page,
      limit: limit,
      hasMore: page * limit < totalDays,
      totalAmount: (agg.first['s'] as num).toDouble(),
    );
  }

  static void _checkAmount(double amount) {
    if (!(amount > 0) || !amount.isFinite) {
      throw ApiException('body.amount: Too small: expected number to be >0', statusCode: 400);
    }
  }

  static String _checkDescription(String description) {
    final d = description.trim();
    if (d.isEmpty || d.length > 30) {
      throw ApiException('body.description: Must be 1-30 characters', statusCode: 400);
    }
    return d;
  }

  static Future<void> _assertCategory(DatabaseExecutor db, String id) async {
    final rows = await db.query('categories', columns: ['id'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw ApiException('Category not found', statusCode: 400);
  }

  Future<Expense> _byId(DatabaseExecutor db, String id) async {
    final rows = await db.rawQuery('$_selectExpense WHERE e.id = ?', [id]);
    if (rows.isEmpty) throw ApiException('Expense not found', statusCode: 404);
    return expenseFromRow(rows.first);
  }

  @override
  Future<Expense> create({
    required double amount,
    required String description,
    required String categoryId,
    DateTime? date,
  }) async {
    final db = await _local.instance;
    _checkAmount(amount);
    final clean = _checkDescription(description);
    await _assertCategory(db, categoryId);

    final id = LocalDatabase.newId();
    await db.insert('expenses', {
      'id': id,
      'amount': amount,
      'description': clean,
      'description_lc': clean.toLowerCase(),
      'category_id': categoryId,
      'date': (date ?? DateTime.now()).millisecondsSinceEpoch,
    });
    return _byId(db, id);
  }

  @override
  Future<Expense> update(
    String id, {
    double? amount,
    String? description,
    String? categoryId,
    DateTime? date,
  }) async {
    final db = await _local.instance;
    if (amount != null) _checkAmount(amount);
    final clean = description == null ? null : _checkDescription(description);
    if (categoryId != null) await _assertCategory(db, categoryId);

    final patch = <String, Object?>{
      'amount': ?amount,
      'description': ?clean,
      'description_lc': ?clean?.toLowerCase(),
      'category_id': ?categoryId,
      'date': ?date?.millisecondsSinceEpoch,
    };
    if (patch.isNotEmpty) await db.update('expenses', patch, where: 'id = ?', whereArgs: [id]);
    return _byId(db, id);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _local.instance;
    final n = await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    if (n == 0) throw ApiException('Expense not found', statusCode: 404);
  }
}
