#!/usr/bin/env python3
"""
Process eat animation from a single 3x3 Gemini sprite sheet.
Layout input:  row0=prepare(3), row1=loop(3), row2=end(3)
Layout output: same — but skip frame index 7 (img 8, row2 col1)
"""

from PIL import Image
import numpy as np
from collections import deque
import os

WHITE_THRESHOLD = 245
PADDING = 6

GENEMI = "/Users/bin/Projects/take-care-pets/assets/genemi"
OUT    = "/Users/bin/Projects/take-care-pets/assets/cat/sheets"

SOURCE = "Gemini_Generated_Image_c9wnicc9wnicc9wn.png"
SKIP   = {7}   # 0-indexed frame numbers to skip (img 8 = index 7)


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


def extract_grid(img: Image.Image, n_cols: int, n_rows: int):
    """Extract sprites from a fixed grid, stripping text labels at bottom of each cell."""
    alpha = np.array(img)[:, :, 3]
    h, w = alpha.shape
    cell_w = w // n_cols
    cell_h = h // n_rows

    sprites = []
    for row in range(n_rows):
        for col in range(n_cols):
            x1 = col * cell_w
            x2 = (col + 1) * cell_w if col < n_cols - 1 else w
            y1 = row * cell_h
            y2 = (row + 1) * cell_h if row < n_rows - 1 else h

            cell = alpha[y1:y2, x1:x2]
            row_sum = cell.sum(axis=1)

            # Find row groups
            in_row = False
            groups = []
            rs = 0
            for y in range(len(row_sum)):
                if row_sum[y] > 0 and not in_row:
                    rs = y; in_row = True
                elif row_sum[y] == 0 and in_row:
                    groups.append((rs, y)); in_row = False
            if in_row:
                groups.append((rs, len(row_sum)))

            if not groups:
                sprites.append(None)
                continue

            # Strip text: last group if small and starts in bottom 60% of cell
            TEXT_THRESHOLD = int(len(row_sum) * 0.6)
            TEXT_MAX_HEIGHT = 50
            kept = [g for g in groups
                    if not (g[0] >= TEXT_THRESHOLD and (g[1] - g[0]) <= TEXT_MAX_HEIGHT)]
            if not kept:
                kept = [max(groups, key=lambda g: g[1] - g[0])]

            sy1 = kept[0][0]
            sy2 = kept[-1][1]

            # Tight horizontal bounds
            sprite_region = cell[sy1:sy2, :]
            col_sum = sprite_region.sum(axis=0)
            col_idxs = np.where(col_sum > 0)[0]
            if len(col_idxs) == 0:
                sprites.append(None)
                continue
            sx1 = int(col_idxs[0])
            sx2 = int(col_idxs[-1]) + 1

            crop = img.crop((x1 + sx1, y1 + sy1, x1 + sx2, y1 + sy2))
            sprites.append(crop)

    return sprites


# ── Extract all 9 sprites ──────────────────────────────────────────────────────

img_clean = remove_bg(Image.open(os.path.join(GENEMI, SOURCE)))
all_sprites = extract_grid(img_clean, n_cols=3, n_rows=3)

# ── Assign to animations, skipping marked indices ─────────────────────────────

rows_sprites = []
for row_idx in range(3):
    row = []
    for col_idx in range(3):
        frame_idx = row_idx * 3 + col_idx
        if frame_idx in SKIP:
            continue
        s = all_sprites[frame_idx]
        if s:
            row.append(s)
    rows_sprites.append(row)
    name = ["eat_prepare", "eat_loop", "eat_end"][row_idx]
    print(f"  {name}: {len(row)} sprites")

# ── Build output sheet ────────────────────────────────────────────────────────

all_flat = [s for row in rows_sprites for s in row]
cell_w = max(s.width  for s in all_flat) + PADDING * 2
cell_h = max(s.height for s in all_flat) + PADDING * 2

cols = max(len(row) for row in rows_sprites)
n_rows = len(rows_sprites)

sheet = Image.new("RGBA", (cell_w * cols, cell_h * n_rows), (0, 0, 0, 0))

for r, row in enumerate(rows_sprites):
    for c, sprite in enumerate(row):
        ox = c * cell_w + (cell_w - sprite.width)  // 2
        oy = r * cell_h + (cell_h - sprite.height)      # bottom-align
        sheet.paste(sprite, (ox, oy), sprite)

out_path = os.path.join(OUT, "eat_sheet.png")
sheet.save(out_path)
print(f"\nSaved: {out_path}")
print(f"Size: {sheet.width}x{sheet.height}px  |  grid: {cols}x{n_rows}  |  cell: {cell_w}x{cell_h}px")
print(f"Godot: hframes={cols}, vframes={n_rows}")
lens = [len(r) for r in rows_sprites]
print(f"  eat_prepare → frames 0–{lens[0]-1}")
print(f"  eat_loop    → frames {cols}–{cols+lens[1]-1}")
print(f"  eat_end     → frames {cols*2}–{cols*2+lens[2]-1}")
