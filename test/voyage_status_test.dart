import 'package:flutter_test/flutter_test.dart';

import 'package:wavemind_app/data/models/voyage_status.dart';

void main() {
  group('VoyageStatus.daysRemaining', () {
    test('is null for a docked status', () {
      const status = VoyageStatus(state: VoyageState.docked);
      expect(status.daysRemaining(), isNull);
    });

    test('equals the saved total on the anchor day itself', () {
      final anchoredAt = DateTime(2026, 1, 1);
      final status = VoyageStatus(
        state: VoyageState.voyage,
        totalDays: 10,
        anchoredAt: anchoredAt,
      );
      expect(status.daysRemaining(DateTime(2026, 1, 1, 18)), 10);
    });

    test('counts down one per elapsed day, ignoring time of day', () {
      final anchoredAt = DateTime(2026, 1, 1, 23);
      final status = VoyageStatus(
        state: VoyageState.voyage,
        totalDays: 10,
        anchoredAt: anchoredAt,
      );
      expect(status.daysRemaining(DateTime(2026, 1, 4, 1)), 7);
    });

    test('floors at 0 once the voyage has run past its total', () {
      final anchoredAt = DateTime(2026, 1, 1);
      final status = VoyageStatus(
        state: VoyageState.voyage,
        totalDays: 5,
        anchoredAt: anchoredAt,
      );
      expect(status.daysRemaining(DateTime(2026, 1, 20)), 0);
    });
  });

  group('VoyageStatus.effectiveState', () {
    test('a docked status is always docked', () {
      const status = VoyageStatus(state: VoyageState.docked);
      expect(status.effectiveState(), VoyageState.docked);
    });

    test('a voyage with days left stays a voyage', () {
      final status = VoyageStatus(
        state: VoyageState.voyage,
        totalDays: 10,
        anchoredAt: DateTime(2026, 1, 1),
      );
      expect(status.effectiveState(DateTime(2026, 1, 2)), VoyageState.voyage);
    });

    test('auto-flips to docked once the countdown hits 0', () {
      final status = VoyageStatus(
        state: VoyageState.voyage,
        totalDays: 5,
        anchoredAt: DateTime(2026, 1, 1),
      );
      expect(status.effectiveState(DateTime(2026, 1, 6)), VoyageState.docked);
    });
  });

  group('VoyageStatus map round-trip', () {
    test('toMap/fromMap preserves every field', () {
      final status = VoyageStatus(
        state: VoyageState.voyage,
        origin: 'Yokohama',
        destination: 'Valparaiso',
        totalDays: 21,
        anchoredAt: DateTime(2026, 3, 5, 9, 30),
      );
      final restored = VoyageStatus.fromMap(status.toMap());
      expect(restored.state, VoyageState.voyage);
      expect(restored.origin, 'Yokohama');
      expect(restored.destination, 'Valparaiso');
      expect(restored.totalDays, 21);
      expect(restored.anchoredAt, status.anchoredAt);
    });

    test('a docked status round-trips with null voyage fields', () {
      const status = VoyageStatus(state: VoyageState.docked);
      final restored = VoyageStatus.fromMap(status.toMap());
      expect(restored.state, VoyageState.docked);
      expect(restored.origin, isNull);
      expect(restored.destination, isNull);
      expect(restored.totalDays, isNull);
      expect(restored.anchoredAt, isNull);
    });
  });
}
