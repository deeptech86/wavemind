FROM python:3.9-slim

WORKDIR /app

COPY backend/requirements.txt backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

COPY backend/app backend/app
COPY assets/audio assets/audio

WORKDIR /app/backend

EXPOSE 8000

# Seed the catalog on first boot (idempotent — no-ops once the DB already
# has content) so a fresh deploy isn't missing stories/sounds, then serve.
CMD ["sh", "-c", "python -m app.seed && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
