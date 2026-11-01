"""Password hashing + session-token helpers for the Wavemind accounts system.

Deliberately stdlib-only (``hashlib`` / ``hmac`` / ``secrets``), consistent with
this backend's "small, no-extra-dependencies" style — there is no ``bcrypt`` /
``passlib`` dependency because PBKDF2-HMAC-SHA256 from the standard library is
adequate here.

Everything in this module is pure (no DB, no FastAPI) so the hashing /
verification logic can be unit-tested in isolation (see
``tests/test_auth.py``).

Storage contract:
    * ``password_salt`` — a per-user random salt, stored as a hex string.
    * ``password_hash`` — the PBKDF2 derived key, stored as a hex string.
Both live in the ``user`` row; the plaintext password is never stored.
"""

from __future__ import annotations

import hashlib
import hmac
import secrets

# PBKDF2 parameters. 200k iterations is a reasonable 2026 cost for sha256 and
# matches the figure called out in the task brief.
_HASH_ALGO = "sha256"
_ITERATIONS = 200_000
_SALT_BYTES = 16
_TOKEN_BYTES = 32

# Server-side minimal sanity rule — nothing more elaborate.
MIN_PASSWORD_LENGTH = 8


def generate_salt() -> str:
    """Return a fresh cryptographically-random salt as a hex string."""
    return secrets.token_bytes(_SALT_BYTES).hex()


def hash_password(password: str, salt_hex: str) -> str:
    """Derive the PBKDF2 hash (hex) for ``password`` under the given salt."""
    salt = bytes.fromhex(salt_hex)
    derived = hashlib.pbkdf2_hmac(
        _HASH_ALGO, password.encode("utf-8"), salt, _ITERATIONS
    )
    return derived.hex()


def verify_password(password: str, salt_hex: str, expected_hash_hex: str) -> bool:
    """Constant-time check that ``password`` matches the stored salt+hash."""
    candidate = hash_password(password, salt_hex)
    return hmac.compare_digest(candidate, expected_hash_hex)


def new_session_token() -> str:
    """Return a new opaque, URL-safe session token."""
    return secrets.token_urlsafe(_TOKEN_BYTES)
