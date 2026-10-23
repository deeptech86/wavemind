# TideWell Content & Profile Backend

A deliberately small FastAPI service with two jobs:

1. **Profile** — stores the few identity fields the client wanted on a real
   server (**name, email, phone**). Single row, upserted in place. No auth.
2. **Content catalog** — the schedule-controlled rotation of **narrated
   stories** and **ambient soundscapes**, plus an **automatic weekly
   rotation** that spotlights 2 of the built-in **games** as "featured" each
   week (no manual toggling — see "Featured games" below). Media files live
   on disk here (served under `/media`) so growing audio never bloats the app
   binary; the device syncs only lightweight metadata and downloads media
   lazily.

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
| `POST`  | `/content/featured-games`          | Register a game's rotation eligibility             |
| `PATCH` | `/content/featured-games/{key}`    | Toggle a game in/out of the rotation pool          |
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

Stories/sounds: only `active` rows are returned. `mediaVersion` is the item's
`updated_at`; the device caches it and only re-downloads a media file when the
version changes.

`featuredGames`: **not** every `active` (eligible) game — exactly the 2 the
automatic weekly rotation currently picks. See "Featured games" below.

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

## Featured games (automatic weekly rotation)

`featured_game.active` is **rotation eligibility**, not "currently featured".
Day-one seeding marks every playable game eligible (`calm_your_waves`,
`knot_master`, `sextant_horizon`, `cabin_dominoes`) and excludes
`fog_signal_echo` since it's still a "coming soon" placeholder client-side.

Which 2 eligible games are spotlighted **this week** is computed on every
`GET /content/catalog` call by `app.rotation.featured_window` — a pure
function of (eligible keys, today's date). Same calendar week → same 2 picks;
the window advances by one game every ~7 days and wraps around the eligible
pool, so every eligible game gets fair rotation over time. There's no stored
"this week's picks" row to go stale and nothing to remember to toggle weekly.

Use the `PATCH` endpoint only to change the **eligible pool** — e.g. pull a
game out of rotation, or add `fog_signal_echo` once it's actually playable:

```bash
curl -X PATCH http://localhost:8010/content/featured-games/fog_signal_echo \
  -H 'Content-Type: application/json' -d '{"active": true}'   # now eligible
```

## Seeding (day-one content)

`app/seed.py` mirrors the content the app currently ships hardcoded (3 stories +
3 soundscapes) onto the server and **copies the real audio files** out of the
app's `assets/audio/` into `backend/media/stories/` and `backend/media/sounds/`,
so the catalog serves playable media immediately. It also registers all five
games, marking the four playable ones eligible for the weekly rotation (see
"Featured games" above).

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

# Add (or remove) a game from the weekly rotation pool — which 2 eligible
# games are actually featured this week is computed automatically, not set here
curl -X PATCH http://localhost:8010/content/featured-games/fog_signal_echo \
  -H 'Content-Type: application/json' -d '{"active": true}'
```

## How the Flutter app reaches it

The app's `lib/core/app_config.dart` points at this service:

- Android emulator: `http://10.0.2.2:8010`
- iOS simulator / desktop: `http://localhost:8010`
- Override for a physical device / staging:
  `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8010`
