"""TideWell minimal profile backend.

A single-profile CRUD service exposing just enough to persist the few identity
fields the client wanted on a real server (name / email / phone). Everything
else in the app lives on-device.

Endpoints:
    GET   /health                       -> liveness probe
    GET   /profile                      -> the stored profile, or null
    PUT   /profile                      -> upsert the profile {name, email, phone}
    POST  /profile                      -> alias for PUT (convenience)

    GET   /content/catalog              -> all currently-active content
    POST  /content/stories              -> upsert a story (create / replace)
    PATCH /content/stories/{id}         -> partial update (e.g. toggle active)
    POST  /content/sounds               -> upsert a sound
    PATCH /content/sounds/{id}          -> partial update
    POST  /content/featured-games       -> upsert a featured-game flag
    PATCH /content/featured-games/{key} -> partial update

Media files are served statically under ``/media`` from ``backend/media/``.

No auth / roles: there is no login system in the app yet, so this is
deliberately open and out of scope for this stage.
"""

from __future__ import annotations

import os
from typing import Any, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, EmailStr, Field

from . import database, seed

app = FastAPI(title="TideWell Content & Profile Service", version="2.0.0")

# The Flutter client calls this from an emulator / device over the LAN, so keep
# CORS permissive — there are no credentials or secrets served here.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class ProfileIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    email: EmailStr
    phone: str = Field(..., min_length=1, max_length=40)


class ProfileOut(BaseModel):
    id: int
    name: str
    email: str
    phone: str
    created_at: str
    updated_at: str


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
    return {"status": "ok", "service": "tidewell-profile"}


@app.get("/profile", response_model=Optional[ProfileOut])
def read_profile() -> Optional[dict]:
    """Return the stored profile, or ``null`` (HTTP 200) if none exists yet.

    Returning 200 + null rather than 404 keeps the client's "nothing saved
    yet" path identical to a normal empty-form load.
    """
    return database.get_profile()


@app.put("/profile", response_model=ProfileOut)
@app.post("/profile", response_model=ProfileOut)
def save_profile(payload: ProfileIn) -> dict:
    return database.upsert_profile(
        name=payload.name,
        email=str(payload.email),
        phone=payload.phone,
    )


# ---------------------------------------------------------------------------
# Content catalog
# ---------------------------------------------------------------------------


@app.get("/content/catalog")
def read_catalog() -> dict:
    """Everything currently ``active``: stories, sounds and featured games.

    Media items carry a full ``mediaUrl`` the app downloads lazily, plus a
    ``mediaVersion`` the device caches so unchanged files aren't re-fetched.
    """
    stories = [_with_media_url(s) for s in database.list_stories(active_only=True)]
    sounds = [_with_media_url(s) for s in database.list_sounds(active_only=True)]
    games = database.list_featured_games(active_only=True)
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
