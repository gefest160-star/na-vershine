# -*- coding: utf-8 -*-
"""Проверка озвучки: все ли файлы читаются, нет ли подозрительно коротких/длинных реплик."""
import os
import sys
import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOICE = os.path.join(ROOT, "audio", "voice")

LO = float(sys.argv[sys.argv.index('--lo') + 1]) if '--lo' in sys.argv else 0.6
HI = float(sys.argv[sys.argv.index('--hi') + 1]) if '--hi' in sys.argv else 1.5
rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(ROOT, "tools", "voice_lines.tsv"), encoding="utf-8")]
by = {}
bad = []
total = 0.0
for vid, spk, text in rows:
    p = os.path.join(VOICE, vid + ".ogg")
    if not os.path.exists(p):
        bad.append((vid, spk, "НЕТ ФАЙЛА", text))
        continue
    try:
        x, sr = sf.read(p, dtype="float32")
    except Exception as e:  # noqa
        bad.append((vid, spk, "НЕ ЧИТАЕТСЯ", text))
        continue
    dur = len(x) / sr
    total += dur
    letters = sum(ch.isalpha() for ch in text)
    cps = letters / max(dur, 0.01)
    rms = 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-9)
    by.setdefault(spk, []).append((cps, dur, rms, vid, text))
    w = max(1, int(sr * 0.02))
    e = np.sqrt(np.convolve(x ** 2, np.ones(w) / w, mode='same')) < 0.004
    run = 0
    longest = 0
    for q in e:
        run = run + 1 if q else 0
        longest = max(longest, run)
    if longest / sr > 1.3:
        bad.append((vid, spk, 'ПАУЗА %.1f c' % (longest / sr), text))
    if dur < 0.25 or rms < -40:
        bad.append((vid, spk, "ПУСТО/ТИХО %.2fc %.0fdB" % (dur, rms), text))

print("всего: %d реплик, %.1f мин звука" % (len(rows), total / 60.0))
for spk, items in sorted(by.items(), key=lambda kv: -len(kv[1])):
    c = np.array([i[0] for i in items])
    print("%-9s n=%3d  букв/с: средн %.1f (мин %.1f, макс %.1f)  громкость %.1f dB" % (spk, len(items), c.mean(), c.min(), c.max(), np.mean([i[2] for i in items])))
    med = np.median(c)
    for cps, dur, rms, vid, text in items:
        if len(text) > 12 and (cps < med * LO or cps > med * HI):
            bad.append((vid, spk, "ТЕМП %.1f при медиане %.1f (%.1fc)" % (cps, med, dur), text))
print("подозрительных: %d" % len(bad))
for b in bad:
    print("  %s [%s] %s :: %s" % (b[0], b[1], b[2], b[3][:70]))
if "--ids" in sys.argv:
    print(",".join(b[0] for b in bad))
