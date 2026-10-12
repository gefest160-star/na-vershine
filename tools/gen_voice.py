# -*- coding: utf-8 -*-
"""Озвучка реплик игры «На вершине» нейросетевыми голосами (edge-tts).

Реплики берутся прямо из scripts/story.gd (вызовы say / think / me), поэтому после правки
текста достаточно запустить скрипт ещё раз — он досоздаст только новые и изменённые строки.

    tools/.venv/Scripts/python tools/gen_voice.py            # всё, чего ещё нет
    tools/.venv/Scripts/python tools/gen_voice.py --only patron,marc --force
    tools/.venv/Scripts/python tools/gen_voice.py --list     # только показать список реплик

Чтобы сменить голос персонажа, поправьте таблицу CAST ниже и перегенерируйте его реплики с --force.
Имя файла = первые 12 символов md5 от «персонаж|текст» — так же его ищет игра (audio.gd).
"""
import asyncio
import hashlib
import os
import random
import re
import sys

import numpy as np
import soundfile as sf
import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORY = os.path.join(ROOT, "scripts", "story.gd")
OUT = os.path.join(ROOT, "audio", "voice")
CACHE = os.path.join(ROOT, "tools", "voice_cache")

DMITRY = "ru-RU-DmitryNeural"
SVETLANA = "ru-RU-SvetlanaNeural"
ANDREW = "en-US-AndrewMultilingualNeural"
BRIAN = "en-US-BrianMultilingualNeural"
FLORIAN = "de-DE-FlorianMultilingualNeural"
REMY = "fr-FR-RemyMultilingualNeural"
GIUSEPPE = "it-IT-GiuseppeMultilingualNeural"
WILLIAM = "en-AU-WilliamMultilingualNeural"

# персонаж: (голос, темп, высота, поправка громкости в дБ)
CAST = {
    "me": (BRIAN, "-3%", "+0Hz", 0.0),
    "think": (BRIAN, "-9%", "-3Hz", -1.0),
    "patron": (ANDREW, "-9%", "-8Hz", 0.0),
    "phone": (ANDREW, "-9%", "-8Hz", 0.0),
    "waiter": (REMY, "+3%", "+3Hz", -1.0),
    "thug": (WILLIAM, "+6%", "-12Hz", 1.0),
    "thug2": (FLORIAN, "+10%", "-5Hz", 1.0),
    "clerk": (GIUSEPPE, "-2%", "-6Hz", -1.0),
    "traveler": (WILLIAM, "-6%", "-3Hz", -1.0),
    "semyonov": (REMY, "-13%", "-11Hz", 0.0),
    "reiner": (FLORIAN, "-3%", "+1Hz", 0.0),
    "marc": (GIUSEPPE, "-13%", "-15Hz", 0.0),
    "lady": (SVETLANA, "-3%", "-2Hz", -1.0),
    "guest_m": (REMY, "-7%", "-9Hz", -1.0),
    "guest_f": (SVETLANA, "-7%", "+3Hz", -1.0),
}
# хор за дверью — несколько голосов сразу
CHORUS = {
    "voices": [(ANDREW, "-16%", "-12Hz"), (BRIAN, "-14%", "-10Hz"), (GIUSEPPE, "-15%", "-14Hz"),
               (SVETLANA, "-14%", "-10Hz"), (FLORIAN, "-15%", "-8Hz")],
}
TARGET_RMS_DB = -21.0


def line_id(spk, text):
    return hashlib.md5((spk + "|" + text).encode("utf-8")).hexdigest()[:12]


def collect():
    src = open(STORY, encoding="utf-8").read()
    found = []
    pat = re.compile(r'await (say|think|me)\((?:"([a-z_0-9]+)",\s*)?"([^"]*)"\)')
    for m in pat.finditer(src):
        kind, spk, text = m.group(1), m.group(2), m.group(3)
        if kind == "think":
            spk = "think"
        elif kind == "me":
            spk = "me"
        if spk is None or spk == "narr":
            continue
        found.append((spk, text))
    seen = set()
    out = []
    for spk, text in found:
        key = (spk, text)
        if key not in seen:
            seen.add(key)
            out.append(key)
    return out


def tts_text(text):
    t = text.replace("№", "номер ")
    for ch in "«»„“":
        t = t.replace(ch, "")
    t = t.replace("...", "…")
    return re.sub(r"\s+", " ", t).strip()


async def synth(voice, rate, pitch, text):
    """Сырой mp3 из кеша или от сервиса (с повторами — сервис иногда отвечает 403)."""
    os.makedirs(CACHE, exist_ok=True)
    key = hashlib.md5("|".join((voice, rate, pitch, text)).encode("utf-8")).hexdigest()[:16]
    path = os.path.join(CACHE, key + ".mp3")
    if os.path.exists(path) and os.path.getsize(path) > 800:
        return path
    last = None
    for attempt in range(45):
        try:
            com = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
            await com.save(path)
            if os.path.getsize(path) > 800:
                return path
        except Exception as e:  # noqa
            last = e
        # отказы сервиса случайны и мгновенны — первые повторы делаем быстро
        await asyncio.sleep((0.5 if attempt < 12 else 2.5) + random.random() * 0.5)
    raise RuntimeError("не удалось озвучить: %s (%s)" % (text[:40], last))


def load_mono(path):
    data, sr = sf.read(path, dtype="float32", always_2d=True)
    return data.mean(axis=1), sr


def trim(x, sr, thr_db=-46.0, pad=0.05):
    thr = 10 ** (thr_db / 20.0)
    win = max(1, int(sr * 0.01))
    env = np.sqrt(np.convolve(x ** 2, np.ones(win) / win, mode="same"))
    idx = np.where(env > thr)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(sr * pad))
    b = min(len(x), idx[-1] + int(sr * (pad + 0.06)))
    y = x[a:b].copy()
    k = min(len(y) // 2, int(sr * 0.008))
    if k > 0:
        y[:k] *= np.linspace(0, 1, k)
        y[-k:] *= np.linspace(1, 0, k)
    return y


def squeeze_silence(x, sr, max_gap=0.8, thr_db=-44.0):
    """Нейроголоса иногда вставляют паузы по нескольку секунд — ужимаем их до max_gap."""
    win = max(1, int(sr * 0.01))
    peak = np.max(np.abs(x)) + 1e-9
    env = np.sqrt(np.convolve((x / peak) ** 2, np.ones(win) / win, mode="same"))
    quiet = env < 10 ** (thr_db / 20.0)
    out = []
    i = 0
    n = len(x)
    keep = int(sr * max_gap / 2)
    while i < n:
        if not quiet[i]:
            j = i
            while j < n and not quiet[j]:
                j += 1
            out.append(x[i:j])
            i = j
        else:
            j = i
            while j < n and quiet[j]:
                j += 1
            seg = x[i:j]
            if j - i > int(sr * max_gap) and i > 0 and j < n:
                a = seg[:keep].copy()
                b = seg[-keep:].copy()
                k = min(len(a), int(sr * 0.01))
                a[-k:] *= np.linspace(1, 0, k)
                b[:k] *= np.linspace(0, 1, k)
                out.append(a)
                out.append(b)
            else:
                out.append(seg)
            i = j
    return np.concatenate(out) if out else x


def normalize(x, gain_db=0.0):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    g = 10 ** ((TARGET_RMS_DB + gain_db) / 20.0) / rms
    y = x * g
    peak = np.max(np.abs(y)) + 1e-9
    if peak > 0.97:
        y *= 0.97 / peak
    return y


def write_ogg(path, x, sr):
    # пишем кусками: libsndfile падает при записи длинного OGG одним буфером
    data = x.astype(np.float32)
    with sf.SoundFile(path, "w", samplerate=sr, channels=1, format="OGG", subtype="VORBIS") as fh:
        for i in range(0, len(data), sr // 4):
            fh.write(data[i:i + sr // 4])


async def make_line(spk, text):
    out = os.path.join(OUT, line_id(spk, text) + ".ogg")
    t = tts_text(text)
    if spk in CHORUS:
        parts = []
        sr = 24000
        for voice, rate, pitch in CHORUS[spk]:
            x, sr = load_mono(await synth(voice, rate, pitch, t))
            parts.append(normalize(squeeze_silence(trim(x, sr), sr)))
        n = max(len(p) for p in parts) + int(sr * 0.12)
        mix = np.zeros(n, dtype=np.float32)
        rnd = random.Random(line_id(spk, text))
        for p in parts:
            off = int(sr * rnd.uniform(0.0, 0.07))
            mix[off:off + len(p)] += p
        write_ogg(out, normalize(mix, 1.0), sr)
        return
    voice, rate, pitch, gain = CAST[spk]
    x, sr = load_mono(await synth(voice, rate, pitch, t))
    write_ogg(out, normalize(squeeze_silence(trim(x, sr), sr), gain), sr)


async def main():
    args = sys.argv[1:]
    force = "--force" in args
    only = None
    limit = None
    for i, a in enumerate(args):
        if a == "--only" and i + 1 < len(args):
            only = set(args[i + 1].split(","))
        if a == "--limit" and i + 1 < len(args):
            limit = int(args[i + 1])
    lines = collect()
    unknown = sorted({s for s, _ in lines if s not in CAST and s not in CHORUS})
    if unknown:
        print("НЕТ ГОЛОСА для персонажей:", ", ".join(unknown))
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(ROOT, "tools", "voice_lines.tsv"), "w", encoding="utf-8") as f:
        for spk, text in lines:
            f.write("%s\t%s\t%s\n" % (line_id(spk, text), spk, text))
    counts = {}
    for spk, _ in lines:
        counts[spk] = counts.get(spk, 0) + 1
    print("реплик: %d, знаков: %d" % (len(lines), sum(len(t) for _, t in lines)))
    print("по персонажам:", ", ".join("%s=%d" % kv for kv in sorted(counts.items(), key=lambda kv: -kv[1])))
    if "--list" in args:
        return
    todo = []
    for spk, text in lines:
        if spk not in CAST and spk not in CHORUS:
            continue
        if only and spk not in only:
            continue
        path = os.path.join(OUT, line_id(spk, text) + ".ogg")
        if force or not os.path.exists(path):
            todo.append((spk, text))
    if limit:
        todo = todo[:limit]
    print("к озвучке: %d" % len(todo))
    fails = 0
    done = 0
    sem = asyncio.Semaphore(3)

    async def worker(spk, text):
        nonlocal fails, done
        async with sem:
            try:
                await make_line(spk, text)
            except Exception as e:  # noqa
                fails += 1
                print("  ОШИБКА [%s] %s -> %s" % (spk, text[:50], str(e)[:120]), flush=True)
                return
            done += 1
            if done % 10 == 0 or done == len(todo):
                print("  %d / %d" % (done, len(todo)), flush=True)

    await asyncio.gather(*(worker(s, t) for s, t in todo))
    valid = {line_id(s, t) + ".ogg" for s, t in lines}
    stale = [f for f in os.listdir(OUT) if f.endswith(".ogg") and f not in valid]
    if stale:
        print("устаревших файлов (текст изменился): %d — можно удалить: %s" % (len(stale), ", ".join(stale[:8])))
    print("ГОТОВО. ошибок: %d" % fails)


if __name__ == "__main__":
    asyncio.run(main())
