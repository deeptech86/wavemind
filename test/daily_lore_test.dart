import 'package:flutter_test/flutter_test.dart';

import 'package:tidewell_app/screens/story_playback_screen.dart';

void main() {
  group('dailyLore', () {
    test('returns exactly `count` stories from the catalog', () {
      final todays = dailyLore(DateTime(2026, 1, 1), SeaStories.all);
      expect(todays.length, 2);
    });

    test('is stable across the same local calendar day', () {
      final morning = dailyLore(DateTime(2026, 3, 5, 0, 1), SeaStories.all);
      final night = dailyLore(DateTime(2026, 3, 5, 23, 59), SeaStories.all);
      expect(morning.map((s) => s.title), night.map((s) => s.title));
    });

    test('rotates to a different window on consecutive days', () {
      final day1 = dailyLore(DateTime(2026, 3, 5), SeaStories.all);
      final day2 = dailyLore(DateTime(2026, 3, 6), SeaStories.all);
      expect(day1.map((s) => s.title), isNot(day2.map((s) => s.title)));
    });

    test('every story gets fair rotation over a full cycle', () {
      final seen = <String>{};
      for (var i = 0; i < SeaStories.all.length; i++) {
        final day = dailyLore(DateTime(2026, 1, 1 + i), SeaStories.all);
        seen.add(day.first.title);
      }
      expect(seen.length, SeaStories.all.length);
    });

    test('never returns more than the catalog holds', () {
      final todays = dailyLore(
        DateTime(2026, 1, 1),
        [SeaStories.lighthouse],
        count: 2,
      );
      expect(todays.length, 1);
    });

    test('returns nothing for an empty catalog', () {
      expect(dailyLore(DateTime(2026, 1, 1), const []), isEmpty);
    });
  });
}
