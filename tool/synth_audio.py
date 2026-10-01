#!/usr/bin/env python3
"""Synthesize royalty-free, seamlessly-loopable ambient placeholder beds for
TideWell (Stage 2 audio). Pure stdlib only (wave/struct/math/random) — no numpy.

Outputs mono 22.05 kHz 16-bit PCM WAV files into assets/audio/. Each loop is
built with a short head/tail crossfade so LoopMode.one in just_audio wraps with
no audible click. Tonal content uses integer cycle counts over the loop length
so phase is continuous across the wrap point.
"""

import math
import os
import random
import struct
import wave

SR = 22050
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets", "audio",
)
# Fallback when run from an unexpected cwd: resolve relative to the project.
if not os.path.isdir(os.path.dirname(OUT_DIR)):
    OUT_DIR = "/Users/dipmacmini/Documents/AI_apps/TideWellApp/assets/audio"

random.seed(1904)  # deterministic output across runs


def crossfade_loop(samples, fade):
    """Return a seamless loop of length len(samples)-fade by crossfading the
    tail `fade` samples back over the head."""
    n = len(samples) - fade
    out = list(samples[:n])
    for i in range(fade):
        w = i / fade  # 0 -> head fully, 1 -> ...
        out[i] = samples[i] * w + samples[n + i] * (1.0 - w)
    return out


def normalize(samples, peak=0.9):
    m = max(1e-9, max(abs(s) for s in samples))
    g = peak / m
    return [s * g for s in samples]


def write_wav(name, samples):
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(bytes(frames))
    print(f"wrote {path} ({len(samples)/SR:.1f}s)")


def rolling_deep_sea(body_s=18.0, fade_s=0.5):
    """Low-frequency ocean swell: brown-ish noise, heavy low-pass, slow swell."""
    n = int((body_s + fade_s) * SR)
    out = []
    brown = 0.0
    lp = 0.0
    for i in range(n):
        t = i / SR
        white = random.uniform(-1.0, 1.0)
        brown = brown * 0.985 + white * 0.08  # leaky integrator -> red-ish
        lp += 0.015 * (brown - lp)            # one-pole LP ~ 50 Hz
        # Two swell LFOs (integer cycles over body for continuity).
        swell = (0.55 + 0.45 * math.sin(2 * math.pi * 2 * t / body_s)) \
            * (0.7 + 0.3 * math.sin(2 * math.pi * 3 * t / body_s + 1.1))
        out.append(lp * swell)
    out = crossfade_loop(out, int(fade_s * SR))
    return normalize(out, 0.85)


def steel_hull_rain(body_s=16.0, fade_s=0.5):
    """White-noise rain hiss with high-pass colouring and gentle gusts."""
    n = int((body_s + fade_s) * SR)
    out = []
    hp_y = 0.0
    hp_x = 0.0
    for i in range(n):
        t = i / SR
        white = random.uniform(-1.0, 1.0)
        # One-pole high-pass to push energy toward "hiss".
        hp_y = 0.9 * (hp_y + white - hp_x)
        hp_x = white
        gust = 0.75 + 0.25 * math.sin(2 * math.pi * 2 * t / body_s + 0.5)
        out.append(hp_y * 0.5 * gust)
    out = crossfade_loop(out, int(fade_s * SR))
    return normalize(out, 0.6)


def foghorn_bell(body_s=18.0, fade_s=0.5):
    """Low foghorn drone (beating sines) + a soft decaying bell every 6 s."""
    n = int((body_s + fade_s) * SR)
    out = [0.0] * n

    def intfreq(f):
        # Snap to an integer number of cycles over the body for seamless wrap.
        cycles = max(1, round(f * body_s))
        return cycles / body_s

    f1 = intfreq(110.0)
    f2 = intfreq(116.0)  # slight beating against f1
    for i in range(n):
        t = i / SR
        # Foghorn breathes in/out slowly (2 cycles over the loop).
        env = 0.5 + 0.5 * math.sin(2 * math.pi * 2 * t / body_s - math.pi / 2)
        drone = (math.sin(2 * math.pi * f1 * t)
                 + 0.7 * math.sin(2 * math.pi * f2 * t)) * 0.18 * env
        out[i] += drone

    # Bells: struck every 6 s, exponential decay. 3 strikes over 18 s loop.
    bell_period = int(6.0 * SR)
    bf1 = 523.25  # C5
    bf2 = 1046.5  # octave partial
    decay = 1.8   # seconds
    for strike in range(int(body_s // 6.0) + 1):
        start = strike * bell_period
        for k in range(int(decay * SR)):
            idx = start + k
            if idx >= n:
                break
            tt = k / SR
            amp = math.exp(-tt / 0.6) * 0.35
            out[idx] += (math.sin(2 * math.pi * bf1 * tt)
                         + 0.5 * math.sin(2 * math.pi * bf2 * tt)) * amp
    out = crossfade_loop(out, int(fade_s * SR))
    return normalize(out, 0.8)


def tidal_breath(body_s=19.2, fade_s=0.6):
    """Calm breathing-pace pad: soft low drone + fifth, under a slow swell LFO
    pulsing at a ~9.6 s breathe cycle (two cycles over the loop), plus a faint
    ocean wash. Meant to sit *under* the Tidal Breath visual exercise."""
    n = int((body_s + fade_s) * SR)
    out = []
    lp = 0.0

    def intfreq(f):
        cycles = max(1, round(f * body_s))
        return cycles / body_s

    root = intfreq(128.0)      # ~C3
    fifth = intfreq(192.0)     # perfect fifth
    for i in range(n):
        t = i / SR
        # Breathing LFO: 2 full breaths over the loop (~9.6 s each).
        breathe = 0.5 + 0.5 * math.sin(2 * math.pi * 2 * t / body_s - math.pi / 2)
        pad = (math.sin(2 * math.pi * root * t)
               + 0.6 * math.sin(2 * math.pi * fifth * t)) * 0.16
        white = random.uniform(-1.0, 1.0)
        lp += 0.01 * (white - lp)  # very soft wash
        out.append(pad * (0.4 + 0.6 * breathe) + lp * 0.25 * breathe)
    out = crossfade_loop(out, int(fade_s * SR))
    return normalize(out, 0.7)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav("rolling_deep_sea.wav", rolling_deep_sea())
    write_wav("steel_hull_rain.wav", steel_hull_rain())
    write_wav("foghorn_bell.wav", foghorn_bell())
    write_wav("tidal_breath.wav", tidal_breath())
    print("done")
