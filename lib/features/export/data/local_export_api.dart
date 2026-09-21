import '../../../core/local/local_database.dart';
import '../../expenses/data/local_expense_api.dart';
import 'export_api.dart';
import 'xlsx_builder.dart';

/// Builds the workbook on-device from SQLite; never touches the network.
class LocalExportApi implements ExportApi {
  final LocalDatabase _local;

  LocalExportApi(this._local);

  @override
  Future<List<int>> downloadXlsx({DateTime? from, DateTime? to, String? label}) async {
    final db = await _local.instance;
    final f = ExpenseFilter(from: from, to: to);
    final rows = await db.rawQuery(
      'SELECT e.date, e.description, e.amount, c.name AS category '
      'FROM expenses e JOIN categories c ON c.id = e.category_id ${f.where} ORDER BY e.date DESC',
      f.args,
    );
    return buildExpensesXlsx(
      rows
          .map((r) => ExportRow(
                date: DateTime.fromMillisecondsSinceEpoch(r['date'] as int),
                category: r['category'] as String,
                description: r['description'] as String,
                amount: (r['amount'] as num).toDouble(),
              ))
          .toList(),
      label == null || label.isEmpty ? 'All expenses' : label,
    );
  }
}
