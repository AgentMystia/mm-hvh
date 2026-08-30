#!/usr/bin/env python3
"""Distinct CS:GO-style gunshots. R8 must not share the Deagle sample."""
from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np

OUT = Path("/workspace/assets/sounds/weapons")
SR = 22050


def write_wav(path: Path, samples: np.ndarray) -> None:
    samples = np.clip(samples, -1.0, 1.0)
    pcm = (samples * 32767.0).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(path.name, f"{len(samples) / SR:.3f}s")


def env_exp(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    a = 1.0 - np.exp(-t / max(attack, 1e-5))
    a /= a.max() or 1.0
    d = np.exp(-t / max(decay, 1e-5))
    return a * d


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n).astype(np.float64)


def tone(n: int, freq: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)


def band_noise(n: int, rng: np.random.Generator, lo: float, hi: float) -> np.ndarray:
    x = noise(n, rng)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spec[(freqs < lo) | (freqs > hi)] *= 0.04
    y = np.fft.irfft(spec, n)
    y /= np.max(np.abs(y)) or 1.0
    return y


def revolver_shot() -> np.ndarray:
    """Heavy .44 magnum boom — longer, lower, not a Deagle crack."""
    rng = np.random.default_rng(44)
    n = int(SR * 1.35)
    t = np.arange(n) / SR
    boom = band_noise(n, rng, 40, 420) * env_exp(n, 0.0008, 0.22) * 0.95
    body = band_noise(n, rng, 200, 1800) * env_exp(n, 0.0004, 0.09) * 0.55
    crack = band_noise(n, rng, 1800, 6500) * env_exp(n, 0.0002, 0.018) * 0.35
    thump = tone(n, 72, 0.18) * 0.45 + tone(n, 118, 0.12) * 0.22
    thump *= np.exp(-t / 0.16)
    # cylinder ring
    ring = tone(n, 1850, 0.07) * 0.08 * np.exp(-t / 0.05)
    s = boom + body + crack + thump + ring
    s /= np.max(np.abs(s)) or 1.0
    return s * 0.95


def revolver_cock() -> np.ndarray:
    rng = np.random.default_rng(8)
    n = int(SR * 0.22)
    t = np.arange(n) / SR
    click = band_noise(n, rng, 800, 7000) * env_exp(n, 0.0004, 0.012) * 0.7
    metal = tone(n, 2400, 0.04) * 0.25 * np.exp(-t / 0.03)
    second = np.zeros_like(click)
    off = int(0.07 * SR)
    second[off:] = (band_noise(n - off, rng, 400, 3000) * env_exp(n - off, 0.0003, 0.02) * 0.45)
    s = click + metal
    s[: n - off] += second[: n - off] * 0.0
    s += np.pad(second, (off, 0), mode="constant")[:n]
    s /= np.max(np.abs(s)) or 1.0
    return s * 0.7


def elite_shot() -> np.ndarray:
    """9mm dualies — sharper and thinner than Glock sample."""
    rng = np.random.default_rng(92)
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    crack = band_noise(n, rng, 900, 8000) * env_exp(n, 0.0002, 0.028) * 0.9
    body = band_noise(n, rng, 250, 1400) * env_exp(n, 0.0003, 0.05) * 0.35
    snap = tone(n, 2100, 0.03) * 0.12 * np.exp(-t / 0.02)
    s = crack + body + snap
    s /= np.max(np.abs(s)) or 1.0
    return s * 0.88


def main() -> None:
    write_wav(OUT / "revolver-1.wav", revolver_shot())
    write_wav(OUT / "revolver_cock.wav", revolver_cock())
    write_wav(OUT / "elite-1.wav", elite_shot())


if __name__ == "__main__":
    main()
