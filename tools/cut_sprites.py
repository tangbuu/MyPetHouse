#!/usr/bin/env python3
"""
Cut sprite sheet into individual frames and remove white background.
Uses edge flood-fill so interior white pixels (eyes) are preserved.
"""

from PIL import Image
import numpy as np
from collections import deque
import os

WHITE_THRESHOLD = 245
MIN_SPRITE_AREA = 600
PADDING = 4


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
        seed(0, x)
        seed(h - 1, x)
    for y in range(h):
        seed(y, 0)
        seed(y, w - 1)

    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and is_white[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))

    arr[bg, 3] = 0
    return Image.fromarray(arr, "RGBA")


def find_sprites(img: Image.Image):
    """Return list of (x1,y1,x2,y2) bounding boxes, sorted left→right top→bottom."""
    alpha = np.array(img)[:, :, 3]
    h, w = alpha.shape
    visited = np.zeros((h, w), dtype=bool)
    boxes = []

    for sy in range(h):
        for sx in range(w):
            if alpha[sy, sx] > 0 and not visited[sy, sx]:
                # BFS
                q = deque([(sy, sx)])
                visited[sy, sx] = True
                ys, xs = [sy], [sx]
                while q:
                    cy, cx = q.popleft()
                    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and alpha[ny, nx] > 0 and not visited[ny, nx]:
                            visited[ny, nx] = True
                            q.append((ny, nx))
                            ys.append(ny)
                            xs.append(nx)

                if len(ys) >= MIN_SPRITE_AREA:
                    x1, y1 = min(xs), min(ys)
                    x2, y2 = max(xs) + 1, max(ys) + 1
                    boxes.append((x1, y1, x2, y2))

    return sorted(boxes, key=lambda b: (b[1] // 80, b[0]))


def normalize(sprites: list) -> list:
    """Pad all sprites to the same canvas size, centered."""
    max_w = max(s.width  for s in sprites)
    max_h = max(s.height for s in sprites)
    result = []
    for s in sprites:
        canvas = Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0))
        x = (max_w - s.width)  // 2
        y = (max_h - s.height) // 2
        canvas.paste(s, (x, y), s)
        result.append(canvas)
    return result


def process(input_path: str, output_dir: str, prefix: str):
    os.makedirs(output_dir, exist_ok=True)
    print(f"\nProcessing: {os.path.basename(input_path)}")

    img = Image.open(input_path)
    img_no_bg = remove_bg(img)
    boxes = find_sprites(img_no_bg)

    print(f"  Found {len(boxes)} sprites")
    sprites = []
    for x1, y1, x2, y2 in boxes:
        x1p = max(0, x1 - PADDING)
        y1p = max(0, y1 - PADDING)
        x2p = min(img_no_bg.width, x2 + PADDING)
        y2p = min(img_no_bg.height, y2 + PADDING)
        sprites.append(img_no_bg.crop((x1p, y1p, x2p, y2p)))

    sprites = normalize(sprites)
    print(f"  Canvas normalized to {sprites[0].width}x{sprites[0].height}px")

    for i, sprite in enumerate(sprites, 1):
        out = os.path.join(output_dir, f"{prefix}_{i}.png")
        sprite.save(out)
        print(f"  [{i}] {out}")


BASE = "/Users/bin/Projects/take-care-pets/assets"

process(
    f"{BASE}/Gemini_Generated_Image_cidfbgcidfbgcidf.png",
    f"{BASE}/../assets/cat/cat/walk_down",
    "walk_down",
)

process(
    f"{BASE}/Gemini_Generated_Image_ity8rcity8rcity8.png",
    f"{BASE}/../assets/cat/cat/walk_up",
    "walk_up",
)
