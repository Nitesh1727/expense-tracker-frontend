import 'package:excel/excel.dart';
import '../../../core/local/ist.dart';

class ExportRow {
  final DateTime date;
  final String category;
  final String description;
  final double amount;

  ExportRow({required this.date, required this.category, required this.description, required this.amount});
}

// Mirrors backend/src/utils/excel.util.js — same layout, colours and number
// formats — so a local export is indistinguishable from a cloud one.
const _currencyFormat = '"₹"#,##0.00';
final _headerFill = ExcelColor.fromHexString('#CC5F3B');
final _headerFont = ExcelColor.fromHexString('#FFFFFF');
final _totalFill = ExcelColor.fromHexString('#F3EDE8');
final _titleFont = ExcelColor.fromHexString('#2D2A26');

/// Excel forbids `: \ / ? * [ ]` in sheet names and caps them at 31 chars.
String sanitizeSheetName(String label) {
  final cleaned = label.replaceAll(RegExp(r'[:\\/?*\[\]]'), '').trim();
  final cut = cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
  return cut.isEmpty ? 'Expenses' : cut;
}

/// Known local-only gap: the `excel` package cannot freeze panes, so the top
/// three rows scroll instead of staying pinned as in the cloud workbook.
List<int> buildExpensesXlsx(List<ExportRow> expenses, String label) {
  final excel = Excel.createExcel();
  final name = sanitizeSheetName(label);
  excel.rename(excel.getDefaultSheet()!, name);
  final sheet = excel[name];

  for (final (i, w) in [14.0, 20.0, 34.0, 16.0].indexed) {
    sheet.setColumnWidth(i, w);
  }

  CellIndex at(int col, int row) => CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
  void put(int col, int row, CellValue value, [CellStyle? style]) {
    final cell = sheet.cell(at(col, row));
    cell.value = value;
    if (style != null) cell.cellStyle = style;
  }

  final header = CellStyle(bold: true, fontColorHex: _headerFont, backgroundColorHex: _headerFill, verticalAlign: VerticalAlign.Center);
  final money = CellStyle(numberFormat: const CustomNumericNumFormat(formatCode: _currencyFormat));

  // Row 0: merged title. Row 1 blank. Row 2: table header.
  sheet.merge(at(0, 0), at(3, 0));
  put(0, 0, TextCellValue('Expenses — $label'), CellStyle(bold: true, fontSize: 14, fontColorHex: _titleFont));
  sheet.setRowHeight(0, 26);
  for (final (i, h) in ['Date', 'Category', 'Description', 'Amount'].indexed) {
    put(i, 2, TextCellValue(h), header);
  }
  sheet.setRowHeight(2, 20);

  var row = 3;
  var total = 0.0;
  final byCategory = <String, double>{};
  for (final e in expenses) {
    put(0, row, TextCellValue(Ist.dateString(e.date)));
    put(1, row, TextCellValue(e.category));
    put(2, row, TextCellValue(e.description));
    put(3, row, DoubleCellValue(e.amount), money);
    total += e.amount;
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    row++;
  }

  row++; // blank
  final totalStyle = CellStyle(bold: true, backgroundColorHex: _totalFill);
  sheet.merge(at(0, row), at(2, row));
  put(0, row, TextCellValue('Total'), totalStyle);
  put(3, row, DoubleCellValue(total), CellStyle(bold: true, backgroundColorHex: _totalFill, numberFormat: const CustomNumericNumFormat(formatCode: _currencyFormat)));
  row += 3; // two blank rows

  put(0, row, TextCellValue('By category'), CellStyle(bold: true, fontSize: 12));
  row++;
  for (final (i, h) in ['Category', 'Amount', '% of total'].indexed) {
    put(i, row, TextCellValue(h), header);
  }
  sheet.setRowHeight(row, 20);
  row++;

  final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted) {
    put(0, row, TextCellValue(e.key));
    put(1, row, DoubleCellValue(e.value), money);
    put(2, row, DoubleCellValue(total == 0 ? 0 : e.value / total), CellStyle(numberFormat: const CustomNumericNumFormat(formatCode: '0.0%')));
    row++;
  }

  return excel.encode()!;
}
