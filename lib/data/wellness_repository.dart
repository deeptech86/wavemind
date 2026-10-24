import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/db/app_database.dart';
import 'models/breathing_session.dart';
import 'models/journal_entry.dart';
import 'models/knot_event.dart';
import 'models/mood_check_in.dart';
import 'models/voyage_status.dart';
import 'wellness_stats.dart';

/// Read model for the Crew "Your Contribution" card.
class ContributionSummary {
  const ContributionSummary({
    required this.totalKnots,
    required this.breathStreakDays,
    required this.seaLogsFiled,
  });

  final int totalKnots;
  final int breathStreakDays;

  /// Count of logbook entries filed (mood check-ins + journal entries).
  final int seaLogsFiled;

  static const empty = ContributionSummary(
    totalKnots: 0,
    breathStreakDays: 0,
    seaLogsFiled: 0,
  );
}

/// Read model for the Weekly Insights screen.
class WeeklyInsightsData {
  const WeeklyInsightsData({
    required this.waveScores,
    required this.breathStreakDays,
    required this.seaLogsFiled,
  });

  /// 7 trailing-day average mood scores (1–5), `null` for days with no log.
  final List<double?> waveScores;
  final int breathStreakDays;
  final int seaLogsFiled;

  bool get hasAnyMood => waveScores.any((v) => v != null);

  static const empty = WeeklyInsightsData(
    waveScores: <double?>[null, null, null, null, null, null, null],
    breathStreakDays: 0,
    seaLogsFiled: 0,
  );
}

/// Central on-device data store. Owns all local tables and — crucially —
/// awards Fleet Knots atomically whenever a point-earning action is saved, so
/// the ledger and the activity that earned the knots can never drift apart.
///
/// Every public method is defensive: if the sqflite platform channel is
/// unavailable (e.g. during widget tests, which have no native DB), reads
/// return empty defaults and writes become no-ops rather than throwing. This is
/// the same "degrade gracefully" posture the audio screens already use.
class WellnessRepository {
  WellnessRepository({AppDatabase? db})
    : _appDb = db ?? AppDatabase.instance;

  final AppDatabase _appDb;

  // --- Journal --------------------------------------------------------------

  Future<JournalEntry?> saveJournalEntry({
    required String body,
    String? prompt,
  }) async {
    final entry = JournalEntry(
      body: body,
      prompt: prompt,
      createdAt: DateTime.now(),
    );
    return _guard<JournalEntry?>(() async {
      final db = await _appDb.database;
      late int id;
      await db.transaction((txn) async {
        id = await txn.insert('journal_entries', entry.toMap());
        await _insertKnot(txn, KnotEventType.journalEntry);
      });
      return JournalEntry(
        id: id,
        body: entry.body,
        prompt: entry.prompt,
        createdAt: entry.createdAt,
      );
    }, fallback: null);
  }

  Future<List<JournalEntry>> journalEntries({int? limit}) {
    return _guard<List<JournalEntry>>(() async {
      final db = await _appDb.database;
      final rows = await db.query(
        'journal_entries',
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return rows.map(JournalEntry.fromMap).toList();
    }, fallback: const []);
  }

  // --- Mood -----------------------------------------------------------------

  Future<void> saveMoodCheckIn(MoodCheckIn checkIn) {
    return _guard<void>(() async {
      final db = await _appDb.database;
      await db.transaction((txn) async {
        await txn.insert('mood_check_ins', checkIn.toMap());
        await _insertKnot(txn, KnotEventType.moodCheckIn);
      });
    }, fallback: null);
  }

  Future<List<MoodCheckIn>> moodCheckIns() {
    return _guard<List<MoodCheckIn>>(() async {
      final db = await _appDb.database;
      final rows = await db.query('mood_check_ins', orderBy: 'created_at DESC');
      return rows.map(MoodCheckIn.fromMap).toList();
    }, fallback: const []);
  }

  // --- Breathing ------------------------------------------------------------

  Future<void> recordBreathingSession({required int durationSeconds}) {
    final session = BreathingSession(
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
    );
    return _guard<void>(() async {
      final db = await _appDb.database;
      await db.transaction((txn) async {
        await txn.insert('breathing_sessions', session.toMap());
        await _insertKnot(txn, KnotEventType.breathingSession);
      });
    }, fallback: null);
  }

  // --- Health sync ----------------------------------------------------------

  /// Persists a single one-off Fleet Knots ledger entry for a manual health
  /// sync. The point [knots] amount is computed live from today's steps/sleep
  /// by the caller and passed in explicitly — only this computed value ever
  /// crosses the persistence boundary; raw health metrics never do.
  ///
  /// Follows the same graceful-degradation posture as the other writers: a
  /// no-op (not a throw) when the native DB is unavailable (e.g. widget tests).
  Future<void> recordHealthSync({required int knots}) {
    return _guard<void>(() async {
      final db = await _appDb.database;
      await db.transaction((txn) async {
        await _insertKnot(txn, KnotEventType.healthSync, knots: knots);
      });
    }, fallback: null);
  }

  Future<List<BreathingSession>> breathingSessions() {
    return _guard<List<BreathingSession>>(() async {
      final db = await _appDb.database;
      final rows = await db.query(
        'breathing_sessions',
        orderBy: 'created_at DESC',
      );
      return rows.map(BreathingSession.fromMap).toList();
    }, fallback: const []);
  }

  // --- Knots ledger ---------------------------------------------------------

  Future<List<KnotEvent>> knotEvents() {
    return _guard<List<KnotEvent>>(() async {
      final db = await _appDb.database;
      final rows = await db.query('knot_events', orderBy: 'created_at DESC');
      return rows.map(KnotEvent.fromMap).toList();
    }, fallback: const []);
  }

  // --- Voyage status ----------------------------------------------------------

  /// `null` means the sailor has never set a voyage status yet (first run).
  Future<VoyageStatus?> voyageStatus() {
    return _guard<VoyageStatus?>(() async {
      final db = await _appDb.database;
      final rows = await db.query('voyage_status', where: 'id = 1', limit: 1);
      if (rows.isEmpty) return null;
      return VoyageStatus.fromMap(rows.first);
    }, fallback: null);
  }

  Future<void> saveVoyageStatus(VoyageStatus status) {
    return _guard<void>(() async {
      final db = await _appDb.database;
      await db.insert(
        'voyage_status',
        status.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }, fallback: null);
  }

  // --- Composite read models ------------------------------------------------

  Future<ContributionSummary> contributionSummary() async {
    final knots = await knotEvents();
    final breaths = await breathingSessions();
    final moods = await moodCheckIns();
    final journals = await journalEntries();
    return ContributionSummary(
      totalKnots: WellnessStats.totalKnots(knots),
      breathStreakDays: WellnessStats.dailyStreak(
        breaths.map((b) => b.createdAt),
      ),
      seaLogsFiled: moods.length + journals.length,
    );
  }

  Future<WeeklyInsightsData> weeklyInsights() async {
    final moods = await moodCheckIns();
    final breaths = await breathingSessions();
    final journals = await journalEntries();
    return WeeklyInsightsData(
      waveScores: WellnessStats.weeklyWaveScores(moods),
      breathStreakDays: WellnessStats.dailyStreak(
        breaths.map((b) => b.createdAt),
      ),
      seaLogsFiled: moods.length + journals.length,
    );
  }

  // --- Internals ------------------------------------------------------------

  /// Inserts a ledger row for [type]. The three fixed-value call sites
  /// (mood/journal/breathing) omit [knots] and fall back to the type's own
  /// fixed value; the health-sync path passes an explicit variable amount.
  Future<void> _insertKnot(
    Transaction txn,
    KnotEventType type, {
    int? knots,
  }) {
    final event = KnotEvent(
      type: type,
      knots: knots ?? type.knots,
      createdAt: DateTime.now(),
    );
    return txn.insert('knot_events', event.toMap()).then((_) {});
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    required T fallback,
  }) async {
    try {
      return await action();
    } catch (e) {
      // No native SQLite (widget tests) or an unexpected DB error: degrade to
      // empty/no-op so the UI renders its empty state instead of crashing.
      debugPrint('WellnessRepository: degrading to fallback ($e)');
      return fallback;
    }
  }
}
