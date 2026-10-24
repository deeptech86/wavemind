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

  /// v2 adds the content-catalog cache tables (`catalog_stories`,
  /// `catalog_sounds`, `catalog_featured_games`) for the schedule-controlled
  /// story / soundscape rotation. v3 adds `voyage_status`, the single-row
  /// Helm voyage-details setting. The four original wellness tables are
  /// unchanged.
  static const int _version = 3;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createWellnessTables(db);
    await _createCatalogTables(db);
    await _createVoyageTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: add the content-catalog cache tables. `IF NOT EXISTS` keeps
    // this idempotent if the path is ever re-run.
    if (oldVersion < 2) {
      await _createCatalogTables(db);
    }
    // v2 -> v3: add the single-row voyage-status setting.
    if (oldVersion < 3) {
      await _createVoyageTable(db);
    }
  }

  Future<void> _createWellnessTables(Database db) async {
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

  /// Local mirror of the server content catalog. Each media row carries
  /// bookkeeping (`local_path`, `downloaded_at`, `media_version`) so a
  /// downloaded file is reused on repeat plays and only re-fetched when its
  /// server version changes. These tables cache metadata only — the bundled
  /// `assets/audio/*` files remain the permanent offline fallback.
  Future<void> _createCatalogTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_stories (
        id              TEXT PRIMARY KEY,
        title           TEXT NOT NULL,
        series          TEXT NOT NULL DEFAULT '',
        narrator        TEXT NOT NULL DEFAULT '',
        teaser_subtitle TEXT NOT NULL DEFAULT '',
        excerpt         TEXT NOT NULL DEFAULT '[]',
        coordinates     TEXT NOT NULL DEFAULT '',
        swell_note      TEXT NOT NULL DEFAULT '',
        duration_label  TEXT NOT NULL DEFAULT '',
        media_url       TEXT NOT NULL,
        media_version   TEXT NOT NULL DEFAULT '',
        sort_order      INTEGER NOT NULL DEFAULT 0,
        active          INTEGER NOT NULL DEFAULT 1,
        local_path      TEXT,
        downloaded_at   TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_sounds (
        id            TEXT PRIMARY KEY,
        label         TEXT NOT NULL,
        subtitle      TEXT NOT NULL DEFAULT '',
        media_url     TEXT NOT NULL,
        media_version TEXT NOT NULL DEFAULT '',
        sort_order    INTEGER NOT NULL DEFAULT 0,
        active        INTEGER NOT NULL DEFAULT 1,
        local_path    TEXT,
        downloaded_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_featured_games (
        game_key       TEXT PRIMARY KEY,
        active          INTEGER NOT NULL DEFAULT 0,
        effective_from TEXT NOT NULL DEFAULT '',
        sort_order     INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Single-row setting for the Helm "Voyage Details" card. `id` is pinned
  /// to 1 and every save is an upsert (`ConflictAlgorithm.replace`) — there
  /// is only ever one current voyage status.
  Future<void> _createVoyageTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS voyage_status (
        id           INTEGER PRIMARY KEY CHECK (id = 1),
        status       TEXT NOT NULL,
        origin       TEXT,
        destination  TEXT,
        total_days   INTEGER,
        anchored_at  TEXT
      )
    ''');
  }

  /// Visible for tests: close and forget the current handle.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
