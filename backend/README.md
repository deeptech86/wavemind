# TideWell Profile Backend

A deliberately tiny FastAPI service that stores **only** the few identity
fields the client wanted on a real server — **name, email, phone**. Everything
else in the TideWell app (journal entries, mood check-ins, breathing streaks,
Fleet Knots) lives on-device and never touches this service.

There is no login / multi-user system in the app yet, so this is a
**single-profile** service: it stores one profile row and upserts it in place.
No auth, no roles — intentionally out of scope for this stage.

## Stack

- FastAPI + Uvicorn
- SQLite via the Python standard-library `sqlite3` module (no ORM — kept at a
  basic-CRUD simplicity level)
- Pydantic for request/response validation

## Endpoints

| Method     | Path       | Purpose                                             |
| ---------- | ---------- | --------------------------------------------------- |
| `GET`      | `/health`  | Liveness probe -> `{"status":"ok", ...}`            |
| `GET`      | `/profile` | Stored profile, or `null` (HTTP 200) if none saved  |
| `PUT`      | `/profile` | Upsert profile `{name, email, phone}`               |
| `POST`     | `/profile` | Alias for `PUT`                                     |

The `profile` table schema: `id, name, email, phone, created_at, updated_at`.

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
```

## How the Flutter app reaches it

The app's `lib/core/app_config.dart` points at this service:

- Android emulator: `http://10.0.2.2:8010`
- iOS simulator / desktop: `http://localhost:8010`
- Override for a physical device / staging:
  `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8010`
