"""Unit tests for the random-but-deterministic weekly game-rotation function.

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
        self.assertEqual(len(set(picks)), 2)  # no duplicate within one week
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

    def test_picks_vary_across_weeks(self) -> None:
        # A genuine shuffle doesn't guarantee any *particular* pair of
        # consecutive weeks differs (with 4 games choose 2, a repeat by
        # chance isn't vanishingly rare) — so check a decent run of weeks
        # sees more than one distinct combination, rather than asserting any
        # single week-over-week comparison.
        start = date(2026, 1, 1)
        combos = {
            tuple(featured_window(GAMES, start + timedelta(weeks=w), count=2))
            for w in range(20)
        }
        self.assertGreater(len(combos), 1)

    def test_every_eligible_game_gets_fair_rotation_over_many_weeks(self) -> None:
        seen: set[str] = set()
        for week in range(200):
            picks = featured_window(
                GAMES, date(2026, 1, 1) + timedelta(weeks=week), count=2
            )
            seen.update(picks)
        self.assertEqual(seen, set(GAMES))

    def test_count_never_exceeds_pool_size(self) -> None:
        picks = featured_window(GAMES[:1], date(2026, 1, 1), count=2)
        self.assertEqual(picks, GAMES[:1])

    def test_empty_pool_returns_empty(self) -> None:
        self.assertEqual(featured_window([], date(2026, 1, 1)), [])

    def test_excluded_game_never_appears(self) -> None:
        # fog_signal_echo is just never in this test's GAMES pool — the
        # function can only ever return keys it was given, so a key missing
        # from the input never sneaks back into the picks.
        for week in range(10):
            picks = featured_window(
                GAMES, date(2026, 1, 1) + timedelta(weeks=week), count=2
            )
            self.assertNotIn("fog_signal_echo", picks)


if __name__ == "__main__":
    unittest.main()
