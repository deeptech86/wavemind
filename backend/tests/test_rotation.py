"""Unit tests for the deterministic weekly game-rotation function.

Run with:  python -m unittest tests.test_rotation   (from backend/, venv active)
       or:  python -m unittest discover
"""

from __future__ import annotations

import unittest
from datetime import date, timedelta

from app.rotation import featured_window

GAMES = ["calm_your_waves", "knot_master", "sextant_horizon", "cabin_dominoes"]


class FeaturedWindowTests(unittest.TestCase):
    def test_returns_exactly_count_keys(self) -> None:
        picks = featured_window(GAMES, date(2026, 1, 1), count=2)
        self.assertEqual(len(picks), 2)
        for key in picks:
            self.assertIn(key, GAMES)

    def test_stable_within_the_same_week(self) -> None:
        # Anchor on the rotation's actual 7-day bucket boundary (toordinal()//7
        # — not a calendar Monday) so all 7 offsets fall in the same bucket.
        anchor = date(2026, 3, 2)
        week_index = anchor.toordinal() // 7
        bucket_start = date.fromordinal(week_index * 7)
        picks_day1 = featured_window(GAMES, bucket_start, count=2)
        for offset in range(7):
            picks = featured_window(
                GAMES, bucket_start + timedelta(days=offset), count=2
            )
            self.assertEqual(picks, picks_day1)

    def test_rotates_on_the_next_week(self) -> None:
        start = date(2026, 3, 2)
        this_week = featured_window(GAMES, start, count=2)
        next_week = featured_window(GAMES, start + timedelta(days=7), count=2)
        self.assertNotEqual(this_week, next_week)

    def test_every_eligible_game_gets_fair_rotation(self) -> None:
        seen: set[str] = set()
        for week in range(len(GAMES)):
            picks = featured_window(
                GAMES, date(2026, 1, 1) + timedelta(weeks=week), count=2
            )
            seen.update(picks)
        self.assertEqual(seen, set(GAMES))

    def test_window_wraps_around_the_pool(self) -> None:
        # Force start = len(GAMES) - 1 so the window must wrap to index 0.
        # week_index % n == n - 1  <=>  pick a date whose toordinal()//7 % 4 == 3.
        d = date(2026, 1, 1)
        while d.toordinal() // 7 % len(GAMES) != len(GAMES) - 1:
            d += timedelta(days=1)
        picks = featured_window(GAMES, d, count=2)
        self.assertEqual(picks, [GAMES[-1], GAMES[0]])

    def test_count_never_exceeds_pool_size(self) -> None:
        picks = featured_window(GAMES[:1], date(2026, 1, 1), count=2)
        self.assertEqual(picks, GAMES[:1])

    def test_empty_pool_returns_empty(self) -> None:
        self.assertEqual(featured_window([], date(2026, 1, 1)), [])

    def test_excluded_game_never_appears(self) -> None:
        # fog_signal_echo is deliberately absent from the eligible pool callers
        # pass in (see app.seed.ELIGIBLE_FOR_ROTATION) — the function can only
        # ever return keys it was given, so it never sneaks back in.
        for week in range(10):
            picks = featured_window(
                GAMES, date(2026, 1, 1) + timedelta(weeks=week), count=2
            )
            self.assertNotIn("fog_signal_echo", picks)


if __name__ == "__main__":
    unittest.main()
