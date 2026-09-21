import 'package:sqflite/sqflite.dart';
import '../../../core/constants/category_presets.dart';
import '../../../core/local/local_database.dart';
import '../../../core/network/api_exception.dart';
import '../domain/category.dart';
import 'category_api.dart';

Category categoryFromRow(Map<String, Object?> r, {String prefix = ''}) => Category(
      id: r['${prefix}id'] as String,
      name: r['${prefix}name'] as String,
      icon: r['${prefix}icon'] as String,
      color: r['${prefix}color'] as String,
      isDeletable: (r['${prefix}is_deletable'] as int) == 1,
    );

/// SQLite implementation of [CategoryApi]. Error messages and status codes
/// match the backend's so screens show identical feedback in both modes.
class LocalCategoryApi implements CategoryApi {
  final LocalDatabase _local;

  LocalCategoryApi(this._local);

  static String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 30) {
      throw ApiException('body.name: Name must be 1-30 characters', statusCode: 400);
    }
    return trimmed;
  }

  static void _checkPresets({String? icon, String? color}) {
    if (icon != null && !CategoryPresets.icons.containsKey(icon)) {
      throw ApiException('body.icon: Invalid option', statusCode: 400);
    }
    if (color != null && !CategoryPresets.colorHexes.contains(color)) {
      throw ApiException('body.color: Invalid option', statusCode: 400);
    }
  }

  static Never _duplicate() => throw ApiException('Already exists', statusCode: 409);

  @override
  Future<List<Category>> list() async {
    final db = await _local.instance;
    final rows = await db.query('categories', orderBy: 'rowid');
    return rows.map(categoryFromRow).toList();
  }

  @override
  Future<Category> create({required String name, required String icon, required String color}) async {
    final db = await _local.instance;
    final clean = _validName(name);
    _checkPresets(icon: icon, color: color);
    final id = LocalDatabase.newId();
    try {
      await db.insert('categories', {
        'id': id,
        'name': clean,
        'name_key': clean.toLowerCase(),
        'icon': icon,
        'color': color,
        'is_deletable': 1,
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) _duplicate();
      rethrow;
    }
    return Category(id: id, name: clean, icon: icon, color: color, isDeletable: true);
  }

  @override
  Future<Category> update(String id, {String? name, String? icon, String? color}) async {
    final db = await _local.instance;
    final clean = name == null ? null : _validName(name);
    _checkPresets(icon: icon, color: color);

    final patch = <String, Object?>{
      'name': ?clean,
      'name_key': ?clean?.toLowerCase(),
      'icon': ?icon,
      'color': ?color,
    };
    try {
      if (patch.isNotEmpty) await db.update('categories', patch, where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) _duplicate();
      rethrow;
    }
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw ApiException('Category not found', statusCode: 404);
    return categoryFromRow(rows.first);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _local.instance;
    await db.transaction((txn) async {
      final rows = await txn.query('categories', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw ApiException('Category not found', statusCode: 404);
      if ((rows.first['is_deletable'] as int) == 0) {
        throw ApiException('"Other" is required as a fallback category and cannot be deleted', statusCode: 400);
      }
      final fallback = await txn.query('categories', where: 'is_deletable = 0', limit: 1);
      // Never leave an expense pointing at a category that no longer exists.
      await txn.update('expenses', {'category_id': fallback.first['id']}, where: 'category_id = ?', whereArgs: [id]);
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }
}
