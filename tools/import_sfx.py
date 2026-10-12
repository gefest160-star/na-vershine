# -*- coding: utf-8 -*-
"""Подготовка живых записей (BigSoundBank, свободная лицензия) для игры.

Исходники лежат в tools/sfx_src/<id>.(flac|wav|ogg). Скрипт режет, зацикливает, нормализует
и кладёт результат в audio/sfx, заменяя синтезированные версии.

    python tools/import_sfx.py            # обработать всё
    python tools/import_sfx.py --events 0165 1704   # показать найденные «события» в записи
"""
import os
import shutil
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "sfx_src")
OUT = os.path.join(ROOT, "audio", "sfx")
BACKUP = os.path.join(ROOT, "tools", "sfx_synth_backup")
done = []


def load(sid, mono=True):
    for ext in (".wav", ".flac", ".ogg"):
        p = os.path.join(SRC, sid + ext)
        if os.path.exists(p):
            try:
                x, sr = sf.read(p, dtype="float32", always_2d=True)
            except Exception:
                continue
            if mono:
                x = x.mean(axis=1, keepdims=True)
            return x.astype(np.float64), sr
    raise FileNotFoundError(sid)


def cut(x, sr, a, b=None):
    i = int(a * sr)
    j = len(x) if b is None else int(b * sr)
    return x[i:j].copy()


def fade(x, sr, fin=0.004, fout=0.03):
    a = min(len(x) // 2, int(fin * sr))
    b = min(len(x) // 2, int(fout * sr))
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)[:, None]
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)[:, None]
    return x


def env_db(x, sr, win=0.008):
    m = x.mean(axis=1)
    w = max(1, int(sr * win))
    e = np.sqrt(np.convolve(m ** 2, np.ones(w) / w, mode="same")) + 1e-9
    return 20 * np.log10(e)


def events(x, sr, thr_db=-38.0, gap=0.12, min_len=0.02):
    """Интервалы, где запись громче порога (с допуском на короткие провалы)."""
    e = env_db(x, sr) > thr_db
    idx = np.where(e)[0]
    if len(idx) == 0:
        return []
    res = []
    start = idx[0]
    prev = idx[0]
    for i in idx[1:]:
        if i - prev > gap * sr:
            res.append((start / sr, prev / sr))
            start = i
        prev = i
    res.append((start / sr, prev / sr))
    return [(a, b) for a, b in res if b - a >= min_len]


def trim(x, sr, thr_db=-45.0, pad=0.01):
    e = np.where(env_db(x, sr) > thr_db)[0]
    if len(e) == 0:
        return x
    a = max(0, e[0] - int(pad * sr))
    b = min(len(x), e[-1] + int((pad + 0.05) * sr))
    return x[a:b].copy()


def loopable(x, sr, xf=1.5):
    k = int(xf * sr)
    w = np.linspace(0, 1, k)[:, None]
    body = x[: len(x) - k].copy()
    body[:k] = x[:k] * np.sqrt(w) + x[-k:] * np.sqrt(1 - w)
    return body


def norm_peak(x, peak=0.9):
    return x / (np.abs(x).max() + 1e-9) * peak


def norm_rms(x, db=-24.0, limit=0.97):
    rms = np.sqrt((x ** 2).mean()) + 1e-9
    y = x * (10 ** (db / 20.0) / rms)
    return np.tanh(y / limit) * limit if np.abs(y).max() > limit else y


def backup_synth(name):
    p = os.path.join(OUT, name + ".wav")
    if os.path.exists(p):
        os.makedirs(BACKUP, exist_ok=True)
        shutil.move(p, os.path.join(BACKUP, name + ".wav"))
        imp = p + ".import"
        if os.path.exists(imp):
            shutil.move(imp, os.path.join(BACKUP, name + ".wav.import"))


def save(name, x, sr, ogg=False):
    if x.shape[1] == 1:
        data = x[:, 0]
    else:
        data = x
    if ogg:
        backup_synth(name)
        # длинные OGG пишем кусками: libsndfile падает при записи большого буфера за раз
        with sf.SoundFile(os.path.join(OUT, name + ".ogg"), "w", samplerate=sr, channels=x.shape[1], format="OGG", subtype="VORBIS") as fh:
            block = sr // 4
            d32 = data.astype(np.float32)
            for i in range(0, len(d32), block):
                fh.write(d32[i:i + block])
    else:
        sf.write(os.path.join(OUT, name + ".wav"), data.astype(np.float32), sr, subtype="PCM_16")
    done.append(name)
    print("  %-12s %6.2f c  %s" % (name, len(x) / sr, "ogg" if ogg else "wav"), flush=True)


def one_shot(name, sid, a=0.0, b=None, peak=0.9, fout=0.05, do_trim=True, fin=0.003):
    x, sr = load(sid)
    x = cut(x, sr, a, b)
    if do_trim:
        x = trim(x, sr)
    save(name, norm_peak(fade(x, sr, fin, fout), peak), sr)


def loop(name, sid, a, b, db, xf=1.5, mono=False):
    x, sr = load(sid, mono=mono)
    x = loopable(cut(x, sr, a, b), sr, xf)
    save(name, norm_rms(x, db), sr, ogg=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    # --- финал: затвор, выстрел, зажигалка ---
    one_shot("bolt", "1985", peak=0.92, fout=0.03)
    one_shot("gunshot", "0437", peak=0.98, fout=0.4)
    # зажигалка: щелчок и тихое потрескивание — хвост приподнимаем мягкой компрессией
    x, sr = load("2131")
    x = cut(x, sr, 0.05, 2.2)
    x = np.sign(x) * np.abs(x / (np.abs(x).max() + 1e-9)) ** 0.62
    save("lighter", norm_peak(fade(x, sr, 0.01, 0.7), 0.9), sr)
    # --- гром ---
    one_shot("thunder1", "3113", peak=0.95, fout=0.8, fin=0.05, do_trim=False)
    one_shot("thunder2", "3114", peak=0.95, fout=1.5, fin=0.1, do_trim=False)
    one_shot("thunder3", "3179", peak=0.95, fout=2.0, fin=0.02, do_trim=False)
    # --- удары, стекло, бумага, перо, замок ---
    one_shot("punch1", "2460", peak=0.9, fout=0.08)
    one_shot("punch2", "2461", peak=0.9, fout=0.08)
    one_shot("punch3", "2463", peak=0.9, fout=0.08)
    one_shot("glass", "0148", peak=0.9, fout=0.2)
    one_shot("paper", "2212", peak=0.5, fout=0.1)
    one_shot("pen", "3236", peak=0.55, fout=0.2)
    one_shot("locker", "0037", 1.8, None, peak=0.8, fout=0.1, do_trim=False)
    one_shot("keys", "2425", 1.0, 2.05, peak=0.6, fout=0.15, do_trim=False)
    # --- дверь: берём конец записи — закрывание и щелчок ---
    x, sr = load("1704")
    ev = events(x, sr, -30.0, 0.25)
    start = max(0.0, ev[-1][0] - 0.9) if ev else 1.8
    save("door", norm_peak(fade(trim(cut(x, sr, start), sr), sr, 0.08, 0.15), 0.85), sr)
    # --- шаги: режем запись на отдельные шаги ---
    x, sr = load("0165")
    ev = events(x, sr, -34.0, 0.2, 0.03)
    n = 0
    for a, b in ev[1:9]:
        seg = cut(x, sr, max(0.0, a - 0.015), a + 0.4)
        n += 1
        save("step%d" % n, norm_peak(fade(seg, sr, 0.004, 0.12), 0.7), sr)
        if n >= 6:
            break
    # --- телефон: один звонок и пауза ---
    x, sr = load("3301")
    ev = events(x, sr, -40.0, 0.5, 0.5)
    a = ev[1][0] - 0.03
    ringpart = fade(cut(x, sr, a, a + 2.9), sr, 0.005, 0.3)
    full = np.zeros((int(4.4 * sr), 1))
    full[: len(ringpart)] = ringpart
    backup_synth("ring")
    save("ring", norm_peak(full, 0.75), sr, ogg=True)
    # --- петли ---
    loop("rain", "1289", 4.0, 30.0, -25.0, mono=True)
    loop("rain_heavy", "1290", 4.0, 30.0, -21.0, mono=True)
    loop("wind", "0146", 38.0, 66.0, -24.0, 2.0, mono=True)
    loop("murmur", "0624", 8.0, 44.0, -23.0, 2.0)
    loop("press", "3404", 3.0, 17.0, -23.0, 1.0)
    loop("waves", "1444", 20.0, 52.0, -23.0, 2.0)
    # камин: редкие щелчки на тихом фоне — нормализуем по верхнему процентилю
    x, sr = load("0030", mono=False)
    x = loopable(cut(x, sr, 3.0, 33.0), sr, 1.5)
    g = 0.45 / (np.percentile(np.abs(x), 99.95) + 1e-9)
    backup_synth("fire")
    save("fire", np.tanh(x * g), sr, ogg=True)

    with open(os.path.join(OUT, "KEEP.txt"), "w", encoding="utf-8") as f:
        f.write("# Эти звуки — живые записи (tools/import_sfx.py); gen_sfx.py их не перезаписывает.\n")
        for nme in sorted({d.rstrip("0123456789") for d in done}):
            f.write(nme + "\n")
    print("готово:", len(done))


if __name__ == "__main__":
    if "--events" in sys.argv:
        for sid in sys.argv[sys.argv.index("--events") + 1:]:
            x, sr = load(sid)
            thr = -34.0
            print(sid, "длина %.2f" % (len(x) / sr), ["%.2f-%.2f" % e for e in events(x, sr, thr, 0.12)])
    else:
        main()
