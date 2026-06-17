# Gemini Sprite Sheet Prompt Template

## Format chung

```
Pixel art sprite sheet, white background. {COLS}×{ROWS} grid layout ({COLS} columns, {ROWS} rows),
each cell the same size with clear spacing between cells.
No text, no filename labels, no captions anywhere on the image.

Row 1 — {anim_name} ({description}):
- Frame 1: ...
- Frame 2: ...
- Frame 3: ...

Row 2 — {anim_name}:
...

Style: cute chunky pixel art cat, approx 32×32 px per sprite, grey/white fur.
White background. No text, no filename labels, no captions anywhere on the image.
Consistent cat size across all frames.
```

---

## Eat animation (3×3, đã test OK)

Pixel art sprite sheet, white background. 3×3 grid layout (3 columns, 3 rows), each cell the same size with clear spacing between cells. No text, no labels anywhere on the image.

**Row 1 — eat_prepare (cat approaching food bowl):**
- Frame 1: cat standing upright, facing right, normal posture
- Frame 2: cat leaning forward slightly, head lowering
- Frame 3: cat crouching low, nose near ground, about to eat

**Row 2 — eat_loop (cat eating, loopable):**
- Frame 1: cat fully crouched, head down eating
- Frame 2: cat head slightly raised while chewing
- Frame 3: same as frame 1 (head down eating) — for smooth loop

**Row 3 — eat_end (cat finishing and standing back up):**
- Frame 1: cat crouching, lifting head up
- Frame 2: cat rising to half-standing, licking lips
- Frame 3: cat fully upright, satisfied pose, facing right

Style: cute chunky pixel art cat, approx 32×32 px per sprite, grey/white fur. White background. **No text, no filename labels, no captions** anywhere on the image. Consistent cat size across all 9 frames.

---

## Notes
- Luôn thêm "No text, no filename labels, no captions" vào đầu VÀ cuối prompt
- Grid rõ ràng giúp script cắt đúng hơn (fixed-grid approach chia đều theo số cột)
- Mỗi animation nên là bội số của 3 frame để dễ layout (3×N)
- Nếu Gemini vẫn gen text label → gen lại, thêm "absolutely no text of any kind"
