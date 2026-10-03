"""TideWell minimal profile backend.

A single-profile CRUD service exposing just enough to persist the few identity
fields the client wanted on a real server (name / email / phone). Everything
else in the app lives on-device.

Endpoints:
    GET  /health   -> liveness probe
    GET  /profile  -> the stored profile, or null if none saved yet
    PUT  /profile  -> upsert the profile {name, email, phone}
    POST /profile  -> alias for PUT (convenience)

No auth / roles: there is no login system in the app yet, so this is
deliberately open and out of scope for this stage.
"""

from __future__ import annotations

from typing import Optional

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr, Field

from . import database

app = FastAPI(title="TideWell Profile Service", version="1.0.0")

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


@app.on_event("startup")
def _startup() -> None:
    database.init_db()


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
