import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens and owns the single on-device SQLite database used for all local
/// persistence (journal entries, mood check-ins, breathing sessions and the
/// Fleet Knots ledger).
///
/// **Why sqflite (not drift):** the schema is four small, independent, flat
/// tables with simple inserts and a handful of date-range aggregation reads. No
/// relations, migrations-heavy modelling, or reactive query streams are needed.
/// sqflite covers this directly with zero code-generation / build_runner setup —
/// keeping the toolchain of a project that otherwise has no codegen simple. The
/// aggregation / streak logic lives as pure functions in `wellness_stats.dart`,
/// so we don't lose type-safety where it matters and it stays unit-testable
/// without a database.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _fileName = 'tidewell.db';
  static const int _version = 1;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);
    return openDatabase(path, version: _version, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journal_entries (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        body       TEXT NOT NULL,
        prompt     TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mood_check_ins (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        state         TEXT NOT NULL,
        sleep_quality INTEGER NOT NULL,
        sea_weather   INTEGER NOT NULL,
        homesickness  INTEGER NOT NULL,
        created_at    TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE breathing_sessions (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        duration_seconds INTEGER NOT NULL,
        created_at       TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE knot_events (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        type       TEXT NOT NULL,
        knots      INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Visible for tests: close and forget the current handle.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
