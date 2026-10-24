"""TideWell backend — accounts + content catalog.

Two concerns, same small stdlib-sqlite3 FastAPI service:

Accounts (real multi-user login/signup, the foundation for future
cross-device wellness competitions):
    POST  /auth/signup                  -> create account + session, returns {token, user}
    POST  /auth/login                   -> verify credentials + session, returns {token, user}
    POST  /auth/logout                  -> delete the caller's session (204)
    GET   /auth/me                       -> the current user (Bearer-protected)
    PATCH /auth/me                       -> partial profile update (name/age/sex/fleet_name)
    PUT   /me/points                     -> overwrite the caller's Fleet Knots total (Bearer-protected)
    GET   /leaderboard                   -> top N accounts by points + the caller's own row (Bearer-protected)
    PUT   /me/mood                       -> overwrite the caller's latest mood state (Bearer-protected)
    GET   /crew/mood-summary             -> anonymous % of crew currently "calm" (Bearer-protected)
    PUT   /crew/message                  -> cast a new crew message, bumping older ones down (Bearer-protected)
    GET   /crew/message                  -> the latest 3 crew messages, newest first (Bearer-protected)

Content catalog (unrelated to accounts, open):
    GET   /health                       -> liveness probe
    GET   /content/catalog              -> all currently-active content
    POST  /content/stories              -> upsert a story (create / replace)
    PATCH /content/stories/{id}         -> partial update (e.g. toggle active)
    POST  /content/sounds               -> upsert a sound
    PATCH /content/sounds/{id}          -> partial update
    POST  /content/featured-games       -> register a game's rotation eligibility
    PATCH /content/featured-games/{key} -> toggle a game in/out of the rotation pool

Media files are served statically under ``/media`` from ``backend/media/``.

Auth model: opaque bearer tokens (no JWT) stored in a ``session`` table, looked
up on every protected request. Passwords are PBKDF2-HMAC-SHA256 hashed with a
per-user salt (see ``app.auth``) — stdlib only, no bcrypt/passlib dependency.

The old single-row ``/profile`` placeholder endpoint has been removed; the
``user`` table / ``/auth/*`` endpoints fully supersede it.
"""

from __future__ import annotations

import os
import sqlite3
from datetime import datetime, timezone
from typing import Any, Literal, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, EmailStr, Field

from . import auth, database, rotation, seed

app = FastAPI(title="TideWell Accounts & Content Service", version="3.0.0")

# The Flutter client calls this from an emulator / device over the LAN, so keep
# CORS permissive — there are no credentials or secrets served here.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Accounts schemas -------------------------------------------------------


class SignupIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    email: EmailStr
    password: str = Field(..., min_length=auth.MIN_PASSWORD_LENGTH, max_length=200)
    age: int = Field(..., ge=0, le=150)
    # Sensitive personal data, kept a free-ish string on purpose — no rigid
    # enum. Still bounded so it can't be abused as an arbitrary blob.
    sex: str = Field(..., min_length=1, max_length=40)
    fleet_name: Optional[str] = Field(default=None, max_length=120)


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=200)


class ProfilePatch(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    age: Optional[int] = Field(default=None, ge=0, le=150)
    sex: Optional[str] = Field(default=None, min_length=1, max_length=40)
    fleet_name: Optional[str] = Field(default=None, max_length=120)


class UserOut(BaseModel):
    id: int
    name: str
    email: str
    age: int
    sex: str
    fleet_name: Optional[str] = None
    created_at: str


class AuthOut(BaseModel):
    token: str
    user: UserOut


class PointsIn(BaseModel):
    total_points: int = Field(..., ge=0)


class LeaderboardEntryOut(BaseModel):
    name: str
    fleet_name: Optional[str] = None
    total_points: int
    rank: int
    is_me: bool


class LeaderboardOut(BaseModel):
    entries: list[LeaderboardEntryOut]


class MoodIn(BaseModel):
    # Mirrors MoodState.key in lib/data/models/mood_state.dart.
    state: Literal[
        "calm_sea", "gentle_swell", "choppy_water", "drifting", "high_storm"
    ]


class CrewMoodSummaryOut(BaseModel):
    calm_percent: int
    total_logged: int


class CrewMessageIn(BaseModel):
    body: str = Field(..., min_length=1, max_length=280)


class CrewMessageOut(BaseModel):
    body: str
    author_name: str
    posted_at: str


class CrewMessagesOut(BaseModel):
    # Newest first, capped at database.CREW_MESSAGE_LIMIT (currently 3).
    messages: list[CrewMessageOut]


# --- Content catalog schemas ------------------------------------------------


class StoryIn(BaseModel):
    id: str = Field(..., min_length=1, max_length=80)
    title: str
    media_path: str
    series: str = ""
    narrator: str = ""
    teaser_subtitle: str = ""
    excerpt: list[str] = Field(default_factory=list)
    coordinates: str = ""
    swell_note: str = ""
    duration_label: str = ""
    active: bool = True
    sort_order: int = 0


class StoryPatch(BaseModel):
    title: Optional[str] = None
    media_path: Optional[str] = None
    series: Optional[str] = None
    narrator: Optional[str] = None
    teaser_subtitle: Optional[str] = None
    excerpt: Optional[list[str]] = None
    coordinates: Optional[str] = None
    swell_note: Optional[str] = None
    duration_label: Optional[str] = None
    active: Optional[bool] = None
    sort_order: Optional[int] = None


class SoundIn(BaseModel):
    id: str = Field(..., min_length=1, max_length=80)
    label: str
    media_path: str
    subtitle: str = ""
    active: bool = True
    sort_order: int = 0


class SoundPatch(BaseModel):
    label: Optional[str] = None
    media_path: Optional[str] = None
    subtitle: Optional[str] = None
    active: Optional[bool] = None
    sort_order: Optional[int] = None


class FeaturedGameIn(BaseModel):
    game_key: str = Field(..., min_length=1, max_length=80)
    # NOT "currently featured" — this is rotation *eligibility*. Which
    # eligible games are featured this week is computed by
    # `rotation.featured_window`, not stored. Set False to pull a game out of
    # rotation (e.g. it's not playable yet).
    active: bool = False
    effective_from: str = ""
    sort_order: int = 0


class FeaturedGamePatch(BaseModel):
    active: Optional[bool] = None
    effective_from: Optional[str] = None
    sort_order: Optional[int] = None


# Directory the /media mount serves from.
MEDIA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "media")


def _with_media_url(item: dict) -> dict:
    """Attach a downloadable ``mediaUrl`` + change-detection ``mediaVersion``
    to a story/sound dict, derived from its stored ``media_path`` /
    ``updated_at``. The client prefixes ``mediaUrl`` with the API base URL."""
    out = dict(item)
    media_path = out.get("media_path", "")
    out["mediaUrl"] = f"/media/{media_path}" if media_path else ""
    out["mediaVersion"] = out.get("updated_at", "")
    return out


@app.on_event("startup")
def _startup() -> None:
    database.init_db()
    # Come up pre-populated on a fresh DB; a no-op once content exists.
    try:
        seed.seed(force=False)
    except FileNotFoundError:
        # Bundled audio not reachable (e.g. backend copied without the app
        # repo). Tables still exist; content can be added via the write
        # endpoints. Don't block startup.
        pass


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "tidewell-backend"}


# ---------------------------------------------------------------------------
# Accounts / auth
# ---------------------------------------------------------------------------


def current_user(authorization: Optional[str] = Header(default=None)) -> dict:
    """FastAPI dependency: resolve ``Authorization: Bearer <token>`` to the
    current user row, or raise 401 for a missing/invalid/expired token."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    token = authorization[len("bearer ") :].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    user = database.get_user_for_token(token)
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user


def _issue_session(user: dict) -> dict:
    """Create a fresh session for ``user`` and return the ``{token, user}``
    envelope both signup and login respond with."""
    token = auth.new_session_token()
    database.create_session(token, user["id"])
    return {"token": token, "user": database.public_user(user)}


@app.post("/auth/signup", response_model=AuthOut, status_code=201)
def signup(payload: SignupIn) -> dict:
    """Create an active account immediately (no email verification) and return
    a session token + the public user. 409 if the email is already taken."""
    email = str(payload.email).lower()
    salt = auth.generate_salt()
    password_hash = auth.hash_password(payload.password, salt)
    try:
        user = database.create_user(
            name=payload.name.strip(),
            email=email,
            password_hash=password_hash,
            password_salt=salt,
            age=payload.age,
            sex=payload.sex.strip(),
            fleet_name=(payload.fleet_name.strip() or None)
            if payload.fleet_name
            else None,
        )
    except sqlite3.IntegrityError:
        # UNIQUE(email) violation — the only integrity constraint here.
        raise HTTPException(
            status_code=409, detail="An account with that email already exists."
        )
    return _issue_session(user)


@app.post("/auth/login", response_model=AuthOut)
def login(payload: LoginIn) -> dict:
    """Verify credentials and open a new session. Returns a generic 401 on any
    failure so it never leaks whether the email or the password was wrong."""
    email = str(payload.email).lower()
    user = database.get_user_by_email(email)
    invalid = HTTPException(status_code=401, detail="Invalid email or password.")
    if user is None:
        raise invalid
    if not auth.verify_password(
        payload.password, user["password_salt"], user["password_hash"]
    ):
        raise invalid
    return _issue_session(user)


@app.post("/auth/logout", status_code=204)
def logout(authorization: Optional[str] = Header(default=None)) -> Response:
    """Delete the caller's session. Idempotent — an unknown token is a no-op."""
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization[len("bearer ") :].strip()
        if token:
            database.delete_session(token)
    return Response(status_code=204)


@app.get("/auth/me", response_model=UserOut)
def read_me(user: dict = Depends(current_user)) -> dict:
    """Return the current user — used by the app on launch to validate a stored
    token is still good."""
    return database.public_user(user)


@app.patch("/auth/me", response_model=UserOut)
def update_me(
    payload: ProfilePatch, user: dict = Depends(current_user)
) -> dict:
    """Partial update of the caller's own editable profile fields. Email and
    password are intentionally out of scope here (they need re-verification)."""
    fields = payload.model_dump(exclude_unset=True)
    if "name" in fields and isinstance(fields["name"], str):
        fields["name"] = fields["name"].strip()
    if "sex" in fields and isinstance(fields["sex"], str):
        fields["sex"] = fields["sex"].strip()
    if "fleet_name" in fields:
        fn = fields["fleet_name"]
        fields["fleet_name"] = (fn.strip() or None) if isinstance(fn, str) else fn
    updated = database.update_user(user["id"], fields)
    if updated is None:  # pragma: no cover - current_user guarantees existence
        raise HTTPException(status_code=404, detail="user not found")
    return database.public_user(updated)


@app.put("/me/points")
def update_my_points(
    payload: PointsIn, user: dict = Depends(current_user)
) -> dict:
    """Overwrite the caller's Fleet Knots total with [payload.total_points].

    The device's on-device ledger is the source of truth for *how* points
    were earned; this always replaces the whole total (never a delta), so a
    sync can never double-count or drift out of sync with the device.
    """
    updated = database.set_user_points(user["id"], payload.total_points)
    if updated is None:  # pragma: no cover - current_user guarantees existence
        raise HTTPException(status_code=404, detail="user not found")
    return {"total_points": updated["total_points"]}


@app.get("/leaderboard", response_model=LeaderboardOut)
def read_leaderboard(
    limit: int = 4, user: dict = Depends(current_user)
) -> dict:
    """Real multi-user ranking: the top [limit] accounts by points, plus the
    caller's own row (with their true rank) appended if they didn't already
    make the top [limit] — so the caller always sees where they stand, never
    duplicated if they're already in the top slice.
    """
    top = database.leaderboard_top(limit)
    entries = [
        {
            "name": row["name"],
            "fleet_name": row["fleet_name"],
            "total_points": row["total_points"],
            "rank": i + 1,
            "is_me": row["id"] == user["id"],
        }
        for i, row in enumerate(top)
    ]
    if not any(e["is_me"] for e in entries):
        entries.append(
            {
                "name": user["name"],
                "fleet_name": user["fleet_name"],
                "total_points": user["total_points"],
                "rank": database.user_rank(user["id"]),
                "is_me": True,
            }
        )
    return {"entries": entries}


@app.put("/me/mood")
def update_my_mood(payload: MoodIn, user: dict = Depends(current_user)) -> dict:
    """Overwrite the caller's latest mood state. Only ever feeds the
    anonymous crew-wide summary below — never returned next to a name."""
    updated = database.set_user_mood(user["id"], payload.state)
    if updated is None:  # pragma: no cover - current_user guarantees existence
        raise HTTPException(status_code=404, detail="user not found")
    return {"state": updated["latest_mood_state"]}


@app.get("/crew/mood-summary", response_model=CrewMoodSummaryOut)
def read_crew_mood_summary(user: dict = Depends(current_user)) -> dict:
    """Anonymous aggregate: what fraction of accounts with a logged mood are
    currently "calm", across the whole crew — never attributed to anyone."""
    return database.crew_mood_summary()


@app.put("/crew/message", response_model=CrewMessageOut)
def cast_crew_message(
    payload: CrewMessageIn, user: dict = Depends(current_user)
) -> dict:
    """Cast a new crew message, attributed to the caller's real account
    name. Bumps every older message down a slot; only the latest
    database.CREW_MESSAGE_LIMIT are kept — the rest just age out.
    """
    return database.set_crew_message(payload.body.strip(), user["name"])


@app.get("/crew/message", response_model=CrewMessagesOut)
def read_crew_messages(user: dict = Depends(current_user)) -> dict:
    """The latest crew messages, newest first — empty if no one has cast
    one yet."""
    return {"messages": database.get_crew_messages()}


# ---------------------------------------------------------------------------
# Content catalog
# ---------------------------------------------------------------------------


@app.get("/content/catalog")
def read_catalog() -> dict:
    """Everything currently ``active``: stories, sounds and this week's
    featured games.

    Media items carry a full ``mediaUrl`` the app downloads lazily, plus a
    ``mediaVersion`` the device caches so unchanged files aren't re-fetched.

    Featured games are **not** a manually-toggled set: ``featured_game.active``
    marks a game as *eligible* for rotation (e.g. a still-unplayable game like
    Fog Signal Echo is excluded until it ships), and `rotation.featured_window`
    deterministically picks this week's 2 from the eligible pool — no cron job,
    nothing to forget to flip.
    """
    stories = [_with_media_url(s) for s in database.list_stories(active_only=True)]
    sounds = [_with_media_url(s) for s in database.list_sounds(active_only=True)]
    eligible = database.list_featured_games(active_only=True)
    this_weeks_keys = rotation.featured_window(
        [g["game_key"] for g in eligible],
        datetime.now(timezone.utc).date(),
        count=2,
    )
    by_key = {g["game_key"]: g for g in eligible}
    games = [by_key[key] for key in this_weeks_keys]
    return {"stories": stories, "sounds": sounds, "featuredGames": games}


@app.post("/content/stories")
def create_story(payload: StoryIn) -> dict:
    data = payload.model_dump()
    story_id = data.pop("id")
    return _with_media_url(database.upsert_story(story_id, data))


@app.patch("/content/stories/{story_id}")
def update_story(story_id: str, payload: StoryPatch) -> dict:
    result = database.patch_story(
        story_id, payload.model_dump(exclude_unset=True)
    )
    if result is None:
        raise HTTPException(status_code=404, detail="story not found")
    return _with_media_url(result)


@app.post("/content/sounds")
def create_sound(payload: SoundIn) -> dict:
    data = payload.model_dump()
    sound_id = data.pop("id")
    return _with_media_url(database.upsert_sound(sound_id, data))


@app.patch("/content/sounds/{sound_id}")
def update_sound(sound_id: str, payload: SoundPatch) -> dict:
    result = database.patch_sound(
        sound_id, payload.model_dump(exclude_unset=True)
    )
    if result is None:
        raise HTTPException(status_code=404, detail="sound not found")
    return _with_media_url(result)


@app.post("/content/featured-games")
def create_featured_game(payload: FeaturedGameIn) -> dict:
    data = payload.model_dump()
    game_key = data.pop("game_key")
    return database.upsert_featured_game(game_key, data)


@app.patch("/content/featured-games/{game_key}")
def update_featured_game(game_key: str, payload: FeaturedGamePatch) -> dict:
    result = database.patch_featured_game(
        game_key, payload.model_dump(exclude_unset=True)
    )
    if result is None:
        raise HTTPException(status_code=404, detail="featured game not found")
    return result


# Serve media last so the explicit routes above always win. The directory is
# created on first seed; ensure it exists so the mount doesn't error on a bare
# checkout that hasn't seeded yet.
os.makedirs(MEDIA_DIR, exist_ok=True)
app.mount("/media", StaticFiles(directory=MEDIA_DIR), name="media")
