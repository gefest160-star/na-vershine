# -*- coding: utf-8 -*-
"""Синтез звуковых эффектов и фоновых петель для игры «На вершине».

Запуск:  tools/.venv/Scripts/python tools/gen_sfx.py [имя ...]
Без аргументов пересоздаёт все звуки, которых ещё нет в audio/sfx (или все — с --force).
Файлы, помеченные в KEEP (заменённые живыми записями), не перезаписываются.
"""
import os
import sys
import numpy as np
import soundfile as sf

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "sfx")
rng = np.random.default_rng(1894)


# ---------- кирпичики ----------

def n_(sec):
    return int(SR * sec)


def noise(sec):
    return rng.standard_normal(n_(sec))


def brown(sec):
    x = np.cumsum(rng.standard_normal(n_(sec)))
    x -= np.linspace(x[0], x[-1], len(x))
    return x / (np.max(np.abs(x)) + 1e-9)


def filt(x, lo=None, hi=None, order=4):
    """Полосовой фильтр с нулевой фазой (через БПФ)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    H = np.ones_like(f)
    if lo:
        H *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-6)) ** (2 * order))
    if hi:
        H *= 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order))
    return np.fft.irfft(X * H, len(x))


def t_(sec):
    return np.arange(n_(sec)) / SR


def decay(sec, tau):
    return np.exp(-t_(sec) / tau)


def sweep(sec, f0, f1, curve=1.0):
    t = t_(sec)
    k = (t / max(sec, 1e-9)) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def ping(sec, freq, tau, phase=0.0):
    t = t_(sec)
    return np.sin(2 * np.pi * freq * t + phase) * np.exp(-t / tau)


def place(buf, x, at, gain=1.0):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[: j - i] * gain
    return buf


def fade(x, fin=0.005, fout=0.02):
    a = n_(fin)
    b = n_(fout)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def fftconv(x, ir):
    n = len(x) + len(ir) - 1
    m = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)[:n]


def reverb(x, dur=1.2, mix=0.25, bright=4500, pre=0.012):
    ir = noise(dur) * decay(dur, dur / 5.0)
    ir = filt(ir, 150, bright, 2)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = fftconv(x, ir)
    out = np.zeros(len(wet) + n_(pre))
    out[: len(x)] += x * (1.0 - mix * 0.5)
    out[n_(pre): n_(pre) + len(wet)] += wet * mix
    return out


def loopable(x, xf=0.6):
    """Плавное зацикливание: хвост вмешивается в начало."""
    k = n_(xf)
    head = x[:k].copy()
    tail = x[-k:].copy()
    w = np.linspace(0, 1, k)
    body = x[: len(x) - k].copy()
    body[:k] = head * np.sqrt(w) + tail * np.sqrt(1 - w)
    return body


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def save(name, x, peak=0.9):
    x = norm(np.asarray(x, dtype=np.float64), peak)
    sf.write(os.path.join(OUT, name + ".wav"), x.astype(np.float32), SR, subtype="PCM_16")
    print("  %-14s %.2f c" % (name, len(x) / SR))


# ---------- эффекты ----------

def blip():
    x = sweep(0.05, 1150, 820) * decay(0.05, 0.016)
    save("blip", fade(x, 0.002, 0.01), 0.35)


def steps():
    for i in range(1, 5):
        d = 0.16
        x = np.zeros(n_(d))
        f0 = rng.uniform(85, 115)
        place(x, sweep(0.09, f0, f0 * 0.55) * decay(0.09, 0.028), 0.0, 0.9)
        place(x, filt(noise(0.05), 250, rng.uniform(900, 1500)) * decay(0.05, 0.012), 0.0, 0.5)
        place(x, filt(noise(0.03), 1500, 5000) * decay(0.03, 0.006), 0.004, 0.12)
        place(x, filt(noise(0.06), 200, 800) * decay(0.06, 0.02), 0.07, 0.12)   # носок
        save("step%d" % i, fade(reverb(x, 0.25, 0.12, 3000), 0.001, 0.03), 0.6)


def door():
    x = np.zeros(n_(1.1))
    # скрип петель
    t = t_(0.42)
    creak_f = 310 + 50 * np.sin(2 * np.pi * 3.1 * t) + rng.standard_normal(len(t)).cumsum() * 0.15
    creak = np.sign(np.sin(2 * np.pi * np.cumsum(creak_f) / SR)) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t) ** 2)
    creak = filt(creak, 500, 2600) * np.hanning(len(t))
    place(x, creak, 0.0, 0.16)
    # щелчок замка и удар полотна
    place(x, filt(noise(0.03), 1500, 6000) * decay(0.03, 0.006), 0.5, 0.5)
    place(x, ping(0.08, 1900, 0.02), 0.5, 0.2)
    place(x, sweep(0.22, 120, 60) * decay(0.22, 0.06), 0.56, 1.0)
    place(x, filt(noise(0.14), 80, 600) * decay(0.14, 0.035), 0.56, 0.8)
    save("door", fade(reverb(x, 0.8, 0.22, 2500), 0.002, 0.08), 0.8)


def punch():
    for i in (1, 2):
        x = np.zeros(n_(0.35))
        place(x, sweep(0.16, rng.uniform(120, 150), 45) * decay(0.16, 0.045), 0.0, 1.0)
        place(x, filt(noise(0.09), 70, 500) * decay(0.09, 0.028), 0.0, 0.9)
        place(x, filt(noise(0.03), 900, 3500) * decay(0.03, 0.007), 0.002, 0.45)
        save("punch%d" % i, fade(np.tanh(reverb(x, 0.3, 0.12, 2500) * 2.2), 0.001, 0.05), 0.85)


def glass():
    x = np.zeros(n_(1.6))
    place(x, filt(noise(0.06), 1800, 11000) * decay(0.06, 0.012), 0.0, 1.0)
    place(x, sweep(0.1, 180, 70) * decay(0.1, 0.03), 0.0, 0.5)
    for _ in range(46):
        at = abs(rng.normal(0.0, 0.3))
        f = rng.uniform(2200, 9000)
        place(x, ping(0.2, f, rng.uniform(0.015, 0.09), rng.uniform(0, 6.28)), at, rng.uniform(0.05, 0.3) * np.exp(-at * 2.0))
    for _ in range(18):
        place(x, filt(noise(0.012), 3000, 12000) * decay(0.012, 0.003), rng.uniform(0.02, 0.9), rng.uniform(0.05, 0.25))
    save("glass", fade(reverb(x, 0.9, 0.2, 9000), 0.001, 0.2), 0.85)


def gunshot():
    x = np.zeros(n_(2.6))
    place(x, filt(noise(0.012), 800, 14000) * decay(0.012, 0.002), 0.0, 1.4)       # дульный щелчок
    place(x, filt(noise(0.3), 250, 7000) * decay(0.3, 0.03), 0.001, 1.0)           # хлопок
    place(x, sweep(0.35, 160, 42) * decay(0.35, 0.07), 0.0, 1.1)                   # тело
    place(x, filt(noise(0.2), 60, 350) * decay(0.2, 0.05), 0.0, 0.9)
    dry = np.tanh(x * 2.5)
    tail = filt(noise(2.4), 90, 2200, 2) * decay(2.4, 0.5)
    tail *= 1.0 - np.exp(-t_(2.4) / 0.03)
    y = np.zeros(n_(2.8))
    place(y, dry, 0.0, 1.0)
    place(y, tail, 0.02, 0.22)
    place(y, filt(noise(0.5), 300, 3000) * decay(0.5, 0.1), 0.31, 0.1)            # отражение
    save("gunshot", fade(y, 0.0005, 0.4), 0.95)


def lighter():
    x = np.zeros(n_(1.7))
    # откидывается крышка
    for f, g in ((2950, 1.0), (4380, 0.7), (6150, 0.45), (8200, 0.25)):
        place(x, ping(0.25, f, 0.045, rng.uniform(0, 6.28)), 0.0, g * 0.5)
    place(x, filt(noise(0.012), 3000, 12000) * decay(0.012, 0.0025), 0.0, 0.9)
    # колёсико по кремню
    t = t_(0.075)
    ratchet = 0.4 + 0.6 * (np.sin(2 * np.pi * 210 * t) > 0.2)
    flint = filt(noise(0.075), 2500, 10000) * ratchet * np.hanning(len(t)) ** 0.5
    place(x, flint, 0.42, 0.75)
    place(x, filt(noise(0.006), 5000, 14000), 0.49, 0.5)
    # пламя
    fl = filt(noise(1.1), 140, 1400, 2)
    env = (1.0 - np.exp(-t_(1.1) / 0.04)) * np.exp(-t_(1.1) / 0.45)
    wob = 1.0 + 0.3 * np.sin(2 * np.pi * 11 * t_(1.1) + 1.0) * np.exp(-t_(1.1) / 0.3)
    place(x, fl * env * wob, 0.5, 0.22)
    save("lighter", fade(reverb(x, 0.35, 0.1, 9000), 0.001, 0.25), 0.8)


def bolt():
    x = np.zeros(n_(0.9))
    # затвор назад
    place(x, filt(noise(0.06), 800, 6000) * decay(0.06, 0.014), 0.0, 1.0)
    for f, g in ((1320, 0.5), (2140, 0.4), (3460, 0.3), (5200, 0.15)):
        place(x, ping(0.12, f, 0.022, rng.uniform(0, 6.28)), 0.0, g)
    # скольжение
    sc = filt(noise(0.13), 1400, 5000) * np.hanning(n_(0.13)) ** 2
    place(x, sc, 0.035, 0.16)
    # затвор вперёд — тяжелее
    place(x, filt(noise(0.08), 500, 5000) * decay(0.08, 0.018), 0.19, 1.25)
    for f, g in ((910, 0.55), (1710, 0.45), (2630, 0.35), (4100, 0.15)):
        place(x, ping(0.2, f, 0.035, rng.uniform(0, 6.28)), 0.19, g)
    place(x, sweep(0.08, 190, 110) * decay(0.08, 0.025), 0.19, 0.6)
    save("bolt", fade(np.tanh(reverb(x, 0.4, 0.14, 7000) * 1.6), 0.0005, 0.15), 0.9)


def paper():
    d = 0.5
    env = np.abs(filt(noise(d), None, 14, 2))
    env = env / (env.max() + 1e-9) * np.hanning(n_(d)) ** 0.7
    x = filt(noise(d), 1400, 9000) * env
    save("paper", fade(x, 0.005, 0.08), 0.45)


def pen():
    d = 1.9
    t = t_(d)
    strokes = np.clip(np.sin(2 * np.pi * 5.2 * t + 2.0 * np.sin(2 * np.pi * 0.9 * t)), 0, 1) ** 0.6
    gaps = (np.sin(2 * np.pi * 0.75 * t + 0.6) > -0.55).astype(float)
    x = filt(noise(d), 1800, 7500) * strokes * gaps
    save("pen", fade(x, 0.02, 0.2), 0.4)


def keys():
    x = np.zeros(n_(0.8))
    for _ in range(9):
        place(x, ping(0.15, rng.uniform(3200, 7800), rng.uniform(0.012, 0.045), rng.uniform(0, 6.28)), rng.uniform(0.0, 0.42), rng.uniform(0.2, 0.7))
    save("keys", fade(reverb(x, 0.3, 0.1, 9000), 0.001, 0.15), 0.5)


def locker():
    x = np.zeros(n_(0.9))
    place(x, filt(noise(0.03), 1200, 7000) * decay(0.03, 0.006), 0.0, 0.7)        # ключ
    place(x, filt(noise(0.08), 300, 3500) * decay(0.08, 0.02), 0.12, 1.0)         # засов
    for f, g in ((520, 0.6), (1180, 0.45), (2390, 0.3), (3650, 0.15)):
        place(x, ping(0.4, f, 0.09, rng.uniform(0, 6.28)), 0.12, g)
    place(x, sweep(0.12, 150, 80) * decay(0.12, 0.03), 0.12, 0.5)
    save("locker", fade(reverb(x, 0.7, 0.2, 5000), 0.001, 0.2), 0.75)


def thunder():
    for i in (1, 2, 3):
        d = rng.uniform(6.0, 8.0)
        t = t_(d)
        env = np.zeros(len(t))
        for _ in range(rng.integers(4, 8)):
            c = rng.uniform(0.1, d * 0.6)
            wdt = rng.uniform(0.25, 1.1)
            env += rng.uniform(0.4, 1.0) * np.exp(-((t - c) / wdt) ** 2)
        env *= np.exp(-t / (d * 0.42))
        env += 1.2 * np.exp(-((t - 0.12) / 0.09) ** 2)
        low = filt(brown(d), 25, 140, 2)
        mid = filt(noise(d), 80, 520, 2) * 0.35
        x = (low / (np.abs(low).max() + 1e-9) + mid / (np.abs(mid).max() + 1e-9) * 0.5) * env
        crack = filt(noise(0.5), 300, 5000) * decay(0.5, 0.07)
        if i != 2:
            place(x, crack, 0.08, 0.35)
        save("thunder%d" % i, fade(np.tanh(x * 1.5), 0.02, 1.5), 0.92)


def siren():
    d = 9.0
    t = t_(d)
    f = 760 + 160 * np.sin(2 * np.pi * t / 3.2 - 1.2)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    x = filt(x, 300, 1500, 2) * np.hanning(len(t)) ** 0.6
    save("siren", fade(reverb(x, 2.0, 0.6, 1500), 0.5, 1.5), 0.5)


# ---------- петли ----------

def rain():
    d = 11.0
    bed = filt(noise(d), 900, 9500, 2)
    slow = 1.0 + 0.18 * filt(noise(d), None, 0.6, 2) / 0.02
    slow = np.clip(slow, 0.7, 1.3)
    x = bed * slow * 0.5
    drops = np.zeros(n_(d))
    for _ in range(int(d * 320)):
        place(drops, filt(noise(0.004), 2000, 9000) * decay(0.004, 0.0012), rng.uniform(0, d - 0.01), rng.uniform(0.1, 0.9))
    x += drops * 0.8
    save("rain", loopable(x), 0.5)


def rain_heavy():
    d = 11.0
    x = filt(noise(d), 300, 11000, 2) * 0.6
    x += filt(noise(d), 60, 400, 2) * 0.35
    gust = 1.0 + 0.25 * np.sin(2 * np.pi * t_(d) / 5.5) + 0.12 * np.sin(2 * np.pi * t_(d) / 2.2 + 1.0)
    x *= gust
    drops = np.zeros(n_(d))
    for _ in range(int(d * 500)):
        place(drops, filt(noise(0.005), 1500, 8000) * decay(0.005, 0.0015), rng.uniform(0, d - 0.01), rng.uniform(0.1, 1.0))
    x += drops
    save("rain_heavy", loopable(x), 0.62)


def wind():
    d = 13.0
    t = t_(d)
    x = np.zeros(len(t))
    for lo, hi, per, ph in ((120, 320, 6.5, 0.0), (260, 620, 4.3, 1.7), (500, 1100, 3.1, 3.9)):
        g = 0.5 + 0.5 * np.sin(2 * np.pi * t / per + ph)
        x += filt(noise(d), lo, hi, 2) / 0.08 * g ** 2
    save("wind", loopable(x, 1.2), 0.5)


def hum():
    d = 8.0
    t = t_(d)
    x = 0.6 * np.sin(2 * np.pi * 50 * t) + 0.3 * np.sin(2 * np.pi * 100 * t + 0.4) + 0.12 * np.sin(2 * np.pi * 150 * t)
    x *= 1.0 + 0.08 * np.sin(2 * np.pi * 0.25 * t)
    x += filt(noise(d), 80, 900, 2) * 3.0
    save("hum", loopable(x, 0.5), 0.2)


def murmur():
    """Запасной вариант гула зала — если нет записи tools/gen_murmur.py."""
    d = 14.0
    t = t_(d)
    x = np.zeros(len(t))
    for _ in range(16):
        f0 = rng.uniform(95, 230)
        pitch = f0 * (1.0 + 0.12 * filt(noise(d), None, 2.0, 2) / 0.03)
        ph = 2 * np.pi * np.cumsum(pitch) / SR
        src = np.sign(np.sin(ph)) * 0.6 + np.sin(ph)
        syl = np.clip(filt(noise(d), None, rng.uniform(3.0, 5.5), 2) / 0.02, 0, None)
        phrase = (np.sin(2 * np.pi * t / rng.uniform(2.5, 6.0) + rng.uniform(0, 6.28)) > rng.uniform(-0.6, 0.2)).astype(float)
        phrase = filt(phrase, None, 3, 2)
        f1 = rng.uniform(350, 800)
        f2 = rng.uniform(1000, 2300)
        v = filt(src, f1 * 0.7, f1 * 1.4, 2) + 0.5 * filt(src, f2 * 0.8, f2 * 1.25, 2)
        x += v * syl * phrase * rng.uniform(0.4, 1.0)
    x = filt(x, 180, 3400, 2)
    for _ in range(18):
        place(x, ping(0.25, rng.uniform(3000, 6500), rng.uniform(0.02, 0.08)), rng.uniform(0.5, d - 1.0), rng.uniform(0.02, 0.07) * np.abs(x).max())
    save("murmur", loopable(reverb(x, 1.4, 0.4, 3000)[: len(x)], 1.0), 0.5)


def press():
    d = 2.4
    x = np.zeros(n_(d))
    t = t_(d)
    x += 0.12 * np.sin(2 * np.pi * 62 * t) + 0.06 * np.sin(2 * np.pi * 124 * t)
    x += filt(noise(d), 300, 2500, 2) * 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 0.6) ** 2)
    for k in range(4):
        at = k * 0.6
        place(x, sweep(0.12, 110, 55) * decay(0.12, 0.03), at, 0.8)
        place(x, filt(noise(0.05), 600, 4000) * decay(0.05, 0.012), at, 0.6)
        place(x, ping(0.1, 1450, 0.02), at + 0.3, 0.25)
        place(x, filt(noise(0.03), 1500, 6000) * decay(0.03, 0.006), at + 0.3, 0.4)
    save("press", x, 0.6)


def fire():
    d = 9.0
    x = filt(noise(d), 90, 900, 2) / 0.1 * 0.25
    x *= 1.0 + 0.3 * filt(noise(d), None, 4, 2) / 0.02
    for _ in range(int(d * 9)):
        place(x, filt(noise(0.01), 900, 7000) * decay(0.01, 0.002), rng.uniform(0, d - 0.02), rng.uniform(0.2, 1.3) ** 2)
    save("fire", loopable(x, 0.7), 0.5)


def waves():
    d = 15.0
    t = t_(d)
    swell = 0.35 + 0.65 * np.clip(np.sin(2 * np.pi * t / 7.5 - 0.5), 0, 1) ** 1.5
    x = filt(noise(d), 80, 1400, 2) / 0.12 * swell
    hiss = filt(noise(d), 1500, 7000, 2) / 0.3 * np.clip(np.sin(2 * np.pi * t / 7.5 - 1.3), 0, 1) ** 3
    x += hiss * 0.35
    save("waves", loopable(x, 1.0), 0.55)


def ring():
    d = 3.6
    x = np.zeros(n_(d))
    t = t_(1.15)
    clap = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 26 * t))
    bell = np.sin(2 * np.pi * 1340 * t) + 0.8 * np.sin(2 * np.pi * 1570 * t) + 0.3 * np.sin(2 * np.pi * 2710 * t) + 0.15 * np.sin(2 * np.pi * 4020 * t)
    b = bell * clap * np.minimum(1.0, t / 0.01)
    b[-n_(0.25):] *= np.exp(-t_(0.25) / 0.06)
    place(x, b, 0.05, 1.0)
    save("ring", reverb(x, 0.4, 0.12, 6000)[: n_(d)], 0.55)


ALL = {
    "blip": blip, "step": steps, "door": door, "punch": punch, "glass": glass, "gunshot": gunshot,
    "lighter": lighter, "bolt": bolt, "paper": paper, "pen": pen, "keys": keys, "locker": locker,
    "thunder": thunder, "siren": siren, "rain": rain, "rain_heavy": rain_heavy, "wind": wind, "hum": hum,
    "murmur": murmur, "press": press, "fire": fire, "waves": waves, "ring": ring,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    keep_path = os.path.join(OUT, "KEEP.txt")
    keep = set()
    if os.path.exists(keep_path):
        keep = {l.strip() for l in open(keep_path, encoding="utf-8") if l.strip() and not l.startswith("#")}
    for name, fn in ALL.items():
        if args and name not in args:
            continue
        if name in keep and name not in args:
            print("  %-14s (оставлена живая запись)" % name)
            continue
        exists = any(f.startswith(name) and f.endswith(".wav") for f in os.listdir(OUT))
        if exists and not force and not args:
            continue
        fn()
    print("готово:", OUT)
