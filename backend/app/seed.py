"""Day-one content seeding for the Wavemind content catalog.

Mirrors the content that currently ships *hardcoded* inside the Flutter app
(3 narrated stories + 10 ambient soundscapes) onto the server, and copies the
real audio files out of the app's ``assets/audio/`` bundle into
``backend/media/`` so the seeded catalog serves genuinely playable media from
the first request.

The seven built-in games are registered in ``featured_game``, all seven marked
eligible for the weekly rotation pool — see ``app.rotation`` for how 2 of the
eligible games get spotlighted as "Featured this week" automatically, on a
rolling 7-day cadence, with no manual toggling required.

Usage (from the ``backend/`` directory, venv active)::

    python -m app.seed            # seed only if the catalog is empty (idempotent)
    python -m app.seed --force    # wipe + recopy + reseed from scratch

Startup seeding (see ``app.main``) calls :func:`seed` with ``force=False`` so a
fresh deployment comes up pre-populated without a manual step.
"""

from __future__ import annotations

import argparse
import os
import shutil

from . import database

# backend/
_BACKEND_DIR = os.path.dirname(os.path.dirname(__file__))
# repo root (…/WavemindApp), one level above backend/
_REPO_ROOT = os.path.dirname(_BACKEND_DIR)

# Where the app's bundled audio currently lives, and where we copy it to be
# served under the /media mount.
ASSETS_AUDIO_DIR = os.path.join(_REPO_ROOT, "assets", "audio")
MEDIA_DIR = os.path.join(_BACKEND_DIR, "media")
MEDIA_STORIES_DIR = os.path.join(MEDIA_DIR, "stories")
MEDIA_SOUNDS_DIR = os.path.join(MEDIA_DIR, "sounds")

# The seven built-in game identifiers (must match `GameKeys` on the Flutter
# side and the tiles in off_watch_games_screen.dart).
GAME_KEYS = [
    "calm_your_waves",
    "knot_master",
    "fog_signal_echo",
    "sextant_horizon",
    "cabin_dominoes",
    "stone_cairn",
    "matchstick_puzzle",
]

# Games eligible for the weekly rotation pool (see `app.rotation`). Only
# games that are actually playable belong here — all seven now ship (see
# off_watch_games_screen.dart's `ready` flags). Which 2 of these are
# featured *this week* is computed automatically, not chosen here.
ELIGIBLE_FOR_ROTATION = {
    "calm_your_waves",
    "knot_master",
    "fog_signal_echo",
    "sextant_horizon",
    "cabin_dominoes",
    "stone_cairn",
    "matchstick_puzzle",
}

# Day-one stories. ``source`` is the bundled asset copied into media/stories/
# as ``<id>.<ext>``; ``media_path`` is the path served under /media.
# Only one spoken-word narration placeholder exists today
# (lighthouse_chapter.m4a), so every story is seeded from it — swap per-story
# source files here once real narration lands.
_STORY_SEED = [
    {
        "id": "lighthouse",
        "source": "lighthouse_chapter.m4a",
        "title": "The Lighthouse at Cape Horn",
        "series": "Tales of the Roaring Forties",
        "narrator": "Capt. Torben Lind",
        "teaser_subtitle": "Narrated by Capt. Torben Lind • 22 min",
        "coordinates": "55°58′S • 67°17′W",
        "swell_note": "Cape Horn Swell 2.4m",
        "duration_label": "22 min",
        "excerpt": [
            '"The wick catches with a soft crackle, shielded from forty knots '
            "of Antarctic gale by two inches of frosted Belgian plate glass. "
            "Below, the dark Drake Passage rolls on in ceaseless, rhythmic "
            'breathing..."',
            "Listen closely as Captain Torben details the ancient clockwork "
            "counterweights that kept the prism rotating without shore power "
            "for one hundred and twelve solitary winters. Let the steady "
            "pendulum swing settle your pulse.",
        ],
    },
    {
        "id": "stars_over_pacific",
        "source": "lighthouse_chapter.m4a",
        "title": "Stars Over the Pacific",
        "series": "Horizon Tales",
        "narrator": "Amaia Rangi",
        "teaser_subtitle": "Polynesian wayfinding & quiet tide drift • 18 min",
        "coordinates": "09°12′S • 140°06′W",
        "swell_note": "Gentle Tide Drift 0.8m",
        "duration_label": "18 min",
        "excerpt": [
            '"The navigators of old read the ocean like a page — each long '
            'swell a sentence pointing home beneath the wheeling Southern '
            'stars."',
        ],
    },
    {
        "id": "st_elmos_light",
        "source": "lighthouse_chapter.m4a",
        "title": "St. Elmo's Light",
        "series": "Horizon Tales",
        "narrator": "Old Deck Folklore",
        "teaser_subtitle": "Folkloric lullaby for restless anchor watch • 15 min",
        "coordinates": "48°20′N • 05°45′W",
        "swell_note": "Light Drizzle on Rigging",
        "duration_label": "15 min",
        "excerpt": [
            '"They say the pale blue fire that dances on the masthead is a '
            "saint's own blessing — a quiet light for the sleepless on "
            'anchor watch."',
        ],
    },
]

# Day-one ambient soundscapes — ids must match `AppAssets.audioAmbient*` and
# the bundled-fallback / catalog-id maps in `haven_screen.dart`.
_SOUND_SEED = [
    {
        "id": "slow_drift",
        "source": "ambient_slow_drift.mp3",
        "label": "A Slow Drift",
        "subtitle": "Hanna Lindgren",
    },
    {
        "id": "forest_birdsong",
        "source": "ambient_forest_birdsong.mp3",
        "label": "Forest Birdsong",
        "subtitle": "Nature SFX",
    },
    {
        "id": "closed_eyes_speak",
        "source": "ambient_closed_eyes_speak.mp3",
        "label": "Closed Eyes Speak",
        "subtitle": "Calm Shores",
    },
    {
        "id": "december_im_home",
        "source": "ambient_december_im_home.mp3",
        "label": "December, I'm Home",
        "subtitle": "Johannes Bornlof",
    },
    {
        "id": "delta_wave_drone",
        "source": "ambient_delta_wave_drone.mp3",
        "label": "Delta Wave Drone",
        "subtitle": "Binaural Relaxation",
    },
    {
        "id": "everbloom",
        "source": "ambient_everbloom.mp3",
        "label": "Everbloom",
        "subtitle": "Center of Attention",
    },
    {
        "id": "gentle_solace",
        "source": "ambient_gentle_solace.mp3",
        "label": "Gentle Solace",
        "subtitle": "Amber Glow",
    },
    {
        "id": "recovery_again",
        "source": "ambient_recovery_again.mp3",
        "label": "Recovery Again",
        "subtitle": "Elin Piel",
    },
    {
        "id": "quiet_spa",
        "source": "ambient_quiet_spa.mp3",
        "label": "The Quiet Spa",
        "subtitle": "Mandala Dreams",
    },
    {
        "id": "lapping_lake",
        "source": "ambient_lapping_lake.mp3",
        "label": "Lapping Lake Water",
        "subtitle": "Nature SFX",
    },
]


def _copy_media(source_name: str, dest_dir: str, dest_name: str) -> None:
    os.makedirs(dest_dir, exist_ok=True)
    src = os.path.join(ASSETS_AUDIO_DIR, source_name)
    dst = os.path.join(dest_dir, dest_name)
    if not os.path.exists(src):
        raise FileNotFoundError(
            f"Bundled audio not found: {src}. Run from the repo so "
            f"assets/audio/ is reachable."
        )
    shutil.copyfile(src, dst)


def seed(force: bool = False) -> dict:
    """Populate the catalog with day-one content.

    Idempotent by default: if any content already exists it is left untouched
    (unless ``force`` wipes it first). Returns a small summary dict.
    """
    database.init_db()

    if force:
        database.clear_content()

    counts = database.content_counts()
    already = counts["stories"] or counts["sounds"] or counts["games"]
    if already and not force:
        return {"seeded": False, "reason": "catalog not empty", **counts}

    for order, story in enumerate(_STORY_SEED):
        ext = os.path.splitext(story["source"])[1]
        dest_name = f"{story['id']}{ext}"
        _copy_media(story["source"], MEDIA_STORIES_DIR, dest_name)
        database.upsert_story(
            story["id"],
            {
                "title": story["title"],
                "series": story["series"],
                "narrator": story["narrator"],
                "teaser_subtitle": story["teaser_subtitle"],
                "excerpt": story["excerpt"],
                "coordinates": story["coordinates"],
                "swell_note": story["swell_note"],
                "media_path": f"stories/{dest_name}",
                "duration_label": story["duration_label"],
                "active": True,
                "sort_order": order,
            },
        )

    for order, sound in enumerate(_SOUND_SEED):
        ext = os.path.splitext(sound["source"])[1]
        dest_name = f"{sound['id']}{ext}"
        _copy_media(sound["source"], MEDIA_SOUNDS_DIR, dest_name)
        database.upsert_sound(
            sound["id"],
            {
                "label": sound["label"],
                "subtitle": sound["subtitle"],
                "media_path": f"sounds/{dest_name}",
                "active": True,
                "sort_order": order,
            },
        )

    for order, game_key in enumerate(GAME_KEYS):
        database.upsert_featured_game(
            game_key,
            {
                "active": game_key in ELIGIBLE_FOR_ROTATION,
                "effective_from": "2026-01-01",
                "sort_order": order,
            },
        )

    return {"seeded": True, **database.content_counts()}


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed the Wavemind catalog.")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Wipe existing catalog + recopy media, then reseed from scratch.",
    )
    args = parser.parse_args()
    result = seed(force=args.force)
    print(result)


if __name__ == "__main__":
    main()
