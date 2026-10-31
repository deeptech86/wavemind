"""Unit tests for the stdlib-only fixed-window rate limiter.

Run with:  python -m unittest tests.test_rate_limit   (from backend/, venv active)
       or:  python -m unittest discover
"""

from __future__ import annotations

import unittest

from app.rate_limit import RateLimiter


class RateLimiterTests(unittest.TestCase):
    def test_allows_up_to_max_hits_then_blocks(self) -> None:
        limiter = RateLimiter(max_hits=3, window_seconds=60)
        self.assertTrue(limiter.allow("1.2.3.4", now=0))
        self.assertTrue(limiter.allow("1.2.3.4", now=1))
        self.assertTrue(limiter.allow("1.2.3.4", now=2))
        self.assertFalse(limiter.allow("1.2.3.4", now=3))  # 4th within window
        self.assertFalse(limiter.allow("1.2.3.4", now=4))  # still blocked

    def test_keys_are_independent(self) -> None:
        limiter = RateLimiter(max_hits=1, window_seconds=60)
        self.assertTrue(limiter.allow("alice", now=0))
        self.assertFalse(limiter.allow("alice", now=0))
        # A different key has its own budget, unaffected by alice's.
        self.assertTrue(limiter.allow("bob", now=0))

    def test_window_resets_after_it_elapses(self) -> None:
        limiter = RateLimiter(max_hits=2, window_seconds=60)
        self.assertTrue(limiter.allow("1.2.3.4", now=0))
        self.assertTrue(limiter.allow("1.2.3.4", now=1))
        self.assertFalse(limiter.allow("1.2.3.4", now=2))  # exhausted

        # Just before the window elapses: still blocked.
        self.assertFalse(limiter.allow("1.2.3.4", now=59.9))
        # Window has elapsed: fresh budget.
        self.assertTrue(limiter.allow("1.2.3.4", now=60))
        self.assertTrue(limiter.allow("1.2.3.4", now=60))
        self.assertFalse(limiter.allow("1.2.3.4", now=60))

    def test_reset_clears_a_keys_window(self) -> None:
        limiter = RateLimiter(max_hits=1, window_seconds=60)
        self.assertTrue(limiter.allow("1.2.3.4", now=0))
        self.assertFalse(limiter.allow("1.2.3.4", now=1))
        limiter.reset("1.2.3.4")
        self.assertTrue(limiter.allow("1.2.3.4", now=2))  # fresh budget

    def test_reset_is_a_no_op_for_an_unknown_key(self) -> None:
        limiter = RateLimiter(max_hits=1, window_seconds=60)
        limiter.reset("never-seen")  # must not raise


if __name__ == "__main__":
    unittest.main()
