# -*- coding: utf-8 -*-
"""Сводка по исходным записям в tools/sfx_src: длительность, уровень, «график» громкости."""
import os
import sys
import numpy as np
import soundfile as sf

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sfx_src")
BARS = " .:-=+*#%@"


def info(path, cols=100):
    x, sr = sf.read(path, dtype="float32", always_2d=True)
    m = x.mean(axis=1)
    dur = len(m) / sr
    win = max(1, len(m) // cols)
    n = len(m) // win
    env = np.sqrt((m[: n * win].reshape(n, win) ** 2).mean(axis=1)) + 1e-9
    db = 20 * np.log10(env)
    lo, hi = -60.0, 0.0
    line = "".join(BARS[int(np.clip((d - lo) / (hi - lo), 0, 0.999) * len(BARS))] for d in db)
    print("%-10s %6.2fs sr=%d ch=%d peak=%.2f rms=%5.1fdB  step=%.3fs" % (os.path.basename(path), dur, sr, x.shape[1], np.abs(m).max(), 20 * np.log10(np.sqrt((m ** 2).mean()) + 1e-9), win / sr))
    print("   |" + line + "|")


if __name__ == "__main__":
    names = sys.argv[1:] or sorted(os.listdir(SRC))
    for nme in names:
        p = os.path.join(SRC, nme)
        if not os.path.exists(p):
            for ext in (".flac", ".wav", ".ogg"):
                if os.path.exists(p + ext):
                    p = p + ext
                    break
        try:
            info(p)
        except Exception as e:
            print('%-10s ERROR %s' % (os.path.basename(p), str(e)[:60]))
