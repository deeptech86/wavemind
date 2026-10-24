"""Unit tests for the crew mood-summary and shared crew-message helpers in
``app.database``.

Run with:  python -m unittest tests.test_crew   (from backend/, venv active)
       or:  python -m unittest discover
"""

from __future__ import annotations

import os
import tempfile
import unittest

from app import database


class _DbTestCase(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        tmp.close()
        self._tmp_path = tmp.name
        self._original_db_path = database.DB_PATH
        database.DB_PATH = self._tmp_path
        database.init_db()

    def tearDown(self) -> None:
        database.DB_PATH = self._original_db_path
        os.unlink(self._tmp_path)

    def _make_user(self, name: str) -> dict:
        return database.create_user(
            name=name,
            email=f"{name.lower()}@example.com",
            password_hash="hash",
            password_salt="salt",
            age=30,
            sex="sailor",
            fleet_name=None,
        )


class CrewMoodTests(_DbTestCase):
    def test_new_user_has_no_mood_logged(self) -> None:
        user = self._make_user("Alice")
        self.assertIsNone(user["latest_mood_state"])

    def test_set_user_mood_persists_state_and_timestamp(self) -> None:
        user = self._make_user("Alice")
        updated = database.set_user_mood(user["id"], "calm_sea")
        self.assertEqual(updated["latest_mood_state"], "calm_sea")
        self.assertIsNotNone(updated["latest_mood_at"])

    def test_set_user_mood_unknown_user_returns_none(self) -> None:
        self.assertIsNone(database.set_user_mood(999999, "calm_sea"))

    def test_summary_excludes_accounts_that_never_logged(self) -> None:
        a = self._make_user("Alice")
        self._make_user("Bob")  # never logs a mood
        database.set_user_mood(a["id"], "calm_sea")
        summary = database.crew_mood_summary()
        self.assertEqual(summary["total_logged"], 1)
        self.assertEqual(summary["calm_percent"], 100)

    def test_summary_counts_calm_sea_and_gentle_swell_as_calm(self) -> None:
        a = self._make_user("Alice")
        b = self._make_user("Bob")
        c = self._make_user("Cara")
        d = self._make_user("Dax")
        database.set_user_mood(a["id"], "calm_sea")
        database.set_user_mood(b["id"], "gentle_swell")
        database.set_user_mood(c["id"], "choppy_water")
        database.set_user_mood(d["id"], "high_storm")
        summary = database.crew_mood_summary()
        self.assertEqual(summary["total_logged"], 4)
        self.assertEqual(summary["calm_percent"], 50)

    def test_summary_with_no_logged_moods_is_zero_not_a_crash(self) -> None:
        summary = database.crew_mood_summary()
        self.assertEqual(summary, {"calm_percent": 0, "total_logged": 0})

    def test_a_later_mood_overwrites_the_earlier_one(self) -> None:
        user = self._make_user("Alice")
        database.set_user_mood(user["id"], "high_storm")
        database.set_user_mood(user["id"], "calm_sea")
        summary = database.crew_mood_summary()
        self.assertEqual(summary, {"calm_percent": 100, "total_logged": 1})


class CrewMessageTests(_DbTestCase):
    def test_no_message_cast_yet_returns_empty(self) -> None:
        self.assertEqual(database.get_crew_messages(), [])

    def test_set_crew_message_round_trips(self) -> None:
        database.set_crew_message("Fair winds to the night watch.", "Marcus Thorne")
        messages = database.get_crew_messages()
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]["body"], "Fair winds to the night watch.")
        self.assertEqual(messages[0]["author_name"], "Marcus Thorne")
        self.assertIsNotNone(messages[0]["posted_at"])

    def test_casting_again_puts_the_new_one_first(self) -> None:
        database.set_crew_message("First cast.", "Alice")
        database.set_crew_message("Second cast.", "Bob")
        messages = database.get_crew_messages()
        self.assertEqual([m["body"] for m in messages], ["Second cast.", "First cast."])

    def test_only_the_latest_3_are_kept(self) -> None:
        database.set_crew_message("Cast 1.", "Alice")
        database.set_crew_message("Cast 2.", "Bob")
        database.set_crew_message("Cast 3.", "Cara")
        database.set_crew_message("Cast 4.", "Dax")
        messages = database.get_crew_messages()
        self.assertEqual(
            [m["body"] for m in messages],
            ["Cast 4.", "Cast 3.", "Cast 2."],
        )
        with database._connect() as conn:  # noqa: SLF001 - test-only inspection
            count = conn.execute("SELECT COUNT(*) AS n FROM crew_message").fetchone()
        self.assertEqual(count["n"], 3)
