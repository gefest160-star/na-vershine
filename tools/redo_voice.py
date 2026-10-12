# -*- coding: utf-8 -*-
"""Перегенерировать отдельные реплики с нуля (мимо кеша): python tools/redo_voice.py <id> [<id> ...]"""
import asyncio
import hashlib
import os
import sys

import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_voice as G  # noqa


async def main():
    ids = set(sys.argv[1:])
    for spk, text in G.collect():
        vid = G.line_id(spk, text)
        if vid not in ids:
            continue
        t = G.tts_text(text)
        combos = G.CHORUS.get(spk) or [G.CAST[spk][:3]]
        for voice, rate, pitch in combos:
            key = hashlib.md5("|".join((voice, rate, pitch, t)).encode("utf-8")).hexdigest()[:16]
            p = os.path.join(G.CACHE, key + ".mp3")
            if os.path.exists(p):
                x, sr = sf.read(p)
                print("  старый кеш %s: %.1f c" % (key, len(x) / sr))
                os.replace(p, p + ".old")
        await G.make_line(spk, text)
        x, sr = sf.read(os.path.join(G.OUT, vid + ".ogg"))
        print("%s [%s] -> %.1f c :: %s" % (vid, spk, len(x) / sr, text[:60]))


asyncio.run(main())
