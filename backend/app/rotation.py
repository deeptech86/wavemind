"""Random-but-deterministic weekly content rotation.

Mirrors the Flutter-side `dailyLore()` pattern (see
`lib/screens/story_playback_screen.dart`) but one level up: instead of
rotating a daily window of sleep-lore stories, this picks a weekly, randomly
shuffled window of "eligible" built-in games to spotlight as "Featured this
week" — and, now that the client actually hides anything not in this window
(rather than just sorting it first), this window **is** the full set of
games a player can see and play that week.

The rotation is a pure function of (eligible keys, today's date) — there is
no stored "current week's picks" row to go stale, drift, or need a cron job
to advance. The same calendar week always yields the same picks (stable for
every device/user that week), but — unlike a plain round-robin walk — which
`count` keys come up is a genuine shuffle of the pool each week, so it
doesn't visibly cycle through a fixed sequence.
"""

from __future__ import annotations

import random
from datetime import date


def featured_window(
    game_keys: list[str],
    at: date,
    count: int = 2,
) -> list[str]:
    """Randomly picks `count` keys from `game_keys` for the week containing
    `at`, seeded by that week so the pick is stable within the week.

    The week boundary is a plain 7-day cadence from the proleptic Gregorian
    epoch (`date.toordinal() // 7`), not an ISO Mon-Sun week — it only needs
    to be a stable, deterministic 7-day bucket, not calendar-aligned.
    """
    n = len(game_keys)
    if n == 0:
        return []
    week_index = at.toordinal() // 7
    shuffled = list(game_keys)
    random.Random(week_index).shuffle(shuffled)
    return shuffled[: min(count, n)]
