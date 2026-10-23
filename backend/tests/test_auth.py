"""Unit tests for the pure password-hashing / verification logic.

Covers only the Flutter-free, DB-free helpers in ``app.auth`` — the hashing and
token primitives — which are worth testing in isolation.

Run with:  python -m unittest tests.test_auth   (from backend/, venv active)
       or:  python -m unittest discover
"""

from __future__ import annotations

import unittest

from app import auth


class PasswordHashingTests(unittest.TestCase):
    def test_correct_password_verifies(self) -> None:
        salt = auth.generate_salt()
        hashed = auth.hash_password("correct horse battery", salt)
        self.assertTrue(
            auth.verify_password("correct horse battery", salt, hashed)
        )

    def test_wrong_password_rejected(self) -> None:
        salt = auth.generate_salt()
        hashed = auth.hash_password("correct horse battery", salt)
        self.assertFalse(auth.verify_password("wrong password", salt, hashed))

    def test_same_password_different_salts_differ(self) -> None:
        salt_a = auth.generate_salt()
        salt_b = auth.generate_salt()
        self.assertNotEqual(salt_a, salt_b)
        hash_a = auth.hash_password("same password", salt_a)
        hash_b = auth.hash_password("same password", salt_b)
        # Different per-user salts must yield different stored hashes, so a
        # leaked DB can't reveal that two users share a password.
        self.assertNotEqual(hash_a, hash_b)

    def test_hash_is_deterministic_for_same_salt(self) -> None:
        salt = auth.generate_salt()
        self.assertEqual(
            auth.hash_password("repeatable", salt),
            auth.hash_password("repeatable", salt),
        )

    def test_hash_and_salt_are_hex_strings(self) -> None:
        salt = auth.generate_salt()
        hashed = auth.hash_password("whatever", salt)
        # Both round-trip through bytes.fromhex without error.
        bytes.fromhex(salt)
        bytes.fromhex(hashed)

    def test_session_tokens_are_unique(self) -> None:
        tokens = {auth.new_session_token() for _ in range(100)}
        self.assertEqual(len(tokens), 100)


if __name__ == "__main__":
    unittest.main()
