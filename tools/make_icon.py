# -*- coding: utf-8 -*-
"""Рисует значок игры (icon.png): золотая лестница в темноте и фигура на верхней ступени."""
import os
import struct
import zlib

import numpy as np

N = 256
img = np.zeros((N, N, 4), dtype=np.float64)
yy, xx = np.mgrid[0:N, 0:N]

# фон: тёмный с лёгким свечением сверху
d = np.hypot(xx - N * 0.62, yy - N * 0.22) / N
bg = np.clip(1.0 - d * 1.5, 0, 1) ** 2
img[..., 0] = 0.035 + 0.10 * bg
img[..., 1] = 0.04 + 0.09 * bg
img[..., 2] = 0.07 + 0.10 * bg
img[..., 3] = 1.0

# скруглённые углы
r = 44
corner = np.ones((N, N))
for cx, cy in ((r, r), (N - r, r), (r, N - r), (N - r, N - r)):
    m = ((xx < r) if cx == r else (xx >= N - r)) & ((yy < r) if cy == r else (yy >= N - r))
    corner[m & (np.hypot(xx - cx, yy - cy) > r)] = 0.0
img[..., 3] = corner

gold = np.array([0.91, 0.75, 0.44])
dark = np.array([0.45, 0.33, 0.14])


def rect(x0, y0, x1, y1, col, a=1.0):
    m = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
    for c in range(3):
        img[..., c][m] = img[..., c][m] * (1 - a) + col[c] * a


# лестница
steps = 5
sw, sh = 34, 26
x0, y0 = 34, 214
for i in range(steps):
    x = x0 + i * sw
    y = y0 - (i + 1) * sh
    rect(x, y, x + sw + 2, y0 + 8, dark * (0.55 + 0.09 * i))
    rect(x, y, x + sw + 2, y + 6, gold)

# фигура на вершине
fx = x0 + (steps - 1) * sw + 14
fy = y0 - steps * sh
rect(fx - 6, fy - 34, fx + 6, fy, np.array([0.02, 0.02, 0.03]))
m = np.hypot(xx - fx, yy - (fy - 42)) < 7.5
for c in range(3):
    img[..., c][m] = 0.02
rect(fx - 12, fy - 48, fx + 12, fy - 46, np.array([0.02, 0.02, 0.03]))   # шляпа
rect(fx - 6, fy - 56, fx + 6, fy - 47, np.array([0.02, 0.02, 0.03]))

out = (np.clip(img, 0, 1) * 255).astype(np.uint8)
raw = b"".join(b"\x00" + out[y].tobytes() for y in range(N))


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "icon.png")
open(path, "wb").write(png)
print("icon:", path)
