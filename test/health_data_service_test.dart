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
