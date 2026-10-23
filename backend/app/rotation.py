"""Deterministic weekly content rotation.

Mirrors the Flutter-side `dailyLore()` pattern (see
`lib/screens/story_playback_screen.dart`) but one level up: instead of
rotating a daily window of sleep-lore stories, this rotates a weekly window
of "eligible" built-in games to spotlight as "Featured this week".

The rotation is a pure function of (eligible keys, today's date) — there is
no stored "current week's picks" row to go stale, drift, or need a cron job
to advance. The same calendar week always yields the same window; the window
advances by one key every week and wraps around, so every eligible game gets
fair rotation over a full cycle.
"""

from __future__ import annotations

from datetime import date


def featured_window(
    game_keys: list[str],
    at: date,
    count: int = 2,
) -> list[str]:
    """Pick `count` keys from `game_keys` for the week containing `at`.

    `game_keys` must already be in a stable display order (callers pass the
    `featured_game` table's `sort_order, game_key` ordering) — the rotation
    window walks that fixed order, it doesn't reorder it.

    The week boundary is a plain 7-day cadence from the proleptic Gregorian
    epoch (`date.toordinal() // 7`), not an ISO Mon-Sun week — it only needs
    to be a stable, deterministic 7-day bucket, not calendar-aligned.
    """
    n = len(game_keys)
    if n == 0:
        return []
    week_index = at.toordinal() // 7
    start = week_index % n
    k = min(count, n)
    return [game_keys[(start + i) % n] for i in range(k)]
