#!/usr/bin/env python3
"""
Combine individual idle animation PNGs into single-row sprite sheets.
"""

from PIL import Image
import numpy as np
from collections import deque
import os, glob

WHITE_THRESHOLD = 245
PADDING = 4

BASE  = "/Users/bin/Projects/take-care-pets/assets/cat/idle"
OUT   = "/Users/bin/Projects/take-care-pets/assets/cat/sheets"


def remove_bg(img: Image.Image) -> Image.Image:
    arr = np.array(img.convert("RGBA"))
    h, w = arr.shape[:2]
    is_white = np.all(arr[:, :, :3] >= WHITE_THRESHOLD, axis=2)
    bg = np.zeros((h, w), dtype=bool)
    q: deque = deque()

    def seed(y, x):
        if is_white[y, x] and not bg[y, x]:
            bg[y, x] = True
            q.append((y, x))

    for x in range(w):
        seed(0, x); seed(h - 1, x)
    for y in range(h):
        seed(y, 0); seed(y, w - 1)

    while q:
        y, x = q.popleft()
        for dy, dx in ((-1,0),(1,0),(0,-1),(0,1)):
            ny, nx = y+dy, x+dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny,nx] and is_white[ny,nx]:
                bg[ny,nx] = True
                q.append((ny, nx))

    arr[bg, 3] = 0
    return Image.fromarray(arr, "RGBA")


def tight_crop(img: Image.Image) -> Image.Image:
    alpha = np.array(img)[:, :, 3]
    rows = np.any(alpha > 0, axis=1)
    cols = np.any(alpha > 0, axis=0)
    if not rows.any():
        return img
    y1, y2 = int(np.where(rows)[0][0]), int(np.where(rows)[0][-1]) + 1
    x1, x2 = int(np.where(cols)[0][0]), int(np.where(cols)[0][-1]) + 1
    return img.crop((x1, y1, x2, y2))


def make_sheet(folder: str, out_name: str):
    pngs = sorted(glob.glob(os.path.join(folder, "*.png")))
    sprites = [tight_crop(remove_bg(Image.open(p))) for p in pngs]

    cell_w = max(s.width  for s in sprites) + PADDING * 2
    cell_h = max(s.height for s in sprites) + PADDING * 2

    sheet = Image.new("RGBA", (cell_w * len(sprites), cell_h), (0, 0, 0, 0))
    for i, sprite in enumerate(sprites):
        ox = i * cell_w + (cell_w - sprite.width)  // 2
        oy = cell_h - sprite.height                 # bottom-align
        sheet.paste(sprite, (ox, oy), sprite)

    # Resize 50%
    sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.NEAREST)

    out_path = os.path.join(OUT, out_name)
    sheet.save(out_path)
    print(f"  {out_name}: {len(sprites)} frames  {sheet.width}x{sheet.height}px")
    return len(sprites)


tasks = [
    ("idel_2", "idle2_sheet.png"),
    ("idel_3", "idle3_sheet.png"),
    ("idel_4", "idle4_sheet.png"),
    ("idel_6", "idle6_sheet.png"),
]

for folder_name, out_name in tasks:
    make_sheet(os.path.join(BASE, folder_name), out_name)
