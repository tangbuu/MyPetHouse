#!/usr/bin/env python3
"""
Clean Gemini sprite sheets:
  1. Remove white background (flood fill from edges)
  2. Remove text labels (tiny connected components)
  3. Normalize to uniform grid → single PNG ready for Godot hframes/vframes
"""

from PIL import Image
import numpy as np
from collections import deque
import os, math

WHITE_THRESHOLD = 245
MIN_SPRITE_AREA = 600   # px — components smaller than this are treated as text/noise
PADDING = 6             # transparent padding around each sprite in the cell
COLS = 3                # columns in the output grid


# ── Step 1: remove white background ──────────────────────────────────────────

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


# ── Step 2: find sprite bounding boxes (filter out text) ─────────────────────

def find_sprites(img: Image.Image):
    alpha = np.array(img)[:, :, 3]
    h, w = alpha.shape
    visited = np.zeros((h, w), dtype=bool)
    boxes = []

    for sy in range(h):
        for sx in range(w):
            if alpha[sy, sx] > 0 and not visited[sy, sx]:
                q = deque([(sy, sx)])
                visited[sy, sx] = True
                ys, xs = [sy], [sx]
                while q:
                    cy, cx = q.popleft()
                    for dy, dx in ((-1,0),(1,0),(0,-1),(0,1)):
                        ny, nx = cy+dy, cx+dx
                        if 0 <= ny < h and 0 <= nx < w and alpha[ny,nx] > 0 and not visited[ny,nx]:
                            visited[ny,nx] = True
                            q.append((ny, nx))
                            ys.append(ny); xs.append(nx)

                if len(ys) >= MIN_SPRITE_AREA:
                    boxes.append((min(xs), min(ys), max(xs)+1, max(ys)+1))

    return sorted(boxes, key=lambda b: (b[1] // 80, b[0]))


# ── Step 3: build uniform-grid sprite sheet ───────────────────────────────────

def build_sheet(img_no_bg: Image.Image, cols: int) -> tuple:
    boxes = find_sprites(img_no_bg)
    n = len(boxes)

    # Cell size = max sprite size + padding on each side
    cell_w = max(x2-x1 for x1,y1,x2,y2 in boxes) + PADDING * 2
    cell_h = max(y2-y1 for x1,y1,x2,y2 in boxes) + PADDING * 2

    rows = math.ceil(n / cols)
    sheet = Image.new("RGBA", (cell_w * cols, cell_h * rows), (0, 0, 0, 0))

    for i, (x1, y1, x2, y2) in enumerate(boxes):
        sprite = img_no_bg.crop((x1, y1, x2, y2))
        col = i % cols
        row = i // cols
        # Bottom-center: feet always at same Y, body centered horizontally
        ox = col * cell_w + (cell_w - sprite.width)  // 2
        oy = row * cell_h + (cell_h - sprite.height)
        sheet.paste(sprite, (ox, oy), sprite)

    return sheet, n, cols, rows, cell_w, cell_h


# ── Main ──────────────────────────────────────────────────────────────────────

GENEMI = "/Users/bin/Projects/take-care-pets/assets/genemi"
OUT    = "/Users/bin/Projects/take-care-pets/assets/cat/sheets"
os.makedirs(OUT, exist_ok=True)

tasks = [
    ("Gemini_Generated_Image_cidfbgcidfbgcidf.png", "walk_down", 0),  # 0 = 1 row (auto cols)
    ("Gemini_Generated_Image_ity8rcity8rcity8.png",  "walk_up",   3),
    ("Gemini_Generated_Image_9yrb8k9yrb8k9yrb.png",  "walk_side", 4),
]

for filename, name, cols in tasks:
    path = os.path.join(GENEMI, filename)
    print(f"\n{name}  ←  {filename}")

    img = Image.open(path)
    img_clean = remove_bg(img)
    # cols=0 means 1 row: all sprites in a single horizontal line
    sprites_count = len(find_sprites(img_clean))
    actual_cols = sprites_count if cols == 0 else cols
    sheet, n, c, r, cw, ch = build_sheet(img_clean, actual_cols)

    out_path = os.path.join(OUT, f"{name}_sheet.png")
    sheet.save(out_path)
    print(f"  sprites: {n}  grid: {c}×{r}  cell: {cw}×{ch}px")
    print(f"  → {out_path}")
    print(f"  Godot: hframes={c}, vframes={r}  (use frames 0–{n-1})")
