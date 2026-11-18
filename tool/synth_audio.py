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


def stone_settle():
    """A short, non-looping dull stone-on-stone thud/clink for Stone Cairn
    Balance: a low thump (filtered noise burst) plus a brief higher clink
    overtone, both decaying fast. just_audio's `setPitch` varies this per
    stone so repeated placements don't sound identical."""
    dur = 0.45
    n = int(dur * SR)
    out = [0.0] * n
    lp = 0.0
    for i in range(n):
        t = i / SR
        white = random.uniform(-1.0, 1.0)
        lp += 0.06 * (white - lp)  # soft low-pass -> dull thump body
        thump_env = math.exp(-t / 0.09)
        clink = math.sin(2 * math.pi * 1400 * t) * math.exp(-t / 0.04) * 0.25
        out[i] = lp * thump_env * 0.9 + clink
    return normalize(out, 0.85)


def stone_collapse():
    """A short tumbling-stones clatter for Stone Cairn Balance's toppled-tower
    moment: several overlapping dull thumps of falling/colliding stones at
    staggered times, decaying in amplitude, plus a little high-passed
    "clatter" noise for the scatter at the end."""
    dur = 0.9
    n = int(dur * SR)
    out = [0.0] * n

    def thump(start_t, amp, lp_coeff=0.06, body=0.09):
        start = int(start_t * SR)
        lp = 0.0
        for i in range(int(body * SR)):
            idx = start + i
            if idx >= n:
                break
            t = i / SR
            white = random.uniform(-1.0, 1.0)
            lp += lp_coeff * (white - lp)
            out[idx] += lp * math.exp(-t / (body * 0.45)) * amp

    # Staggered thumps as stones hit and tumble, roughly loudest first.
    starts = [0.0, 0.08, 0.17, 0.24, 0.34, 0.46, 0.6]
    for i, s in enumerate(starts):
        thump(s, amp=0.9 * (0.82 ** i))

    # A scatter of high-passed clatter noise trailing off at the end.
    hp_y = 0.0
    hp_x = 0.0
    clatter_start = int(0.3 * SR)
    for i in range(clatter_start, n):
        t = (i - clatter_start) / SR
        white = random.uniform(-1.0, 1.0)
        hp_y = 0.85 * (hp_y + white - hp_x)
        hp_x = white
        out[i] += hp_y * 0.12 * math.exp(-t / 0.35)

    return normalize(out, 0.9)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav("foghorn_bell.wav", foghorn_bell())
    write_wav("stone_settle.wav", stone_settle())
    write_wav("stone_collapse.wav", stone_collapse())
    print("done")
