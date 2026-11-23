"""Generates OneGame placeholder sound effects (royalty-free, pure synthesis).

Usage: python3 tools/gen_sfx.py  -> writes app/assets/audio/*.wav
"""
import pathlib
import wave

import numpy as np

SR = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "app" / "assets" / "audio"


def env(n, attack=0.005, release=0.08):
    e = np.ones(n)
    a, r = min(int(attack * SR), n // 4), min(int(release * SR), n // 2)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def tone(freq, dur, kind="sine", vol=0.5, decay=0.0):
    t = np.arange(int(dur * SR)) / SR
    f = np.full_like(t, freq) if np.isscalar(freq) else np.interp(t, np.linspace(0, dur, len(freq)), freq)
    phase = 2 * np.pi * np.cumsum(f) / SR
    if kind == "square":
        s = np.sign(np.sin(phase)) * 0.6
    elif kind == "tri":
        s = 2 / np.pi * np.arcsin(np.sin(phase))
    else:
        s = np.sin(phase)
    if decay:
        s *= np.exp(-decay * t)
    return s * vol * env(len(t))


def bell(freq, dur, vol=0.5):
    t = np.arange(int(dur * SR)) / SR
    s = sum(a * np.sin(2 * np.pi * freq * m * t) for m, a in [(1, 1), (2.76, 0.5), (5.4, 0.25), (8.9, 0.12)])
    return s * vol * np.exp(-3 * t) * env(len(t), 0.002, 0.05) / 1.9


def noise(dur, vol=0.4, decay=20.0, seed=1):
    rng = np.random.default_rng(seed)
    t = np.arange(int(dur * SR)) / SR
    return rng.uniform(-1, 1, len(t)) * vol * np.exp(-decay * t) * env(len(t), 0.001, 0.02)


def cat(*parts):
    return np.concatenate(parts)


def silence(d):
    return np.zeros(int(d * SR))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def write(name, s):
    s = np.clip(s, -1, 1)
    data = (s * 32000).astype("<i2").tobytes()
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Alarm: 2 s of a fast twin-bell ring (the OneGame signature).
    ring = []
    for i in range(16):
        ring.append(mix(bell(1568 if i % 2 else 1760, 0.125, 0.55), noise(0.02, 0.15, 80, i)))
    write("alarm", cat(*ring))
    write("go", cat(tone(523, 0.08, "square", 0.3), tone([784, 1046], 0.25, "square", 0.35)))
    write("fin", cat(tone(784, 0.12, "tri", 0.5), tone(659, 0.12, "tri", 0.5), tone(523, 0.35, "tri", 0.5, 3)))
    write("highlight", cat(*[tone(f, 0.09, "square", 0.3) for f in (523, 659, 784, 1046)], tone(1318, 0.4, "square", 0.3, 4)))
    write("tick", mix(tone(1800, 0.03, "sine", 0.4, 60), noise(0.01, 0.2, 200)))
    write("countdown", tone(880, 0.12, "square", 0.3, 10))
    write("tap", tone(660, 0.05, "tri", 0.4, 40))
    write("hit", mix(noise(0.12, 0.6, 30, 3), tone([220, 90], 0.12, "sine", 0.6)))
    write("bounce", tone([420, 300], 0.07, "tri", 0.4, 30))
    write("score", cat(tone(880, 0.06, "square", 0.25), tone(1320, 0.12, "square", 0.25, 10)))
    write("miss", tone([300, 150], 0.3, "square", 0.25, 5))
    write("whoosh", noise(0.25, 0.35, 8, 9) * np.linspace(0.2, 1, int(0.25 * SR)))


if __name__ == "__main__":
    main()
