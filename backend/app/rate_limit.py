"""A small, dependency-free fixed-window rate limiter.

Deliberately stdlib-only (``threading`` + a plain dict), consistent with this
backend's "small, no extra dependencies" style (see ``app.auth``) — no
``slowapi`` / Redis needed for a single-process dev-scale service.

Scoped by an arbitrary string key (the caller passes whatever it wants to
throttle independently — e.g. one bucket per client IP) so unrelated callers
never share a budget. Pure and side-effect-free beyond its own internal
state, so it's directly unit-testable without the FastAPI app or a DB.
"""

from __future__ import annotations

import threading
import time


class RateLimiter:
    """Allows at most ``max_hits`` calls to :meth:`allow` per key within a
    rolling ``window_seconds`` window; the window resets per key once it
    elapses (a plain fixed window, not a sliding one — adequate for
    throttling brute-force attempts, not a precision traffic-shaping tool).

    Thread-safe: ``uvicorn --reload``'s dev server is single-process but can
    still serve requests concurrently across threads/async tasks.
    """

    def __init__(self, max_hits: int, window_seconds: float) -> None:
        self.max_hits = max_hits
        self.window_seconds = window_seconds
        self._lock = threading.Lock()
        # key -> (window_start_monotonic, hits_in_window)
        self._state: dict[str, tuple[float, int]] = {}

    def allow(self, key: str, *, now: float | None = None) -> bool:
        """Records one hit for ``key`` and returns whether it's within the
        limit. Always records — even a rejected call counts, so a caller
        hammering the endpoint doesn't get to keep probing for free."""
        t = now if now is not None else time.monotonic()
        with self._lock:
            start, hits = self._state.get(key, (t, 0))
            if t - start >= self.window_seconds:
                start, hits = t, 0
            hits += 1
            self._state[key] = (start, hits)
            return hits <= self.max_hits

    def reset(self, key: str) -> None:
        """Clears a key's window — e.g. after a successful login, so a
        legitimate user who mistyped their password a few times isn't left
        throttled by their own earlier failed attempts."""
        with self._lock:
            self._state.pop(key, None)
