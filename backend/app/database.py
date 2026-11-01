"""Tiny SQLite persistence layer for the Wavemind backend.

Deliberately uses the Python standard-library ``sqlite3`` module (no ORM) to
keep this at the "basic CRUD service" simplicity level the brief asked for.

Backs three concerns, all in the same plain-``sqlite3`` style:
    * **Accounts** — a real multi-user ``user`` table plus opaque bearer
      ``session`` tokens (the login/signup foundation).
    * **Content catalog** — rotating stories / ambient sounds / featured games.

The original single-row ``profile`` table (name/email/phone) has been
**retired**: it was a placeholder built before any accounts system existed, and
is fully superseded by the ``user`` table below. Nothing reads or writes it any
more, so its CREATE statement and helpers were removed; an existing DB may still
carry a stale ``profile`` table, which is simply ignored.
"""

from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

# Store the DB file next to the backend package by default; overridable so
# tests (or a future deployment) can point somewhere else.
DB_PATH = os.environ.get(
    "WAVEMIND_DB_PATH",
    os.path.join(os.path.dirname(os.path.dirname(__file__)), "wavemind.db"),
)

# Long-lived sessions: there is no refresh-token flow in this pass, so a single
# 30-day opaque token is acceptable (re-login once it lapses).
SESSION_TTL = timedelta(days=30)


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create every table if it does not exist.

    ``user`` + ``session`` back the accounts system (login/signup). The three
    ``content_*`` tables back the rotating content catalog (stories / ambient
    sounds) plus the weekly featured-game flags — all kept in the same
    plain-``sqlite3`` style.
    """
    with _connect() as conn:
        # Accounts. ``email`` is the login identifier (unique). The password is
        # stored only as a PBKDF2 hash + per-user salt (see app.auth); plaintext
        # never touches the DB. ``sex`` is a free-ish string on purpose — it is
        # sensitive personal data and not worth over-constraining with an enum.
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS user (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                name          TEXT NOT NULL,
                email         TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                password_salt TEXT NOT NULL,
                age           INTEGER NOT NULL,
                sex           TEXT NOT NULL,
                fleet_name    TEXT,
                total_points  INTEGER NOT NULL DEFAULT 0,
                latest_mood_state TEXT,
                latest_mood_at    TEXT,
                suspended_until   TEXT,
                created_at    TEXT NOT NULL,
                updated_at    TEXT NOT NULL
            )
            """
        )
        # A pre-existing dev DB predates these columns — add them in place.
        # ``CREATE TABLE IF NOT EXISTS`` above only covers a fresh DB.
        for ddl in (
            "ALTER TABLE user ADD COLUMN total_points INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE user ADD COLUMN latest_mood_state TEXT",
            "ALTER TABLE user ADD COLUMN latest_mood_at TEXT",
            "ALTER TABLE user ADD COLUMN suspended_until TEXT",
        ):
            try:
                conn.execute(ddl)
            except sqlite3.OperationalError:
                pass  # column already exists
        # Opaque bearer sessions. One row per successful login/signup; deleted
        # on logout and ignored once ``expires_at`` has passed.
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS session (
                token      TEXT PRIMARY KEY,
                user_id    INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES user (id) ON DELETE CASCADE
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
        # The shared "cast a float bottle" crew messages — an append-only
        # log pruned to the latest CREW_MESSAGE_LIMIT rows on every cast
        # (see set_crew_message), newest first. Attributed to the real
        # account at cast time (author_id drives flag-triggered suspension;
        # author_name is just the display string).
        old_schema = conn.execute(
            "SELECT sql FROM sqlite_master "
            "WHERE type = 'table' AND name = 'crew_message'"
        ).fetchone()
        if old_schema and "CHECK (id = 1)" in old_schema["sql"]:
            # Pre-existing dev DB predates the multi-message design (it had
            # a single pinned row) — migrate its one message across rather
            # than discarding it.
            conn.execute("ALTER TABLE crew_message RENAME TO crew_message_old")
            conn.execute(
                """
                CREATE TABLE crew_message (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    body        TEXT NOT NULL,
                    author_name TEXT NOT NULL DEFAULT '',
                    author_id   INTEGER,
                    posted_at   TEXT NOT NULL
                )
                """
            )
            conn.execute(
                "INSERT INTO crew_message (body, author_name, posted_at) "
                "SELECT body, author_name, posted_at FROM crew_message_old"
            )
            conn.execute("DROP TABLE crew_message_old")
        else:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS crew_message (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    body        TEXT NOT NULL,
                    author_name TEXT NOT NULL DEFAULT '',
                    author_id   INTEGER,
                    posted_at   TEXT NOT NULL
                )
                """
            )
            # A dev DB may already have the multi-row shape from before
            # author_id existed.
            try:
                conn.execute("ALTER TABLE crew_message ADD COLUMN author_id INTEGER")
            except sqlite3.OperationalError:
                pass  # column already exists
        # One row per (message, distinct flagger) — the primary key is what
        # makes "different users" enforcement free: a second flag from the
        # same user on the same message is just ignored.
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS crew_message_flag (
                message_id INTEGER NOT NULL,
                user_id    INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                PRIMARY KEY (message_id, user_id)
            )
            """
        )
        conn.commit()


# ---------------------------------------------------------------------------
# Accounts — users
# ---------------------------------------------------------------------------
#
# Callers (app.main) hash the password via app.auth before handing it here; this
# layer only persists the already-derived hash + salt. ``public_user`` strips
# the credential columns for anything that leaves the server.


def _user_row_to_dict(row: sqlite3.Row) -> dict:
    return dict(row)


def public_user(row: dict) -> dict:
    """Project a user row to the shape the API returns — never the hash/salt."""
    return {
        "id": row["id"],
        "name": row["name"],
        "email": row["email"],
        "age": row["age"],
        "sex": row["sex"],
        "fleet_name": row["fleet_name"],
        "created_at": row["created_at"],
    }


def get_user_by_email(email: str) -> Optional[dict]:
    with _connect() as conn:
        row = conn.execute(
            "SELECT * FROM user WHERE email = ?", (email,)
        ).fetchone()
        return _user_row_to_dict(row) if row else None


def get_user_by_id(user_id: int) -> Optional[dict]:
    with _connect() as conn:
        row = conn.execute(
            "SELECT * FROM user WHERE id = ?", (user_id,)
        ).fetchone()
        return _user_row_to_dict(row) if row else None


def create_user(
    *,
    name: str,
    email: str,
    password_hash: str,
    password_salt: str,
    age: int,
    sex: str,
    fleet_name: Optional[str],
) -> dict:
    """Insert a new user row and return it. Raises ``sqlite3.IntegrityError``
    if the email is already taken (callers translate that to HTTP 409)."""
    now = _utc_now_iso()
    with _connect() as conn:
        cursor = conn.execute(
            """
            INSERT INTO user (
                name, email, password_hash, password_salt,
                age, sex, fleet_name, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                name,
                email,
                password_hash,
                password_salt,
                age,
                sex,
                fleet_name,
                now,
                now,
            ),
        )
        conn.commit()
        user_id = int(cursor.lastrowid)
    result = get_user_by_id(user_id)
    assert result is not None  # just written
    return result


def update_user(user_id: int, fields: dict[str, Any]) -> Optional[dict]:
    """Partially update a user's editable profile fields. Returns the updated
    row, or ``None`` if the user does not exist."""
    allowed = {"name", "age", "sex", "fleet_name"}
    sets: list[str] = []
    values: list[Any] = []
    for key, value in fields.items():
        if key not in allowed:
            continue
        sets.append(f"{key} = ?")
        values.append(value)
    with _connect() as conn:
        if conn.execute(
            "SELECT 1 FROM user WHERE id = ?", (user_id,)
        ).fetchone() is None:
            return None
        if sets:
            sets.append("updated_at = ?")
            values.append(_utc_now_iso())
            values.append(user_id)
            conn.execute(
                f"UPDATE user SET {', '.join(sets)} WHERE id = ?", values
            )
            conn.commit()
    return get_user_by_id(user_id)


# ---------------------------------------------------------------------------
# Accounts — leaderboard points
# ---------------------------------------------------------------------------
#
# ``total_points`` mirrors the device's local Fleet Knots ledger total (the
# device is the source of truth for *how* points were earned; the backend
# only ever sees the running total, pushed wholesale on each sync — never a
# delta). This is what makes real, multi-user ranking possible at all.


def set_user_points(user_id: int, total_points: int) -> Optional[dict]:
    """Overwrite the caller's points total. Returns the updated row, or
    ``None`` if the user does not exist."""
    with _connect() as conn:
        if conn.execute(
            "SELECT 1 FROM user WHERE id = ?", (user_id,)
        ).fetchone() is None:
            return None
        conn.execute(
            "UPDATE user SET total_points = ?, updated_at = ? WHERE id = ?",
            (total_points, _utc_now_iso(), user_id),
        )
        conn.commit()
    return get_user_by_id(user_id)


def leaderboard_top(limit: int) -> list[dict]:
    """The top ``limit`` users by points, highest first. Ties break on id (so
    the order is stable) — earliest-registered account wins a tie."""
    with _connect() as conn:
        rows = conn.execute(
            "SELECT * FROM user ORDER BY total_points DESC, id ASC LIMIT ?",
            (limit,),
        ).fetchall()
        return [_user_row_to_dict(r) for r in rows]


def user_rank(user_id: int) -> int:
    """1-indexed rank among all accounts by points — the count of users
    strictly ahead, plus one. A user with no points data yet ranks last."""
    with _connect() as conn:
        row = conn.execute(
            """
            SELECT 1 + (
                SELECT COUNT(*) FROM user
                WHERE total_points > (SELECT total_points FROM user WHERE id = ?)
            ) AS rank
            """,
            (user_id,),
        ).fetchone()
        return int(row["rank"]) if row else 1


# ---------------------------------------------------------------------------
# Accounts — crew mood (Anchor Pool "Anonymized Crew Swell" card)
# ---------------------------------------------------------------------------
#
# The five mood keys below mirror ``MoodState`` in
# lib/data/models/mood_state.dart — keep the two lists in sync. "Calm" here
# means the two calmest states (waveScore 4-5); everything aggregated is a
# per-account *latest* mood only, never a history, and never attributed to a
# name in any response — the summary is a pure anonymous percentage.
MOOD_STATE_KEYS = (
    "calm_sea",
    "gentle_swell",
    "choppy_water",
    "drifting",
    "high_storm",
)
_CALM_MOOD_KEYS = ("calm_sea", "gentle_swell")


def set_user_mood(user_id: int, state: str) -> Optional[dict]:
    """Overwrite the caller's latest mood state. Returns the updated row, or
    ``None`` if the user does not exist."""
    with _connect() as conn:
        if conn.execute(
            "SELECT 1 FROM user WHERE id = ?", (user_id,)
        ).fetchone() is None:
            return None
        conn.execute(
            "UPDATE user SET latest_mood_state = ?, latest_mood_at = ? "
            "WHERE id = ?",
            (state, _utc_now_iso(), user_id),
        )
        conn.commit()
    return get_user_by_id(user_id)


def crew_mood_summary() -> dict:
    """Anonymous aggregate across every account's latest logged mood: what
    fraction currently reads "calm", and how many accounts have logged a
    mood at all (accounts that never have are excluded, not counted as
    non-calm)."""
    placeholders = ",".join("?" for _ in _CALM_MOOD_KEYS)
    with _connect() as conn:
        total = conn.execute(
            "SELECT COUNT(*) AS n FROM user WHERE latest_mood_state IS NOT NULL"
        ).fetchone()["n"]
        calm = conn.execute(
            f"SELECT COUNT(*) AS n FROM user "
            f"WHERE latest_mood_state IN ({placeholders})",
            _CALM_MOOD_KEYS,
        ).fetchone()["n"]
    percent = round(100 * calm / total) if total else 0
    return {"calm_percent": percent, "total_logged": total}


# ---------------------------------------------------------------------------
# Crew message — the shared "cast a float bottle" notes, plus moderation
# ---------------------------------------------------------------------------


# Only the latest CREW_MESSAGE_LIMIT casts are ever kept — casting a new one
# bumps everything else down a slot, and the oldest falls off past this.
CREW_MESSAGE_LIMIT = 3

# More than this many *distinct* accounts flagging the same message suspends
# its author from casting for SUSPENSION_DAYS. "More than 5" == 6th flag.
FLAG_SUSPEND_THRESHOLD = 5
SUSPENSION_DAYS = 30


def set_crew_message(body: str, author_name: str, author_id: int) -> dict:
    """Append a newly cast crew message, then prune down to the latest
    [CREW_MESSAGE_LIMIT] (and drop flags on whatever just aged out) — the
    rest just age out, there is no separate delete step."""
    now = _utc_now_iso()
    with _connect() as conn:
        cursor = conn.execute(
            "INSERT INTO crew_message (body, author_name, author_id, posted_at) "
            "VALUES (?, ?, ?, ?)",
            (body, author_name, author_id, now),
        )
        new_id = cursor.lastrowid
        conn.execute(
            """
            DELETE FROM crew_message WHERE id NOT IN (
                SELECT id FROM crew_message ORDER BY id DESC LIMIT ?
            )
            """,
            (CREW_MESSAGE_LIMIT,),
        )
        conn.execute(
            "DELETE FROM crew_message_flag WHERE message_id NOT IN "
            "(SELECT id FROM crew_message)"
        )
        conn.commit()
    return {"id": new_id, "body": body, "author_name": author_name, "posted_at": now}


def get_crew_messages(limit: int = CREW_MESSAGE_LIMIT) -> list[dict]:
    """The latest [limit] crew messages, newest first. Empty if no one has
    cast one yet."""
    with _connect() as conn:
        rows = conn.execute(
            "SELECT id, body, author_name, posted_at FROM crew_message "
            "ORDER BY id DESC LIMIT ?",
            (limit,),
        ).fetchall()
        return [
            {
                "id": r["id"],
                "body": r["body"],
                "author_name": r["author_name"],
                "posted_at": r["posted_at"],
            }
            for r in rows
        ]


def crew_messages_flagged_by(message_ids: list[int], user_id: int) -> set[int]:
    """Which of [message_ids] the caller has already flagged — lets the UI
    disable the flag button on ones they've already flagged."""
    if not message_ids:
        return set()
    placeholders = ",".join("?" for _ in message_ids)
    with _connect() as conn:
        rows = conn.execute(
            f"SELECT message_id FROM crew_message_flag "
            f"WHERE user_id = ? AND message_id IN ({placeholders})",
            (user_id, *message_ids),
        ).fetchall()
        return {r["message_id"] for r in rows}


def is_user_suspended(user_row: dict) -> bool:
    """Whether [user_row]'s casting suspension is currently in effect."""
    until = user_row.get("suspended_until")
    if not until:
        return False
    try:
        return datetime.fromisoformat(until) > datetime.now(timezone.utc)
    except ValueError:
        return False


def flag_crew_message(message_id: int, user_id: int) -> Optional[dict]:
    """Record [user_id]'s flag on [message_id] — a no-op if they already
    flagged it (the composite primary key dedupes, giving "distinct users"
    semantics for free). Once a message has been flagged by more than
    [FLAG_SUSPEND_THRESHOLD] distinct accounts, its author is suspended
    from casting for [SUSPENSION_DAYS] — applied once, not reset by every
    further flag past the threshold. Returns ``None`` if the message
    doesn't exist (e.g. it already aged out past the 3-message cap).
    """
    with _connect() as conn:
        msg = conn.execute(
            "SELECT id, author_id FROM crew_message WHERE id = ?", (message_id,)
        ).fetchone()
        if msg is None:
            return None
        conn.execute(
            "INSERT OR IGNORE INTO crew_message_flag "
            "(message_id, user_id, created_at) VALUES (?, ?, ?)",
            (message_id, user_id, _utc_now_iso()),
        )
        count = conn.execute(
            "SELECT COUNT(*) AS n FROM crew_message_flag WHERE message_id = ?",
            (message_id,),
        ).fetchone()["n"]
        author_id = msg["author_id"]
        suspended = count > FLAG_SUSPEND_THRESHOLD and author_id is not None
        if suspended:
            author = conn.execute(
                "SELECT suspended_until FROM user WHERE id = ?", (author_id,)
            ).fetchone()
            if author is not None and not is_user_suspended(dict(author)):
                until = (
                    datetime.now(timezone.utc) + timedelta(days=SUSPENSION_DAYS)
                ).isoformat()
                conn.execute(
                    "UPDATE user SET suspended_until = ? WHERE id = ?",
                    (until, author_id),
                )
        conn.commit()
    return {"flag_count": count, "author_suspended": suspended}


# ---------------------------------------------------------------------------
# Accounts — sessions
# ---------------------------------------------------------------------------


def create_session(token: str, user_id: int) -> dict:
    """Persist a new session for ``user_id`` and return it."""
    now = datetime.now(timezone.utc)
    expires = now + SESSION_TTL
    with _connect() as conn:
        conn.execute(
            """
            INSERT INTO session (token, user_id, created_at, expires_at)
            VALUES (?, ?, ?, ?)
            """,
            (token, user_id, now.isoformat(), expires.isoformat()),
        )
        conn.commit()
    return {
        "token": token,
        "user_id": user_id,
        "created_at": now.isoformat(),
        "expires_at": expires.isoformat(),
    }


def get_user_for_token(token: str) -> Optional[dict]:
    """Resolve a bearer token to its (non-expired) user row.

    Returns ``None`` for an unknown token; also deletes and returns ``None`` for
    an expired one so the table self-prunes as stale tokens are presented.
    """
    with _connect() as conn:
        row = conn.execute(
            "SELECT user_id, expires_at FROM session WHERE token = ?", (token,)
        ).fetchone()
        if row is None:
            return None
        try:
            expires_at = datetime.fromisoformat(row["expires_at"])
        except (ValueError, TypeError):
            expires_at = None
        if expires_at is None or expires_at <= datetime.now(timezone.utc):
            conn.execute("DELETE FROM session WHERE token = ?", (token,))
            conn.commit()
            return None
        user_id = row["user_id"]
    return get_user_by_id(user_id)


def delete_session(token: str) -> None:
    """Delete a session row (logout). A no-op if the token is unknown."""
    with _connect() as conn:
        conn.execute("DELETE FROM session WHERE token = ?", (token,))
        conn.commit()


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
