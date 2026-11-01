import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wavemind_app/core/db/app_database.dart';
import 'package:wavemind_app/data/models/knot_event.dart';
import 'package:wavemind_app/data/models/voyage_status.dart';
import 'package:wavemind_app/data/wellness_repository.dart';

/// Exercises [WellnessRepository] against a real, in-process SQLite database
/// (sqflite FFI) so the ledger writes can be asserted off-device.
void main() {
  // Route sqflite's global openDatabase/getDatabasesPath through FFI.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late WellnessRepository repo;

  setUp(() async {
    // Fresh, isolated knot ledger per test: use the shared AppDatabase singleton
    // but truncate the table so counts/rows are deterministic.
    repo = WellnessRepository();
    final db = await AppDatabase.instance.database;
    await db.delete('knot_events');
    await db.delete('voyage_status');
  });

  tearDownAll(() async {
    await AppDatabase.instance.close();
  });

  group('recordHealthSync', () {
    test('writes exactly one health_sync ledger row for the passed amount',
        () async {
      await repo.recordHealthSync(knots: 800);

      final events = await repo.knotEvents();
      expect(events, hasLength(1));
      final entry = events.single;
      expect(entry.type, KnotEventType.healthSync);
      expect(entry.knots, 800); // the explicit amount, not the enum's nominal 0
    });

    test('the synced amount flows into the Fleet Knots total', () async {
      await repo.recordHealthSync(knots: 300);
      await repo.recordHealthSync(knots: 150);

      final summary = await repo.contributionSummary();
      expect(summary.totalKnots, 450);
    });

    test('does not disturb the fixed-value earners (mood/journal/breathing)',
        () async {
      // Existing fixed-value writers still award their own enum values; the
      // health-sync override path must not change them.
      await repo.recordHealthSync(knots: 500);
      await repo.recordBreathingSession(durationSeconds: 120);

      final events = await repo.knotEvents();
      final breathing = events.firstWhere(
        (e) => e.type == KnotEventType.breathingSession,
      );
      final health = events.firstWhere(
        (e) => e.type == KnotEventType.healthSync,
      );
      expect(breathing.knots, KnotEventType.breathingSession.knots); // 50
      expect(health.knots, 500);
    });
  });

  group('voyageStatus', () {
    test('is null before anything has ever been saved', () async {
      expect(await repo.voyageStatus(), isNull);
    });

    test('round-trips a saved voyage against the real schema', () async {
      final saved = VoyageStatus(
        state: VoyageState.voyage,
        origin: 'Yokohama',
        destination: 'Valparaiso',
        totalDays: 21,
        anchoredAt: DateTime(2026, 3, 5),
      );
      await repo.saveVoyageStatus(saved);

      final loaded = await repo.voyageStatus();
      expect(loaded, isNotNull);
      expect(loaded!.state, VoyageState.voyage);
      expect(loaded.origin, 'Yokohama');
      expect(loaded.destination, 'Valparaiso');
      expect(loaded.totalDays, 21);
      expect(loaded.anchoredAt, DateTime(2026, 3, 5));
    });

    test('a second save replaces the first row rather than inserting a new one',
        () async {
      await repo.saveVoyageStatus(
        VoyageStatus(
          state: VoyageState.voyage,
          origin: 'Yokohama',
          destination: 'Valparaiso',
          totalDays: 21,
          anchoredAt: DateTime(2026, 3, 5),
        ),
      );
      await repo.saveVoyageStatus(const VoyageStatus(state: VoyageState.docked));

      final db = await AppDatabase.instance.database;
      final rows = await db.query('voyage_status');
      expect(rows, hasLength(1));

      final loaded = await repo.voyageStatus();
      expect(loaded!.state, VoyageState.docked);
      expect(loaded.origin, isNull);
    });
  });
}
