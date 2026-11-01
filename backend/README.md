# Wavemind Accounts & Content Backend

A deliberately small FastAPI service with two jobs:

1. **Accounts** — a real multi-user login/signup system (the foundation for the
   future cross-device wellness competitions). Users sign up with **name,
   email, password, age, sex** and an optional **fleet_name**; sessions are
   opaque bearer tokens. See "Accounts / auth" below.
2. **Content catalog** — the schedule-controlled rotation of **narrated
   stories** and **ambient soundscapes**, plus an **automatic weekly
   rotation** that spotlights 2 of the built-in **games** as "featured" each
   week (no manual toggling — see "Featured games" below). Media files live
   on disk here (served under `/media`) so growing audio never bloats the app
   binary; the device syncs only lightweight metadata and downloads media
   lazily.

Everything else in the Wavemind app (journal entries, mood check-ins, breathing
streaks, Fleet Knots) lives on-device and never touches this service.

> The original single-row `/profile` placeholder endpoint (name/email/phone)
> has been **retired** — it predated any accounts concept and is fully
> superseded by the `user` table and `/auth/*` endpoints below.

## Stack

- FastAPI + Uvicorn (+ `StaticFiles` for the `/media` mount)
- SQLite via the Python standard-library `sqlite3` module (no ORM — kept at a
  basic-CRUD simplicity level)
- Pydantic for request/response validation
- Password hashing + session tokens via the standard library only
  (`hashlib` / `hmac` / `secrets`) — no `bcrypt` / `passlib` dependency

## Endpoints

| Method  | Path                               | Purpose                                            |
| ------- | ---------------------------------- | -------------------------------------------------- |
| `GET`   | `/health`                          | Liveness probe -> `{"status":"ok", ...}`           |
| `POST`  | `/auth/signup`                     | Create account + session -> `{token, user}` (201)  |
| `POST`  | `/auth/login`                      | Verify credentials + session -> `{token, user}`    |
| `POST`  | `/auth/logout`                     | Delete caller's session (204). Bearer token        |
| `GET`   | `/auth/me`                         | Current user. Bearer token                         |
| `PATCH` | `/auth/me`                         | Partial profile update. Bearer token               |
| `GET`   | `/content/catalog`                 | All currently-**active** content (see below)       |
| `POST`  | `/content/stories`                 | Upsert a story (create / full replace)             |
| `PATCH` | `/content/stories/{id}`            | Partial update — e.g. `{"active": false}`          |
| `POST`  | `/content/sounds`                  | Upsert an ambient sound                            |
| `PATCH` | `/content/sounds/{id}`             | Partial update                                     |
| `POST`  | `/content/featured-games`          | Register a game's rotation eligibility             |
| `PATCH` | `/content/featured-games/{key}`    | Toggle a game in/out of the rotation pool          |
| `GET`   | `/media/...`                       | Static media (story / sound audio files)           |

## Accounts / auth

Real multi-user accounts. Signup creates an **active** account immediately —
there is no email verification (no email-sending infrastructure exists, and
none was added).

### Request / response shapes

```jsonc
// POST /auth/signup   (201)
// body:
{ "name": "Marcus Thorne", "email": "marcus@example.com",
  "password": "deepsea123", "age": 34, "sex": "male",
  "fleet_name": "Northern Fleet" }        // fleet_name optional, may be omitted/null
// -> { "token": "<opaque>", "user": { ...public user... } }

// POST /auth/login
{ "email": "marcus@example.com", "password": "deepsea123" }
// -> { "token": "<opaque>", "user": { ...public user... } }

// GET /auth/me        (Authorization: Bearer <token>)  -> public user
// PATCH /auth/me       (Authorization: Bearer <token>)
{ "name": "Captain Marcus", "age": 35, "sex": "male",
  "fleet_name": "Southern Fleet" }        // all fields optional (partial update)

// public user (never includes the password hash or salt):
{ "id": 1, "name": "...", "email": "...", "age": 34, "sex": "male",
  "fleet_name": "Northern Fleet", "created_at": "2026-10-23T06:45:45+00:00" }
```

- **Email** is the login identifier, stored lowercased and `UNIQUE`; a
  duplicate signup returns **409**. Validated with Pydantic `EmailStr`.
- **Password** must be at least 8 characters (enforced server-side); too-short
  fails validation with **422**. `PATCH /auth/me` deliberately cannot change
  the email or password (those need a re-verification flow that is out of scope).
- **Login** failures return a generic **401 "Invalid email or password."** that
  never reveals whether the email or the password was wrong.

### Password hashing & sessions

- **Hashing**: `hashlib.pbkdf2_hmac("sha256", password, salt, 200_000)` with a
  per-user random salt (`secrets.token_bytes`). The derived hash and the salt
  are both stored as hex strings in the `user` row; **plaintext is never
  stored**. Verification is constant-time (`hmac.compare_digest`). All of this
  lives in `app/auth.py` as pure functions (unit-tested in
  `tests/test_auth.py`).
- **Sessions**: no JWT. `POST /auth/login` / `/auth/signup` create a row in the
  `session` table keyed by an opaque `secrets.token_urlsafe(32)` token, with a
  **30-day** expiry (long-lived — there is no refresh-token flow in this pass).
  Protected endpoints require `Authorization: Bearer <token>`; a missing,
  unknown, or expired token returns **401**. Expired tokens are pruned from the
  table as they are presented. `POST /auth/logout` deletes the caller's row.

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

- `user`: `id, name, email (unique), password_hash, password_salt, age, sex,
  fleet_name (nullable), created_at, updated_at`
- `session`: `token (PK), user_id (FK -> user.id), created_at, expires_at`
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

# One-time (and again whenever this Mac's LAN IP changes): generate a
# locally-trusted TLS cert via mkcert. See tool/gen_dev_cert.sh for what it
# covers and how to trust it on a real test device.
../tool/gen_dev_cert.sh

# Run over HTTPS (port 8010 chosen to avoid colliding with other local
# services). The server only ever serves TLS — there is no plaintext-HTTP
# mode — so login/session traffic is never sent in the clear, even on a LAN:
uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload \
  --ssl-certfile certs/dev-cert.pem --ssl-keyfile certs/dev-key.pem
```

The SQLite file is created automatically at `backend/wavemind.db` on first run
(override with the `WAVEMIND_DB_PATH` env var).

## Quick verification

```bash
curl https://localhost:8010/health

# Accounts: signup -> capture the token -> use it on protected endpoints
TOKEN=$(curl -s -X POST https://localhost:8010/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{"name":"Marcus Thorne","email":"marcus@example.com","password":"deepsea123","age":34,"sex":"male","fleet_name":"Northern Fleet"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

curl -X POST https://localhost:8010/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{"name":"X","email":"marcus@example.com","password":"another12","age":9,"sex":"x"}'  # -> 409 duplicate
curl -X POST https://localhost:8010/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"marcus@example.com","password":"wrongpass"}'                                 # -> 401 generic
curl https://localhost:8010/auth/me -H "Authorization: Bearer $TOKEN"                         # -> the user
curl -X PATCH https://localhost:8010/auth/me -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"name":"Captain Marcus","age":35}'                # -> updated user
curl -X POST https://localhost:8010/auth/logout -H "Authorization: Bearer $TOKEN"             # -> 204
curl https://localhost:8010/auth/me -H "Authorization: Bearer $TOKEN"                         # -> 401 (session gone)

# Content catalog: reads are open, writes require a Bearer token (any signed-in
# account — there is no separate admin role in this app)
curl https://localhost:8010/content/catalog               # -> active stories/sounds/games
curl -I https://localhost:8010/media/stories/lighthouse.m4a   # -> 200, audio/mp4

# Rotate content: deactivate a story and watch it drop out of the catalog
curl -X PATCH https://localhost:8010/content/stories/st_elmos_light \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"active": false}'
curl https://localhost:8010/content/catalog               # -> st_elmos_light no longer listed

# Add (or remove) a game from the weekly rotation pool — which 2 eligible
# games are actually featured this week is computed automatically, not set here
curl -X PATCH https://localhost:8010/content/featured-games/fog_signal_echo \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"active": true}'
```

## How the Flutter app reaches it

The app's `lib/core/app_config.dart` points at this service, always over HTTPS:

- Android emulator: `https://10.0.2.2:8010`
- iOS simulator / desktop: `https://localhost:8010`
- Override for a physical device / staging:
  `flutter run --dart-define=API_BASE_URL=https://192.168.x.x:8010`

A **real device** additionally needs the mkcert root CA installed and trusted
(`tool/gen_dev_cert.sh` prints exact steps per platform) — without that, the
device correctly refuses the connection as an untrusted certificate. The iOS
Simulator needs no extra step (it shares this Mac's trust store). The
**Android emulator** does need the CA installed too, same as a real Android
device (Settings > Security > Encryption & credentials > Install a
certificate), *or* push it straight into the emulator's system trust store
with root (works on a Google APIs, non-Play-Store emulator image):
`adb root && adb remount` then push `rootCA.pem` into
`/system/etc/security/cacerts/` under its subject-hash filename and reboot.
