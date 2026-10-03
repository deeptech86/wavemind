import 'models/knot_event.dart';
import 'models/mood_check_in.dart';

/// Pure, database-free computations over persisted wellness data.
///
/// Kept free of any `sqflite` / IO dependency so they can be unit-tested
/// directly and reused across screens (Crew contribution card, Weekly Insights).
abstract final class WellnessStats {
  /// Number of trailing days shown on the Weekly Emotional Wave chart.
  static const int weekLength = 7;

  /// Strip a timestamp down to its calendar day (local time).
  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Total Fleet Knots == the sum of every ledger entry (always derivable).
  static int totalKnots(Iterable<KnotEvent> events) =>
      events.fold(0, (sum, e) => sum + e.knots);

  /// Longest run of consecutive calendar days, counting back from today, on
  /// which at least one of [timestamps] falls.
  ///
  /// The streak is considered "live" if there is activity today **or**
  /// yesterday (so a streak isn't broken until a full day is missed). If the
  /// most recent activity is older than yesterday, the streak is 0.
  static int dailyStreak(Iterable<DateTime> timestamps, {DateTime? now}) {
    final today = dayOf(now ?? DateTime.now());
    final days = timestamps.map(dayOf).toSet();
    if (days.isEmpty) return 0;

    // Anchor on today if active today, else yesterday, else no live streak.
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime cursor;
    if (days.contains(today)) {
      cursor = today;
    } else if (days.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// A [weekLength]-long list of average mood wave-scores for the trailing week.
  ///
  /// Index 0 is the oldest day (6 days ago) and the last index is today. A day
  /// with no logged mood is `null` (an unplotted gap), letting the chart draw a
  /// sensible sparse / empty state rather than fabricating data.
  static List<double?> weeklyWaveScores(
    Iterable<MoodCheckIn> moods, {
    DateTime? now,
  }) {
    final today = dayOf(now ?? DateTime.now());
    final buckets = List.generate(weekLength, (_) => <int>[]);
    for (final m in moods) {
      final diff = today.difference(dayOf(m.createdAt)).inDays;
      if (diff >= 0 && diff < weekLength) {
        // diff 0 == today -> last bucket; diff 6 == oldest -> first bucket.
        buckets[weekLength - 1 - diff].add(m.state.waveScore);
      }
    }
    return [
      for (final bucket in buckets)
        if (bucket.isEmpty)
          null
        else
          bucket.reduce((a, b) => a + b) / bucket.length,
    ];
  }

  /// The user's leaderboard rank given their real [userKnots] and the fixed
  /// knot totals of the static mock competitors. Ties resolve in the user's
  /// favour (rank == number of competitors strictly ahead + 1).
  static int rankAmong(int userKnots, Iterable<int> competitorKnots) {
    final ahead = competitorKnots.where((k) => k > userKnots).length;
    return ahead + 1;
  }
}
