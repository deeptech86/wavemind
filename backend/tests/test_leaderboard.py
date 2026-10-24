"""Unit tests for the leaderboard points helpers in ``app.database``.

Run with:  python -m unittest tests.test_leaderboard   (from backend/, venv active)
       or:  python -m unittest discover
"""

from __future__ import annotations

import os
import tempfile
import unittest

from app import database


class LeaderboardTests(unittest.TestCase):
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

    def _make_user(self, name: str, points: int) -> dict:
        user = database.create_user(
            name=name,
            email=f"{name.lower()}@example.com",
            password_hash="hash",
            password_salt="salt",
            age=30,
            sex="sailor",
            fleet_name=None,
        )
        database.set_user_points(user["id"], points)
        return database.get_user_by_id(user["id"])

    def test_new_user_defaults_to_zero_points(self) -> None:
        user = database.create_user(
            name="Zed",
            email="zed@example.com",
            password_hash="hash",
            password_salt="salt",
            age=30,
            sex="sailor",
            fleet_name=None,
        )
        self.assertEqual(user["total_points"], 0)

    def test_set_user_points_overwrites_the_total(self) -> None:
        user = self._make_user("Alice", 100)
        database.set_user_points(user["id"], 250)
        self.assertEqual(database.get_user_by_id(user["id"])["total_points"], 250)

    def test_set_user_points_unknown_user_returns_none(self) -> None:
        self.assertIsNone(database.set_user_points(999999, 100))

    def test_leaderboard_top_orders_by_points_descending(self) -> None:
        self._make_user("Alice", 300)
        self._make_user("Bob", 500)
        self._make_user("Cara", 100)
        top = database.leaderboard_top(2)
        self.assertEqual([row["name"] for row in top], ["Bob", "Alice"])

    def test_leaderboard_top_respects_limit(self) -> None:
        for i in range(6):
            self._make_user(f"Sailor{i}", i * 10)
        self.assertEqual(len(database.leaderboard_top(4)), 4)

    def test_user_rank_counts_strictly_greater_scores(self) -> None:
        alice = self._make_user("Alice", 300)
        self._make_user("Bob", 500)
        self._make_user("Cara", 100)
        self.assertEqual(database.user_rank(alice["id"]), 2)

    def test_user_rank_is_1_for_the_sole_or_top_user(self) -> None:
        solo = self._make_user("Solo", 0)
        self.assertEqual(database.user_rank(solo["id"]), 1)
