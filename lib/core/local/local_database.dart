import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Mirrors backend/src/constants/categoryPresets.js DEFAULT_CATEGORIES.
const _defaultCategories = [
  ('Food', 'restaurant', '#F59E0B', true),
  ('Transport', 'directions_car', '#3B82F6', true),
  ('Shopping', 'shopping_bag', '#8B5CF6', true),
  ('Bills', 'receipt_long', '#EF4444', true),
  ('Entertainment', 'movie', '#EC4899', true),
  ('Health', 'favorite', '#14B8A6', true),
  ('Other', 'category', '#6B7280', false),
];

/// Owns the single on-device SQLite file (`spendwise.db`). All local-mode
/// data lives in this one file so it can later be backed up or restored by
/// copying it.
class LocalDatabase {
  final Future<Database> Function() _open;
  Future<Database>? _db;

  LocalDatabase._(this._open);

  /// The real on-device database.
  factory LocalDatabase.onDevice() => LocalDatabase._(() async {
        final dir = await getDatabasesPath();
        return openDatabase(p.join(dir, 'spendwise.db'), version: 1, onCreate: createSchema);
      });

  /// For tests: any already-configured factory (e.g. an in-memory ffi DB).
  factory LocalDatabase.withOpener(Future<Database> Function() open) => LocalDatabase._(open);

  Future<Database> get instance => _db ??= _open();

  static Future<void> createSchema(Database db, int version) async {
    // name_key is the lowercased name: a UNIQUE column gives the same
    // case-insensitive "no duplicate names" rule as the cloud's collation
    // index, including for non-ASCII names that SQLite's NOCASE would miss.
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        name_key TEXT NOT NULL UNIQUE,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        is_deletable INTEGER NOT NULL DEFAULT 1
      )
    ''');
    // date is UTC epoch ms; description_lc is the Dart-lowercased description
    // so search can be a plain substring test (no LIKE wildcards to escape,
    // and Unicode-aware case folding that SQLite's LIKE lacks).
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        description_lc TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        date INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_expenses_category_date ON expenses(category_id, date)');

    await _seedDefaults(db);
  }

  static Future<void> _seedDefaults(DatabaseExecutor db) async {
    for (final (name, icon, color, deletable) in _defaultCategories) {
      await db.insert('categories', {
        'id': newId(),
        'name': name,
        'name_key': name.toLowerCase(),
        'icon': icon,
        'color': color,
        'is_deletable': deletable ? 1 : 0,
      });
    }
  }

  /// Wipes every expense and category, then re-seeds the defaults — the local
  /// equivalent of deleting the account.
  Future<void> eraseAll() async {
    final db = await instance;
    await db.transaction((txn) async {
      await txn.delete('expenses');
      await txn.delete('categories');
      await _seedDefaults(txn);
    });
  }

  /// 24 hex chars, the same shape as the cloud's ids, so id-typed code paths
  /// see identical values in both modes.
  static String newId() {
    final rng = Random.secure();
    return List.generate(12, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
