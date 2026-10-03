"""Tiny SQLite persistence layer for the TideWell profile service.

Deliberately uses the Python standard-library ``sqlite3`` module (no ORM) to
keep this at the "basic CRUD service" simplicity level the brief asked for.

The service stores a *single* profile row because the TideWell app has no
login / multi-user system yet. The row is pinned to a fixed primary key so
``PUT /profile`` is a true upsert rather than an ever-growing table.
"""

from __future__ import annotations

import os
import sqlite3
from datetime import datetime, timezone
from typing import Optional

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
    """Create the ``profile`` table if it does not exist."""
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
