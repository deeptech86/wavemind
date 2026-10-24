import 'package:flutter_test/flutter_test.dart';
import 'package:tidewell_app/data/health_data_service.dart';

void main() {
  group('HealthDataService.formatSleepDuration', () {
    test('formats hours and minutes as "7h 42m"', () {
      expect(
        HealthDataService.formatSleepDuration(
          const Duration(hours: 7, minutes: 42),
        ),
        '7h 42m',
      );
    });

    test('drops the minutes component on a whole hour', () {
      expect(
        HealthDataService.formatSleepDuration(const Duration(hours: 8)),
        '8h',
      );
    });

    test('shows minutes only when under an hour', () {
      expect(
        HealthDataService.formatSleepDuration(const Duration(minutes: 45)),
        '45m',
      );
    });

    test('truncates sub-minute remainders to whole minutes', () {
      expect(
        HealthDataService.formatSleepDuration(
          const Duration(hours: 6, minutes: 30, seconds: 59),
        ),
        '6h 30m',
      );
    });

    test('zero duration renders as "0m"', () {
      expect(HealthDataService.formatSleepDuration(Duration.zero), '0m');
    });
  });

  group('HealthDataService.pointsForSync', () {
    // Client formula: 1000 steps = 100 pts, 8h (480 min) sleep = 100 pts, both
    // as floor-blocks so partial blocks don't count.
    test('awards 100 points per full 1000-step block', () {
      expect(
        HealthDataService.pointsForSync(const HealthSnapshot(steps: 1000)),
        100,
      );
      expect(
        HealthDataService.pointsForSync(const HealthSnapshot(steps: 2500)),
        200, // 2 full blocks, remainder dropped
      );
    });

    test('awards 100 points per full 8h (480 min) sleep block', () {
      expect(
        HealthDataService.pointsForSync(
          const HealthSnapshot(sleep: Duration(hours: 8)),
        ),
        100,
      );
      expect(
        HealthDataService.pointsForSync(
          const HealthSnapshot(sleep: Duration(hours: 16)),
        ),
        200,
      );
    });

    test('sums steps and sleep contributions', () {
      // 7500 steps -> 7 blocks -> 700; 9h sleep -> 1 block -> 100; total 800.
      expect(
        HealthDataService.pointsForSync(
          const HealthSnapshot(steps: 7500, sleep: Duration(hours: 9)),
        ),
        800,
      );
    });

    test('a partial block below the threshold contributes zero', () {
      expect(
        HealthDataService.pointsForSync(
          const HealthSnapshot(steps: 999, sleep: Duration(minutes: 479)),
        ),
        0,
      );
    });

    test('null / missing metrics count as zero rather than erroring', () {
      expect(HealthDataService.pointsForSync(const HealthSnapshot()), 0);
      expect(
        HealthDataService.pointsForSync(const HealthSnapshot(steps: 3000)),
        300, // sleep null -> 0
      );
      expect(
        HealthDataService.pointsForSync(
          const HealthSnapshot(sleep: Duration(hours: 8)),
        ),
        100, // steps null -> 0
      );
    });

    test('heart rate alone never contributes points', () {
      expect(
        HealthDataService.pointsForSync(
          const HealthSnapshot(restingHeartRate: 60),
        ),
        0,
      );
    });
  });

  group('HealthSnapshot', () {
    test('hasAnyData is false when every metric is null', () {
      expect(const HealthSnapshot().hasAnyData, isFalse);
    });

    test('hasAnyData is true when at least one metric is present', () {
      expect(const HealthSnapshot(steps: 0).hasAnyData, isTrue);
      expect(
        const HealthSnapshot(sleep: Duration(hours: 7)).hasAnyData,
        isTrue,
      );
      expect(
        const HealthSnapshot(restingHeartRate: 60).hasAnyData,
        isTrue,
      );
    });
  });
}
