"""Tiny SQLite persistence layer for the TideWell profile service.

Deliberately uses the Python standard-library ``sqlite3`` module (no ORM) to
keep this at the "basic CRUD service" simplicity level the brief asked for.

The service stores a *single* profile row because the TideWell app has no
login / multi-user system yet. The row is pinned to a fixed primary key so
``PUT /profile`` is a true upsert rather than an ever-growing table.
"""

from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timezone
from typing import Any, Optional

# Store the DB file next to the backend package by default; overridable so
# tests (or a future deployment) can point somewhere else.
DB_PATH = os.environ.get(
    "TIDEWELL_DB_PATH",
    os.path.join(os.path.dirname(os.path.dirname(__file__)), "tidewell.db"),
)

# There is only ever one profile, so we pin it to a constant id.
PROFILE_ID = 1


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create every table if it does not exist.

    Profile is the original single-row identity store. The three ``content_*``
    tables back the rotating content catalog (stories / ambient sounds) plus the
    weekly featured-game flags — all kept in the same plain-``sqlite3`` style.
    """
    with _connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS profile (
                id         INTEGER PRIMARY KEY,
                name       TEXT NOT NULL,
                email      TEXT NOT NULL,
                phone      TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        # A narrated sea story. Media lives on disk (served under /media); only
        # lightweight metadata is stored here. ``excerpt`` is a JSON-encoded list
        # of paragraph strings. Richer presentation (vibe chips, chapter copy)
        # stays client-authored, keyed by this ``id``.
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS content_story (
                id              TEXT PRIMARY KEY,
                title           TEXT NOT NULL,
                series          TEXT NOT NULL DEFAULT '',
                narrator        TEXT NOT NULL DEFAULT '',
                teaser_subtitle TEXT NOT NULL DEFAULT '',
                excerpt         TEXT NOT NULL DEFAULT '[]',
                coordinates     TEXT NOT NULL DEFAULT '',
                swell_note      TEXT NOT NULL DEFAULT '',
                media_path      TEXT NOT NULL,
                duration_label  TEXT NOT NULL DEFAULT '',
                active          INTEGER NOT NULL DEFAULT 1,
                sort_order      INTEGER NOT NULL DEFAULT 0,
                created_at      TEXT NOT NULL,
                updated_at      TEXT NOT NULL
            )
            """
        )
        # A looping ambient soundscape bed.
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS content_sound (
                id         TEXT PRIMARY KEY,
                label      TEXT NOT NULL,
                subtitle   TEXT NOT NULL DEFAULT '',
                media_path TEXT NOT NULL,
                active     INTEGER NOT NULL DEFAULT 1,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        # Which of the five built-in games are "featured" right now. No new game
        # content ever flows through here — only the spotlight flag + ordering.
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS featured_game (
                game_key       TEXT PRIMARY KEY,
                active         INTEGER NOT NULL DEFAULT 0,
                effective_from TEXT NOT NULL DEFAULT '',
                sort_order     INTEGER NOT NULL DEFAULT 0,
                updated_at     TEXT NOT NULL
            )
            """
        )
        conn.commit()


def get_profile() -> Optional[dict]:
    """Return the stored profile as a dict, or ``None`` if nothing saved yet."""
    with _connect() as conn:
        row = conn.execute(
            "SELECT * FROM profile WHERE id = ?", (PROFILE_ID,)
        ).fetchone()
        return dict(row) if row else None


def upsert_profile(name: str, email: str, phone: str) -> dict:
    """Insert or update the single profile row and return the stored result."""
    now = _utc_now_iso()
    with _connect() as conn:
        existing = conn.execute(
            "SELECT created_at FROM profile WHERE id = ?", (PROFILE_ID,)
        ).fetchone()
        created_at = existing["created_at"] if existing else now
        conn.execute(
            """
            INSERT INTO profile (id, name, email, phone, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                email = excluded.email,
                phone = excluded.phone,
                updated_at = excluded.updated_at
            """,
            (PROFILE_ID, name, email, phone, created_at, now),
        )
        conn.commit()
    result = get_profile()
    assert result is not None  # just written
    return result


# ---------------------------------------------------------------------------
# Content catalog — stories
# ---------------------------------------------------------------------------
#
# Each media item carries a ``version`` (its ``updated_at`` stamp) in the
# catalog response. The device caches that stamp so it only re-downloads a file
# when the server-side content actually changes.


def _story_row_to_dict(row: sqlite3.Row) -> dict:
    data = dict(row)
    try:
        data["excerpt"] = json.loads(data.get("excerpt") or "[]")
    except (ValueError, TypeError):
        data["excerpt"] = []
    data["active"] = bool(data["active"])
    return data


def upsert_story(story_id: str, fields: dict[str, Any]) -> dict:
    """Insert or fully replace a story row. ``excerpt`` may be a list."""
    now = _utc_now_iso()
    excerpt = fields.get("excerpt", [])
    if isinstance(excerpt, (list, tuple)):
        excerpt = json.dumps(list(excerpt))
    with _connect() as conn:
        existing = conn.execute(
            "SELECT created_at FROM content_story WHERE id = ?", (story_id,)
        ).fetchone()
        created_at = existing["created_at"] if existing else now
        conn.execute(
            """
            INSERT INTO content_story (
                id, title, series, narrator, teaser_subtitle, excerpt,
                coordinates, swell_note, media_path, duration_label,
                active, sort_order, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                series = excluded.series,
                narrator = excluded.narrator,
                teaser_subtitle = excluded.teaser_subtitle,
                excerpt = excluded.excerpt,
                coordinates = excluded.coordinates,
                swell_note = excluded.swell_note,
                media_path = excluded.media_path,
                duration_label = excluded.duration_label,
                active = excluded.active,
                sort_order = excluded.sort_order,
                updated_at = excluded.updated_at
            """,
            (
                story_id,
                fields.get("title", ""),
                fields.get("series", ""),
                fields.get("narrator", ""),
                fields.get("teaser_subtitle", ""),
                excerpt,
                fields.get("coordinates", ""),
                fields.get("swell_note", ""),
                fields["media_path"],
                fields.get("duration_label", ""),
                1 if fields.get("active", True) else 0,
                int(fields.get("sort_order", 0)),
                created_at,
                now,
            ),
        )
        conn.commit()
    result = get_story(story_id)
    assert result is not None
    return result


def patch_story(story_id: str, fields: dict[str, Any]) -> Optional[dict]:
    """Partially update a story (e.g. flip ``active``). Returns None if absent."""
    allowed = {
        "title", "series", "narrator", "teaser_subtitle", "excerpt",
        "coordinates", "swell_note", "media_path", "duration_label",
        "active", "sort_order",
    }
    sets: list[str] = []
    values: list[Any] = []
    for key, value in fields.items():
        if key not in allowed or value is None:
            continue
        if key == "excerpt" and isinstance(value, (list, tuple)):
            value = json.dumps(list(value))
        if key == "active":
            value = 1 if value else 0
        sets.append(f"{key} = ?")
        values.append(value)
    with _connect() as conn:
        if conn.execute(
            "SELECT 1 FROM content_story WHERE id = ?", (story_id,)
        ).fetchone() is None:
            return None
        if sets:
            sets.append("updated_at = ?")
            values.append(_utc_now_iso())
            values.append(story_id)
            conn.execute(
                f"UPDATE content_story SET {', '.join(sets)} WHERE id = ?",
                values,
            )
            conn.commit()
    return get_story(story_id)


def get_story(story_id: str) -> Optional[dict]:
    with _connect() as conn:
        row = conn.execute(
            "SELECT * FROM content_story WHERE id = ?", (story_id,)
        ).fetchone()
        return _story_row_to_dict(row) if row else None


def list_stories(active_only: bool = False) -> list[dict]:
    where = "WHERE active = 1" if active_only else ""
    with _connect() as conn:
        rows = conn.execute(
            f"SELECT * FROM content_story {where} ORDER BY sort_order, id"
        ).fetchall()
        return [_story_row_to_dict(r) for r in rows]


# ---------------------------------------------------------------------------
# Content catalog — sounds
# ---------------------------------------------------------------------------


def _sound_row_to_dict(row: sqlite3.Row) -> dict:
    data = dict(row)
    data["active"] = bool(data["active"])
    return data


def upsert_sound(sound_id: str, fields: dict[str, Any]) -> dict:
    now = _utc_now_iso()
    with _connect() as conn:
        existing = conn.execute(
            "SELECT created_at FROM content_sound WHERE id = ?", (sound_id,)
        ).fetchone()
        created_at = existing["created_at"] if existing else now
        conn.execute(
            """
            INSERT INTO content_sound (
                id, label, subtitle, media_path, active, sort_order,
                created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                label = excluded.label,
                subtitle = excluded.subtitle,
                media_path = excluded.media_path,
                active = excluded.active,
                sort_order = excluded.sort_order,
                updated_at = excluded.updated_at
            """,
            (
                sound_id,
                fields.get("label", ""),
                fields.get("subtitle", ""),
                fields["media_path"],
                1 if fields.get("active", True) else 0,
                int(fields.get("sort_order", 0)),
                created_at,
                now,
            ),
        )
        conn.commit()
    result = get_sound(sound_id)
    assert result is not None
    return result


def patch_sound(sound_id: str, fields: dict[str, Any]) -> Optional[dict]:
    allowed = {"label", "subtitle", "media_path", "active", "sort_order"}
    sets: list[str] = []
    values: list[Any] = []
    for key, value in fields.items():
        if key not in allowed or value is None:
            continue
        if key == "active":
            value = 1 if value else 0
        sets.append(f"{key} = ?")
        values.append(value)
    with _connect() as conn:
        if conn.execute(
            "SELECT 1 FROM content_sound WHERE id = ?", (sound_id,)
        ).fetchone() is None:
            return None
        if sets:
            sets.append("updated_at = ?")
            values.append(_utc_now_iso())
            values.append(sound_id)
            conn.execute(
                f"UPDATE content_sound SET {', '.join(sets)} WHERE id = ?",
                values,
            )
            conn.commit()
    return get_sound(sound_id)


def get_sound(sound_id: str) -> Optional[dict]:
    with _connect() as conn:
        row = conn.execute(
            "SELECT * FROM content_sound WHERE id = ?", (sound_id,)
        ).fetchone()
        return _sound_row_to_dict(row) if row else None


def list_sounds(active_only: bool = False) -> list[dict]:
    where = "WHERE active = 1" if active_only else ""
    with _connect() as conn:
        rows = conn.execute(
            f"SELECT * FROM content_sound {where} ORDER BY sort_order, id"
        ).fetchall()
        return [_sound_row_to_dict(r) for r in rows]


# ---------------------------------------------------------------------------
# Featured games
# ---------------------------------------------------------------------------


def _game_row_to_dict(row: sqlite3.Row) -> dict:
    data = dict(row)
    data["active"] = bool(data["active"])
    return data


def upsert_featured_game(game_key: str, fields: dict[str, Any]) -> dict:
    now = _utc_now_iso()
    with _connect() as conn:
        conn.execute(
            """
            INSERT INTO featured_game (
                game_key, active, effective_from, sort_order, updated_at
            ) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(game_key) DO UPDATE SET
                active = excluded.active,
                effective_from = excluded.effective_from,
                sort_order = excluded.sort_order,
                updated_at = excluded.updated_at
            """,
            (
                game_key,
                1 if fields.get("active", False) else 0,
                fields.get("effective_from", ""),
                int(fields.get("sort_order", 0)),
                now,
            ),
        )
        conn.commit()
    result = get_featured_game(game_key)
    assert result is not None
    return result


def patch_featured_game(game_key: str, fields: dict[str, Any]) -> Optional[dict]:
    allowed = {"active", "effective_from", "sort_order"}
    sets: list[str] = []
    values: list[Any] = []
    for key, value in fields.items():
        if key not in allowed or value is None:
            continue
        if key == "active":
            value = 1 if value else 0
        sets.append(f"{key} = ?")
        values.append(value)
    with _connect() as conn:
        if conn.execute(
            "SELECT 1 FROM featured_game WHERE game_key = ?", (game_key,)
        ).fetchone() is None:
            return None
        if sets:
            sets.append("updated_at = ?")
            values.append(_utc_now_iso())
            values.append(game_key)
            conn.execute(
                f"UPDATE featured_game SET {', '.join(sets)} WHERE game_key = ?",
                values,
            )
            conn.commit()
    return get_featured_game(game_key)


def get_featured_game(game_key: str) -> Optional[dict]:
    with _connect() as conn:
        row = conn.execute(
            "SELECT * FROM featured_game WHERE game_key = ?", (game_key,)
        ).fetchone()
        return _game_row_to_dict(row) if row else None


def list_featured_games(active_only: bool = False) -> list[dict]:
    where = "WHERE active = 1" if active_only else ""
    with _connect() as conn:
        rows = conn.execute(
            f"SELECT * FROM featured_game {where} ORDER BY sort_order, game_key"
        ).fetchall()
        return [_game_row_to_dict(r) for r in rows]


def content_counts() -> dict:
    """Row counts per content table — used by startup seeding to decide whether
    the day-one data still needs to be inserted."""
    with _connect() as conn:
        return {
            "stories": conn.execute(
                "SELECT COUNT(*) AS c FROM content_story"
            ).fetchone()["c"],
            "sounds": conn.execute(
                "SELECT COUNT(*) AS c FROM content_sound"
            ).fetchone()["c"],
            "games": conn.execute(
                "SELECT COUNT(*) AS c FROM featured_game"
            ).fetchone()["c"],
        }


def clear_content() -> None:
    """Wipe all catalog tables (used by ``seed --force``)."""
    with _connect() as conn:
        conn.execute("DELETE FROM content_story")
        conn.execute("DELETE FROM content_sound")
        conn.execute("DELETE FROM featured_game")
        conn.commit()
