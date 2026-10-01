# Audio asset generation (Stage 2 placeholders)

All audio in `assets/audio/` is royalty-free placeholder material generated
locally on macOS — nothing is fetched from the internet. Swap these for real
narration / sound design later; the Dart paths live in `lib/core/app_assets.dart`.

## Ambient beds (seamless loops)

Synthesized with pure-Python stdlib (`wave`/`struct`/`math`/`random`, no numpy).
Each loop uses a head/tail crossfade so `LoopMode.one` wraps without a click, and
tonal content snaps to an integer number of cycles over the loop length.

```bash
python3 tool/synth_audio.py
```

Produces (mono, 22.05 kHz, 16-bit WAV):

- `rolling_deep_sea.wav` — brown-ish noise, heavy low-pass, slow swell LFO
- `steel_hull_rain.wav`  — high-passed white-noise hiss with gentle gusts
- `foghorn_bell.wav`     — beating low drone + a soft decaying bell every 6 s
- `tidal_breath.wav`     — calm low pad + fifth under a ~9.6 s breathing LFO

## Narration placeholder (spoken word)

Generated from the actual Lighthouse chapter text with the macOS `say` command
(the `Daniel` en_GB voice — a warm baritone fitting Capt. Torben Lind), then
encoded to AAC/M4A with `afconvert` for Flutter compatibility:

```bash
say -v Daniel -r 160 -o lighthouse_chapter.aiff "<chapter text>"
afconvert -f m4af -d aac lighthouse_chapter.aiff assets/audio/lighthouse_chapter.m4a
rm lighthouse_chapter.aiff
```

Verify any regenerated file with `afinfo assets/audio/<file>`.
