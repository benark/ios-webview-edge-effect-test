#!/usr/bin/env python3
"""Compares two screenshots of the same page band by band and prints the largest per-channel difference.

Used for the "identical pixel for pixel from N pt down" statements: a band with a difference of 0 is identical.
Heights are in points from the top of the screen. The left ruler and the right scroll indicator are included unless
--content is given, which compares only the columns between them.

Usage: python3 scripts/compare.py a.png b.png [--content]     (needs Pillow and NumPy)
"""
import sys

import numpy as np
from PIL import Image

SCREEN_WIDTH_PT = 440  # iPhone 18 Pro Max; the scale is derived from the screenshot's width
BANDS_PT = [(0, 62), (62, 70), (70, 80), (80, 90), (90, 97), (97, 128), (128, 280)]

paths = [a for a in sys.argv[1:] if not a.startswith("--")]
content_only = "--content" in sys.argv
if len(paths) != 2:
    sys.exit(__doc__)

a, b = (np.asarray(Image.open(p).convert("RGB")).astype(int) for p in paths)
if a.shape != b.shape:
    sys.exit(f"different sizes: {a.shape} and {b.shape}")
scale = a.shape[1] / SCREEN_WIDTH_PT
difference = np.abs(a - b).max(axis=2)
if content_only:
    difference = difference[:, int(48 * scale):int(430 * scale)]

for top, bottom in BANDS_PT:
    band = difference[int(top * scale):int(bottom * scale)]
    print(f"{top:3d}-{bottom:3d} pt: largest difference {band.max():3d}/255, {100 * (band > 0).mean():6.2f}% of pixels differ")
