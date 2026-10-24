import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tidewell_app/core/db/app_database.dart';
import 'package:tidewell_app/data/models/knot_event.dart';
import 'package:tidewell_app/data/wellness_repository.dart';

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
}
