"""Unit tests for the crew mood-summary and shared crew-message helpers in
``app.database``.

Run with:  python -m unittest tests.test_crew   (from backend/, venv active)
       or:  python -m unittest discover
"""

from __future__ import annotations

import os
import tempfile
import unittest
from datetime import datetime, timedelta, timezone

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
        author = self._make_user("Marcus")
        database.set_crew_message(
            "Fair winds to the night watch.", "Marcus Thorne", author["id"]
        )
        messages = database.get_crew_messages()
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]["body"], "Fair winds to the night watch.")
        self.assertEqual(messages[0]["author_name"], "Marcus Thorne")
        self.assertIsNotNone(messages[0]["posted_at"])
        self.assertIsNotNone(messages[0]["id"])

    def test_casting_again_puts_the_new_one_first(self) -> None:
        alice, bob = self._make_user("Alice"), self._make_user("Bob")
        database.set_crew_message("First cast.", "Alice", alice["id"])
        database.set_crew_message("Second cast.", "Bob", bob["id"])
        messages = database.get_crew_messages()
        self.assertEqual([m["body"] for m in messages], ["Second cast.", "First cast."])

    def test_only_the_latest_3_are_kept(self) -> None:
        users = [self._make_user(n) for n in ("Alice", "Bob", "Cara", "Dax")]
        for i, user in enumerate(users, start=1):
            database.set_crew_message(f"Cast {i}.", user["name"], user["id"])
        messages = database.get_crew_messages()
        self.assertEqual(
            [m["body"] for m in messages],
            ["Cast 4.", "Cast 3.", "Cast 2."],
        )
        with database._connect() as conn:  # noqa: SLF001 - test-only inspection
            count = conn.execute("SELECT COUNT(*) AS n FROM crew_message").fetchone()
        self.assertEqual(count["n"], 3)


class CrewMessageFlagTests(_DbTestCase):
    def _cast(self, author: dict, body: str = "A float bottle.") -> int:
        message = database.set_crew_message(body, author["name"], author["id"])
        return message["id"]

    def test_flagging_unknown_message_returns_none(self) -> None:
        flagger = self._make_user("Flagger")
        self.assertIsNone(database.flag_crew_message(999999, flagger["id"]))

    def test_a_single_flag_does_not_suspend(self) -> None:
        author = self._make_user("Author")
        message_id = self._cast(author)
        flagger = self._make_user("Flagger")
        result = database.flag_crew_message(message_id, flagger["id"])
        self.assertEqual(result, {"flag_count": 1, "author_suspended": False})
        self.assertFalse(
            database.is_user_suspended(database.get_user_by_id(author["id"]))
        )

    def test_the_same_user_flagging_twice_only_counts_once(self) -> None:
        author = self._make_user("Author")
        message_id = self._cast(author)
        flagger = self._make_user("Flagger")
        database.flag_crew_message(message_id, flagger["id"])
        result = database.flag_crew_message(message_id, flagger["id"])
        self.assertEqual(result["flag_count"], 1)

    def test_more_than_5_distinct_flaggers_suspends_the_author(self) -> None:
        author = self._make_user("Author")
        message_id = self._cast(author)
        flaggers = [self._make_user(f"Flagger{i}") for i in range(6)]
        result = None
        for flagger in flaggers:
            result = database.flag_crew_message(message_id, flagger["id"])
        # 6 distinct flaggers = "more than 5".
        self.assertEqual(result, {"flag_count": 6, "author_suspended": True})
        updated_author = database.get_user_by_id(author["id"])
        self.assertTrue(database.is_user_suspended(updated_author))
        until = datetime.fromisoformat(updated_author["suspended_until"])
        expected = datetime.now(timezone.utc) + timedelta(
            days=database.SUSPENSION_DAYS
        )
        self.assertLess(abs((until - expected).total_seconds()), 5)

    def test_exactly_5_flaggers_does_not_suspend(self) -> None:
        author = self._make_user("Author")
        message_id = self._cast(author)
        flaggers = [self._make_user(f"Flagger{i}") for i in range(5)]
        result = None
        for flagger in flaggers:
            result = database.flag_crew_message(message_id, flagger["id"])
        self.assertEqual(result, {"flag_count": 5, "author_suspended": False})

    def test_suspended_author_cannot_cast(self) -> None:
        author = self._make_user("Author")
        message_id = self._cast(author)
        for i in range(6):
            flagger = self._make_user(f"Flagger{i}")
            database.flag_crew_message(message_id, flagger["id"])
        self.assertTrue(
            database.is_user_suspended(database.get_user_by_id(author["id"]))
        )

    def test_suspended_until_is_not_reset_by_a_later_unrelated_flag_wave(
        self,
    ) -> None:
        author = self._make_user("Author")
        message_id = self._cast(author)
        for i in range(6):
            flagger = self._make_user(f"Flagger{i}")
            database.flag_crew_message(message_id, flagger["id"])
        first_until = database.get_user_by_id(author["id"])["suspended_until"]

        # A second message from the same (already-suspended) author gets
        # flagged past the threshold too — the suspension clock must not
        # restart from this later wave.
        second_message_id = self._cast(author, "Another float bottle.")
        for i in range(6):
            flagger = self._make_user(f"OtherFlagger{i}")
            database.flag_crew_message(second_message_id, flagger["id"])
        second_until = database.get_user_by_id(author["id"])["suspended_until"]
        self.assertEqual(first_until, second_until)
