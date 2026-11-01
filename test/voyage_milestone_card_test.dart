import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wavemind_app/core/db/app_database.dart';
import 'package:wavemind_app/data/models/voyage_status.dart';
import 'package:wavemind_app/data/wellness_repository.dart';
import 'package:wavemind_app/screens/community_connect_screen.dart';

/// Confirms the Fleet Spirit "Voyage Milestone" card renders the real,
/// previously-saved [VoyageStatus] (the same on-device record the Helm
/// "Voyage Details" card writes), not just its docked fallback — which is
/// all the plain-fallback screens_smoke_test.dart coverage can exercise.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // The isolate-backed `databaseFactoryFfi` deadlocks inside testWidgets:
    // its real cross-isolate port never resolves under the FakeAsync zone
    // Flutter's test binding runs test bodies in. The no-isolate factory runs
    // SQLite synchronously in-process, which is safe here (and is exactly
    // what the package recommends for widget tests).
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late WellnessRepository repo;

  setUp(() async {
    repo = WellnessRepository();
    final db = await AppDatabase.instance.database;
    await db.delete('voyage_status');
  });

  tearDownAll(() async {
    await AppDatabase.instance.close();
  });

  testWidgets('shows the saved route and days remaining for an active voyage',
      (tester) async {
    await repo.saveVoyageStatus(
      VoyageStatus(
        state: VoyageState.voyage,
        origin: 'Yokohama',
        destination: 'Valparaiso',
        totalDays: 10,
        anchoredAt: DateTime.now(),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: CommunityConnectScreen(repository: repo)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Yokohama to Valparaiso'), findsOneWidget);
    expect(find.text('10 Days Remaining'), findsOneWidget);
    expect(find.text('Docked'), findsNothing);
  });

  testWidgets(
      'shows percent completed as elapsed-of-total since the voyage was saved',
      (tester) async {
    // 20 days saved 10 days ago -> 10 days left, 50% of the voyage elapsed.
    await repo.saveVoyageStatus(
      VoyageStatus(
        state: VoyageState.voyage,
        origin: 'Yokohama',
        destination: 'Valparaiso',
        totalDays: 20,
        anchoredAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: CommunityConnectScreen(repository: repo)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('10 Days Remaining'), findsOneWidget);
    expect(find.text('50% Completed'), findsOneWidget);
  });
}
