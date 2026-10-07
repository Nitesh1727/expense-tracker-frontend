import 'dart:io';
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
  // Only needed for restoreFromFile's validation step (opening an arbitrary
  // *other* file read-only to check it's really a SpendWise backup before
  // trusting it) — null in tests that never call restore. Separate from
  // [_open] because that one always opens *this* database's own fixed path.
  final Future<Database> Function(String path)? _openReadOnly;
  Future<Database>? _db;

  LocalDatabase._(this._open, this._openReadOnly);

  /// The real on-device database.
  factory LocalDatabase.onDevice() => LocalDatabase._(
        () async {
          final dir = await getDatabasesPath();
          return openDatabase(p.join(dir, 'spendwise.db'), version: 1, onCreate: createSchema);
        },
        (path) => openDatabase(path, readOnly: true),
      );

  /// For tests: any already-configured factory (e.g. an in-memory ffi DB).
  /// [openReadOnly] is only needed by tests that exercise [restoreFromFile].
  factory LocalDatabase.withOpener(Future<Database> Function() open, {Future<Database> Function(String path)? openReadOnly}) =>
      LocalDatabase._(open, openReadOnly);

  Future<Database> get instance => _db ??= _open();

  /// The file on disk all local-mode data lives in — Android/iOS keep it in
  /// app-private storage, invisible to a Files app, which is why backup/
  /// restore below exist instead of pointing the user at a folder.
  Future<String> get path async => (await instance).path;

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

  Future<void> close() async {
    final pending = _db;
    _db = null;
    if (pending != null) await (await pending).close();
  }

  /// Writes a complete, consistent snapshot of the live database to
  /// [destPath] using SQLite's own `VACUUM INTO` — safe to call while the
  /// app keeps using the database (unlike copying the raw file, which could
  /// catch it mid-write and copy a corrupt snapshot). This is the whole of
  /// "back up my data": the resulting file is itself a valid SpendWise
  /// database, openable by [restoreFromFile] on any device.
  Future<void> exportSnapshotTo(String destPath) async {
    final db = await instance;
    if (await File(destPath).exists()) await File(destPath).delete();
    // The destination is a fixed path this app generated (a temp file, or
    // the picker's chosen name), never user-typed SQL — but VACUUM INTO
    // doesn't accept a bound parameter for the filename, so it's quoted by
    // hand with its single quotes escaped.
    await db.execute("VACUUM INTO '${destPath.replaceAll("'", "''")}'");
  }

  /// Replaces all local data with the contents of [sourcePath] (a file
  /// produced by [exportSnapshotTo]/a restore picked from Drive/Files). The
  /// current database is backed up alongside itself first and restored if
  /// anything below fails, so a bad or corrupt file can't leave the app
  /// without a database.
  Future<void> restoreFromFile(String sourcePath) async {
    final openReadOnly = _openReadOnly;
    if (openReadOnly == null) throw UnsupportedError('restoreFromFile needs openReadOnly');
    await _assertIsSpendWiseBackup(sourcePath, openReadOnly);

    final targetPath = await path;
    await close();
    final target = File(targetPath);
    final safety = File('$targetPath.before-restore');
    if (await target.exists()) await target.copy(safety.path);
    try {
      await File(sourcePath).copy(targetPath);
    } catch (_) {
      if (await safety.exists()) await safety.copy(targetPath);
      rethrow;
    } finally {
      if (await safety.exists()) await safety.delete();
    }
  }

  static Future<void> _assertIsSpendWiseBackup(String path, Future<Database> Function(String) openReadOnly) async {
    Database? probe;
    try {
      probe = await openReadOnly(path);
      final tables = await probe.query('sqlite_master', columns: ['name'], where: "type = 'table'");
      final names = tables.map((t) => t['name']).toSet();
      if (!names.containsAll(['categories', 'expenses'])) {
        throw const FormatException("This doesn't look like a SpendWise backup file.");
      }
    } on DatabaseException {
      throw const FormatException("This doesn't look like a SpendWise backup file.");
    } finally {
      await probe?.close();
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
