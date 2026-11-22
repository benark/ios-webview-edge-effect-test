#!/usr/bin/env python3
"""Reports where the top edge effect ends in each screenshot, using the red ruler on the left edge of the page.

The ruler has a 1 pt tick every 2 pt. Where the effect covers it the ticks lose contrast. For each screenshot this
prints the first height (pt from the top of the screen) where the ticks show at all (10% contrast) and where they are
fully sharp (95%), relative to the ruler's contrast lower down the same screenshot.

Usage: python3 scripts/measure.py screenshot.png [more.png ...]     (needs Pillow and NumPy)
"""
import sys

import numpy as np
from PIL import Image

SCREEN_WIDTH_PT = 440  # iPhone 18 Pro Max; the scale is derived from the screenshot's width
BAND_PT = 3


def profile(path):
    image = np.asarray(Image.open(path).convert("RGB")).astype(int)
    scale = image.shape[1] / SCREEN_WIDTH_PT
    green = image[:, int(1 * scale):int(7 * scale), 1].mean(axis=1)  # the ticks are red, so green carries them

    def contrast(pt):
        rows = green[int(pt * scale):int((pt + BAND_PT) * scale)]
        return rows.max() - rows.min()

    reference = np.median([contrast(pt) for pt in range(150, 210, BAND_PT)])
    return {pt: contrast(pt) / reference for pt in range(0, 132, BAND_PT)}


def first_from(values, threshold):
    heights = sorted(values)
    return next((pt for pt in heights if all(values[q] >= threshold for q in heights if q >= pt)), None)


for path in sys.argv[1:]:
    values = profile(path)
    row = " ".join(f"{round(values[pt] * 100):3d}" for pt in range(39, 102, BAND_PT))
    print(f"{path.split('/')[-1]:26s} shows from {first_from(values, 0.10):>3} pt, sharp from {first_from(values, 0.95):>3} pt"
          f" | % contrast at 39..99 pt: {row}")
