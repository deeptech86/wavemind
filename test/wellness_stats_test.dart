import 'package:flutter_test/flutter_test.dart';

import 'package:tidewell_app/data/models/knot_event.dart';
import 'package:tidewell_app/data/models/mood_check_in.dart';
import 'package:tidewell_app/data/models/mood_state.dart';
import 'package:tidewell_app/data/wellness_stats.dart';

void main() {
  // The point values are the contract sourced from the Crew screen copy:
  // daily swell (+30), float-bottle/reflective-writing tier (+40), breath (+50).
  group('Fleet Knots point values', () {
    test('match the Crew "How Fleet Knots are Earned" tiers exactly', () {
      expect(KnotEventType.moodCheckIn.knots, 30);
      expect(KnotEventType.journalEntry.knots, 40);
      expect(KnotEventType.breathingSession.knots, 50);
    });
  });

  group('totalKnots', () {
    test('sums the ledger', () {
      final now = DateTime(2026, 1, 1);
      final events = [
        KnotEvent(type: KnotEventType.moodCheckIn, knots: 30, createdAt: now),
        KnotEvent(type: KnotEventType.journalEntry, knots: 40, createdAt: now),
        KnotEvent(
          type: KnotEventType.breathingSession,
          knots: 50,
          createdAt: now,
        ),
      ];
      expect(WellnessStats.totalKnots(events), 120);
    });

    test('is zero for an empty ledger', () {
      expect(WellnessStats.totalKnots(const []), 0);
    });
  });

  group('dailyStreak', () {
    final today = DateTime(2026, 9, 28, 10); // fixed "now"

    test('is zero with no activity', () {
      expect(WellnessStats.dailyStreak(const [], now: today), 0);
    });

    test('counts consecutive days ending today', () {
      final days = [
        DateTime(2026, 9, 28, 8),
        DateTime(2026, 9, 27, 20),
        DateTime(2026, 9, 26, 6),
      ];
      expect(WellnessStats.dailyStreak(days, now: today), 3);
    });

    test('stays live when the latest activity was yesterday', () {
      final days = [DateTime(2026, 9, 27, 9), DateTime(2026, 9, 26, 9)];
      expect(WellnessStats.dailyStreak(days, now: today), 2);
    });

    test('breaks when the latest activity is older than yesterday', () {
      final days = [DateTime(2026, 9, 25, 9), DateTime(2026, 9, 24, 9)];
      expect(WellnessStats.dailyStreak(days, now: today), 0);
    });

    test('dedupes multiple entries on the same day', () {
      final days = [
        DateTime(2026, 9, 28, 8),
        DateTime(2026, 9, 28, 21),
        DateTime(2026, 9, 27, 7),
      ];
      expect(WellnessStats.dailyStreak(days, now: today), 2);
    });
  });

  group('weeklyWaveScores', () {
    final today = DateTime(2026, 9, 28, 12);

    MoodCheckIn mood(MoodState s, DateTime at) => MoodCheckIn(
      state: s,
      sleepQuality: 3,
      seaWeather: 3,
      homesickness: 3,
      createdAt: at,
    );

    test('returns seven buckets, all null when empty', () {
      final scores = WellnessStats.weeklyWaveScores(const [], now: today);
      expect(scores, hasLength(7));
      expect(scores.every((v) => v == null), isTrue);
    });

    test('places today in the last bucket', () {
      final scores = WellnessStats.weeklyWaveScores([
        mood(MoodState.calmSea, today),
      ], now: today);
      expect(scores.last, MoodState.calmSea.waveScore.toDouble());
      // All earlier days remain gaps.
      expect(scores.sublist(0, 6).every((v) => v == null), isTrue);
    });

    test('averages multiple logs on the same day', () {
      final scores = WellnessStats.weeklyWaveScores([
        mood(MoodState.calmSea, today), // 5
        mood(MoodState.choppyWater, today), // 3
      ], now: today);
      expect(scores.last, 4.0);
    });

    test('ignores logs older than the trailing week', () {
      final scores = WellnessStats.weeklyWaveScores([
        mood(MoodState.calmSea, today.subtract(const Duration(days: 9))),
      ], now: today);
      expect(scores.every((v) => v == null), isTrue);
    });
  });

  group('rankAmong', () {
    test('ties resolve in the user favour', () {
      expect(WellnessStats.rankAmong(720, const [850, 780, 650, 590]), 3);
      expect(WellnessStats.rankAmong(900, const [850, 780, 650, 590]), 1);
      expect(WellnessStats.rankAmong(0, const [850, 780, 650, 590]), 5);
      expect(WellnessStats.rankAmong(780, const [850, 780, 650, 590]), 2);
    });
  });
}
