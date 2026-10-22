# TideWell Content & Profile Backend

A deliberately small FastAPI service with two jobs:

1. **Profile** — stores the few identity fields the client wanted on a real
   server (**name, email, phone**). Single row, upserted in place. No auth.
2. **Content catalog** — the schedule-controlled rotation of **narrated
   stories** and **ambient soundscapes**, plus which of the five built-in
   **games** are "featured" this week. Media files live on disk here (served
   under `/media`) so growing audio never bloats the app binary; the device
   syncs only lightweight metadata and downloads media lazily.

Everything else in the TideWell app (journal entries, mood check-ins, breathing
streaks, Fleet Knots) lives on-device and never touches this service. There is
still no login / multi-user system, so this remains open — no auth, no roles.

## Stack

- FastAPI + Uvicorn (+ `StaticFiles` for the `/media` mount)
- SQLite via the Python standard-library `sqlite3` module (no ORM — kept at a
  basic-CRUD simplicity level)
- Pydantic for request/response validation

## Endpoints

| Method  | Path                               | Purpose                                            |
| ------- | ---------------------------------- | -------------------------------------------------- |
| `GET`   | `/health`                          | Liveness probe -> `{"status":"ok", ...}`           |
| `GET`   | `/profile`                         | Stored profile, or `null` (HTTP 200) if none saved |
| `PUT`   | `/profile`                         | Upsert profile `{name, email, phone}`              |
| `POST`  | `/profile`                         | Alias for `PUT`                                    |
| `GET`   | `/content/catalog`                 | All currently-**active** content (see below)       |
| `POST`  | `/content/stories`                 | Upsert a story (create / full replace)             |
| `PATCH` | `/content/stories/{id}`            | Partial update — e.g. `{"active": false}`          |
| `POST`  | `/content/sounds`                  | Upsert an ambient sound                            |
| `PATCH` | `/content/sounds/{id}`             | Partial update                                     |
| `POST`  | `/content/featured-games`          | Upsert a featured-game flag                        |
| `PATCH` | `/content/featured-games/{key}`    | Partial update                                     |
| `GET`   | `/media/...`                       | Static media (story / sound audio files)           |

### `GET /content/catalog` shape

```jsonc
{
  "stories": [ {
    "id": "lighthouse", "title": "...", "series": "...", "narrator": "...",
    "teaser_subtitle": "...", "excerpt": ["para 1", "para 2"],
    "coordinates": "...", "swell_note": "...", "duration_label": "22 min",
    "active": true, "sort_order": 0,
    "mediaUrl": "/media/stories/lighthouse.m4a",   // prefix with the API base URL
    "mediaVersion": "2026-10-22T08:08:04+00:00"    // change-detection stamp
  } ],
  "sounds": [ {
    "id": "rolling_deep_sea", "label": "Rolling Deep Sea",
    "subtitle": "Low Frequency", "active": true, "sort_order": 0,
    "mediaUrl": "/media/sounds/rolling_deep_sea.wav",
    "mediaVersion": "..."
  } ],
  "featuredGames": [
    { "game_key": "calm_your_waves", "active": true, "effective_from": "2026-01-01", "sort_order": 0 }
  ]
}
```

Only `active` rows are returned. `mediaVersion` is the item's `updated_at`; the
device caches it and only re-downloads a media file when the version changes.

### Table schemas

- `profile`: `id, name, email, phone, created_at, updated_at`
- `content_story`: `id, title, series, narrator, teaser_subtitle, excerpt (JSON
  list), coordinates, swell_note, media_path, duration_label, active,
  sort_order, created_at, updated_at`
- `content_sound`: `id, label, subtitle, media_path, active, sort_order,
  created_at, updated_at`
- `featured_game`: `game_key, active, effective_from, sort_order, updated_at`

Richer story presentation (vibe chips, chapter copy) stays **client-authored**
in Flutter, keyed by the story `id`; the server owns media + title + core
teaser copy + the `active` flag.

The five `game_key`s are: `calm_your_waves`, `knot_master`, `fog_signal_echo`,
`sextant_horizon`, `cabin_dominoes`.

## Seeding (day-one content)

`app/seed.py` mirrors the content the app currently ships hardcoded (3 stories +
3 soundscapes) onto the server and **copies the real audio files** out of the
app's `assets/audio/` into `backend/media/stories/` and `backend/media/sounds/`,
so the catalog serves playable media immediately. It also registers all five
games, spotlighting `calm_your_waves` + `knot_master` as the initial featured
set.

```bash
cd backend
source .venv/bin/activate
python -m app.seed            # seed only if the catalog is empty (idempotent)
python -m app.seed --force    # wipe + recopy media + reseed from scratch
```

Seeding also runs automatically on server **startup** when the catalog is empty,
so a fresh DB comes up pre-populated with no manual step. `backend/media/` is
git-ignored because it is regenerated from `assets/audio/` by the seed.

## Setup & run

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run (port 8010 chosen to avoid colliding with other local services):
uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload
```

The SQLite file is created automatically at `backend/tidewell.db` on first run
(override with the `TIDEWELL_DB_PATH` env var).

## Quick verification

```bash
curl http://localhost:8010/health
curl http://localhost:8010/profile                       # -> null initially
curl -X PUT http://localhost:8010/profile \
  -H 'Content-Type: application/json' \
  -d '{"name":"Marcus Thorne","email":"marcus@example.com","phone":"+1 555 0100"}'
curl http://localhost:8010/profile                       # -> the saved profile

# Content catalog
curl http://localhost:8010/content/catalog               # -> active stories/sounds/games
curl -I http://localhost:8010/media/stories/lighthouse.m4a   # -> 200, audio/mp4

# Rotate content: deactivate a story and watch it drop out of the catalog
curl -X PATCH http://localhost:8010/content/stories/st_elmos_light \
  -H 'Content-Type: application/json' -d '{"active": false}'
curl http://localhost:8010/content/catalog               # -> st_elmos_light no longer listed

# Spotlight a different game this week
curl -X PATCH http://localhost:8010/content/featured-games/sextant_horizon \
  -H 'Content-Type: application/json' -d '{"active": true}'
```

## How the Flutter app reaches it

The app's `lib/core/app_config.dart` points at this service:

- Android emulator: `http://10.0.2.2:8010`
- iOS simulator / desktop: `http://localhost:8010`
- Override for a physical device / staging:
  `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8010`
