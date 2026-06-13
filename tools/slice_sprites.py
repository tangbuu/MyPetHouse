#!/usr/bin/env python3
"""
tools/slice_sprites.py — PocketPal sprite slicer
Run from project root:  python3 tools/slice_sprites.py

Outputs:
  assets/cat/frames/     — individual cat animation frames
  assets/item/frames/    — individual furniture items (auto-named, rename later)
  assets/UI/frames/      — UI icons / buttons
"""

from PIL import Image
from pathlib import Path
import sys

ROOT   = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"

# ── util ─────────────────────────────────────────────────────────────────────

def open_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")

def tight_crop(img: Image.Image, pad: int = 2) -> Image.Image | None:
    """Crop to bounding box of non-transparent pixels, plus padding."""
    bb = img.getbbox()
    if bb is None:
        return None
    x0 = max(0, bb[0] - pad)
    y0 = max(0, bb[1] - pad)
    x1 = min(img.width,  bb[2] + pad)
    y1 = min(img.height, bb[3] + pad)
    return img.crop((x0, y0, x1, y1))

def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"  ✓  {path.relative_to(ROOT)}  ({img.width}×{img.height})")

# ── 1. Cat sprite sheet ───────────────────────────────────────────────────────
# RetroCatsFree.png  256×435
# Layout: 64-px columns, 64-px rows for the animation section
#
# Row 0 (y=  0–63):  idle      – 4 frames
# Row 1 (y= 64–127): worried   – 4 frames (some may be empty)
# Row 2 (y=128–191): sleeping  – 4 frames
# Row 3 (y=192–255): food bowls – 4 variants
# y=256+: cat tree, milk boxes, toys — auto-detected below

CAT_ANIM_ROWS = [
    (  0, 64, ["idle_0",    "idle_1",    "idle_2",    "idle_3"   ]),
    ( 64, 64, ["worried_0", "worried_1", "worried_2", "worried_3"]),
    (128, 64, ["sleep_0",   "sleep_1",   "sleep_2",   "sleep_3"  ]),
    (192, 64, ["bowl_blue", "bowl_brown","bowl_dark",  "bowl_gray"]),
]

# Items below y=256 are in irregular positions — auto-detect them
CAT_EXTRA_Y   = 256   # start of irregular section
CAT_EXTRA_CW  = 128   # scan with wider cells (cat tree is large)
CAT_EXTRA_CH  = 64

def slice_cat() -> None:
    src = ASSETS / "cat" / "RetroCatsFree.png"
    out = ASSETS / "cat" / "frames"
    img = open_rgba(src)
    print(f"\n=== Cat sheet  {img.width}×{img.height} ===")

    # Animation rows (uniform 64×64 grid)
    for (row_y, row_h, names) in CAT_ANIM_ROWS:
        for col_i, name in enumerate(names):
            x  = col_i * 64
            cell = img.crop((x, row_y, x + 64, row_y + row_h))
            frame = tight_crop(cell, pad=1)
            if frame is None:
                continue
            save(frame, out / f"{name}.png")

    # Extra items (cat tree, boxes, toys) — scan 128×64 cells
    for row_y in range(CAT_EXTRA_Y, img.height, CAT_EXTRA_CH):
        for col_i in range(img.width // CAT_EXTRA_CW):
            x    = col_i * CAT_EXTRA_CW
            cell = img.crop((x, row_y, x + CAT_EXTRA_CW, row_y + CAT_EXTRA_CH))
            frame = tight_crop(cell, pad=2)
            if frame is None:
                continue
            name = f"extra_{col_i}_{row_y}"
            save(frame, out / f"{name}.png")

# ── 2. Furniture sheet ────────────────────────────────────────────────────────
# Furnitures.png  512×512
# Items are NOT on a uniform grid — scan 128×128 cells, crop to content.
# Files are auto-named "item_COL_ROW.png".  Rename after inspecting output.
#
# Known mapping (col, row) → name  (fill in more after first run):
FURN_NAMES: dict[tuple[int,int], str] = {
    (0, 0): "window_a",
    (1, 0): "window_b",
    (2, 0): "post_beige",
    (3, 0): "post_brown",
    (0, 1): "window_c",
    (1, 1): "window_d",
    (2, 1): "bed_blue",
    (3, 1): "bed_gray",
    (0, 2): "deco_frame_a",
    (1, 2): "deco_frame_b",
    (2, 2): "bed_pink",
    (3, 2): "bed_green",
    (0, 3): "shelf",
    (1, 3): "plant_large",
    (2, 3): "fountain",
    (3, 3): "bowls_set",
}

# Fine-grained explicit crops for items we actually need in-game.
# Format: (x, y, w, h, "name")  — pixel coords in Furnitures.png

# Coordinates confirmed via 64×64 debug-cell scan.
#
# Furniture sheet layout (512×512, items span ~128×128 each):
#
#   x →    0   64  128  192  256  320  384  448
#   y ↓  ┌────┬────┬────┬────┬────┬────┬────┬────┐
#   0    │ W1      │ W2      │ P1      │ P2      │  ← windows + posts
#   64   │         │         │         │         │
#   128  │         │         │ BED1    │ BED2    │  ← cat beds row A
#   192  │         │         │         │  PAINT  │
#   256  │ SHELF   │ PLANT   │ BED3    │ BED4    │  ← cat beds row B
#   320  │         │         │ FOUNT   │ BOWLS   │
#   384  │         │         │         │ BOWL2   │
#   448  │         │         │ BALLS   │         │
#        └─────────┴─────────┴─────────┴─────────┘

FURN_EXPLICIT: list[tuple[int,int,int,int,str]] = [
    # Windows (cols 0-1 and 2-3, rows 0-2  →  each 128 wide × 192 tall)
    (  0,   0, 128, 192, "window_a"),
    (128,   0, 128, 192, "window_b"),

    # Scratch posts (cols 4-5 and 6-7, rows 0-1  →  128 wide × 128 tall)
    (256,   0, 128, 128, "post_beige"),   # confirmed ✓
    (384,   0, 128, 128, "post_teal"),

    # Cat beds  — each fits in ONE 64-px row, use h=64 to avoid bleed
    (192, 128, 128,  64, "bed_blue"),    # confirmed cells (3,2)+(4,2) ✓
    (320, 128, 128,  64, "bed_gray"),    # confirmed cells (5,2)+(6,2) ✓
    (192, 256, 128,  64, "bed_pink"),
    (320, 256, 128,  64, "bed_green"),

    # Painting / wall-art
    (384, 128,  64,  64, "painting"),

    # Shelf (cols 0-1, rows 4-5: single 64-px row for clean crop)
    (  0, 256,  64,  64, "shelf_top"),
    ( 64, 256,  64,  64, "shelf_mid"),

    # Large plant (col 2, row 4)
    (128, 256,  64, 128, "plant_large"),

    # Fountain (col 3, row 5)
    (192, 320,  64, 128, "fountain"),

    # Food + water bowls (col 6-7, row 6) — confirmed ✓
    (384, 384, 128, 128, "bowls_set"),

    # Small toy balls (rows 6-7, left area)
    (  0, 448, 192,  64, "balls"),
]

FURN_CW = FURN_CH = 128   # kept for legacy reference

def slice_furniture() -> None:
    src = ASSETS / "item" / "Furnitures.png"
    out = ASSETS / "item" / "frames"
    img = open_rgba(src)
    print(f"\n=== Furniture sheet  {img.width}×{img.height} (explicit crop) ===")

    for (x, y, w, h, name) in FURN_EXPLICIT:
        cell  = img.crop((x, y, x+w, y+h))
        frame = tight_crop(cell, pad=3)
        if frame is None:
            print(f"  SKIP (empty): {name}")
            continue
        save(frame, out / f"{name}.png")

# ── 3. UI sheet ───────────────────────────────────────────────────────────────
# free.png  256×128
# Left section (~64px wide): cat mood icons + stat elements
# Right section: pixel-art buttons on an approx 18×18 grid

UI_NAMED: list[tuple[int,int,int,int,str]] = [
    # x,  y,  w,  h,  name
    (  0,  0, 32, 32, "icon_face_normal"),
    (  0, 32, 32, 32, "icon_face_sad"),
    (  0, 64, 32, 32, "icon_face_angry"),
    (  0, 96, 32, 32, "icon_cat_sleep"),
    ( 32,  0, 32, 32, "ui_bar_element_a"),
    ( 32, 32, 32, 32, "ui_bar_element_b"),
    ( 32, 64, 32, 32, "ui_bar_element_c"),
    ( 32, 96, 32, 32, "ui_bar_element_d"),
]

UI_BTN_X  = 64   # buttons start here
UI_BTN_W  = 18
UI_BTN_H  = 18

def slice_ui() -> None:
    src = ASSETS / "UI" / "free.png"
    out = ASSETS / "UI" / "frames"
    img = open_rgba(src)
    print(f"\n=== UI sheet  {img.width}×{img.height} ===")

    for (x, y, w, h, name) in UI_NAMED:
        cell  = img.crop((x, y, x+w, y+h))
        frame = tight_crop(cell, pad=1)
        if frame is None:
            continue
        save(frame, out / f"{name}.png")

    # Auto-grid for button section
    btn_region = img.crop((UI_BTN_X, 0, img.width, img.height))
    cols = btn_region.width  // UI_BTN_W
    rows = btn_region.height // UI_BTN_H
    for r in range(rows):
        for c in range(cols):
            cell  = btn_region.crop((c*UI_BTN_W, r*UI_BTN_H,
                                     c*UI_BTN_W + UI_BTN_W, r*UI_BTN_H + UI_BTN_H))
            frame = tight_crop(cell, pad=0)
            if frame is None:
                continue
            save(frame, out / f"btn_{r}_{c}.png")

# ── main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import os
    # Always resolve to project root regardless of CWD
    os.chdir(Path(__file__).resolve().parent.parent)
    slice_cat()
    slice_furniture()
    slice_ui()
    print(f"\n✅  Done — check assets/*/frames/ folders")
