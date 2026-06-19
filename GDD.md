# Game Design Document — PocketPal

---

## Game Profile

| Field | Detail |
|---|---|
| **Title** | PocketPal *(working title)* |
| **Genre** | Virtual Pet / Casual |
| **Platform** | Android (primary), iOS (secondary) |
| **Engine** | Godot 4.x |
| **Target Audience** | 13–28 tuổi, casual gamers |
| **Monetization** | Free-to-play (cosmetics only, no pay-to-win) |
| **Target Release** | TBD |
| **Team Size** | Solo / Indie |

### Elevator Pitch
> Nuôi một con thú ảo cute — chăm sóc, trang trí phòng, và customize ngoại hình thú theo phong cách riêng.

---

## Core Loop

```
Chăm sóc thú → Kiếm coins/gems → Mua item/skin → Trang trí phòng + Customize thú
```

---

## Stats System

| Stat | Range | Decay | Recovery |
|---|---|---|---|
| Hunger | 0–100 | -0.5/s (debug) / -1/15 phút thực | +30 khi ăn |
| Thirst | 0–100 | -0.4/s (debug) / -1/12 phút thực | +30 khi uống |
| Energy | 0–100 | -0.1/s (debug) / -1/1 giờ thực | +2/s khi ngủ |
| Happiness | 0–100 | -0.15/s (debug) / -1/30 phút thực | +15 khi được vuốt |

### State Machine

| State | Điều kiện |
|---|---|
| IDLE | Mặc định |
| HAPPY | Sau khi feed/water/pet (override 2 giây) |
| HUNGRY | Hunger < 20 |
| TIRED | Energy < 20 |
| SLEEPING | is_sleeping = true |

---

## Pet Behavior

Mèo hoạt động tự động dựa theo stats và personality:

- **Wander** — đi loanh quanh phòng ngẫu nhiên
- **Eat** — tự đi đến FoodBowl khi Hunger < 30
- **Drink** — tự đi đến WaterBowl/Fountain khi Thirst < 30
- **Sleep** — tự đi đến CatBed khi Energy < 30
- **Follow** — đi lại gần mèo khác (theo Affection)
- **Bother** — quấy phá mèo đang ngủ (theo Playfulness)

Mỗi mèo có 4 personality traits ngẫu nhiên khi spawn: `laziness`, `playfulness`, `affection`, `curiosity` — ảnh hưởng xác suất chọn hành động.

### Animations hiện có

| Animation | Mô tả |
|---|---|
| idle / idle3 / idle4 / idle6 | Ngồi yên, các biểu cảm ngẫu nhiên |
| walk_side / walk_up / walk_down | Di chuyển 3 hướng |
| eat_start / eat_loop / eat_end | Ăn |
| drink_start / drink_loop / drink_end | Uống |
| sleep_prepare / sleeping / sleep_done | Ngủ |
| tired | Mệt mỏi |
| sofull | No bụng nằm ngửa |

---

## Cat Customization System

*(Planned — Layered Sprite System)*

Mỗi con mèo được render bằng nhiều lớp chồng nhau, tất cả share cùng animation sheets:

```
Pet
├── BodySprite (AnimatedSprite2D)     ← base cat, modulate = fur color
├── PatternSprite (AnimatedSprite2D)  ← markings/spots/stripes overlay
└── AccessorySprite (Sprite2D)        ← item đeo trên người (hat, collar...)
```

### Cat Style Config

```gdscript
{
  "id": "spotted",
  "base_color": Color(...),
  "pattern_sheets": { "idle": "res://...", "walk_side": "res://...", ... },
  "pattern_color": Color(...)
}
```

### Art cần cho mỗi style mới
- Pattern sheets (chỉ vẽ phần marking, nền transparent) — 1 sheet/animation
- 1 entry config — không cần code mới

---

## Room System

- Room load từ JSON (`data/rooms/room_1.json`)
- Background: ảnh hoặc màu solid
- Grid system: chia surface `floor`, `wall_left`, `wall_right` thành ô isometric
- Items snap vào ô grid khi đặt
- Room state lưu về JSON sau mỗi thay đổi

### Items hiện có

| Item | Surface | Mô tả |
|---|---|---|
| FoodBowl | floor | Cho mèo ăn |
| WaterBowl | floor | Cho mèo uống |
| Fountain | floor | Cho mèo uống |
| CatBed (small/large) | floor | Mèo ngủ |
| CatTree | floor | Đồ chơi leo trèo |
| Toy (9 loại) | floor | Đồ chơi |
| Plant (small/large) | floor | Trang trí |
| Shelf | floor | Trang trí |
| WallDeco / WallDecoBig / WallDecoMid | wall | Trang trí tường |
| Window (4 loại) | wall | Cửa sổ |
| WallLamp | wall | Đèn (có hiệu ứng ánh sáng đêm) |

---

## Shop & Economy

### Currency
- **Coins** — kiếm từ chăm sóc thú, dùng mua items thường
- **Gems** — premium, dùng mua items đặc biệt

### Shop
- Tab: Items, Offers, Top-up
- Sub-tab: phân loại theo category (từ `data/shop.json`)
- Hỗ trợ limited stock (badge xN)
- Sort theo giá tăng/giảm

### Bag
- Hiển thị items đã mua
- Drag item từ bag vào phòng để đặt
- Drag item trong phòng về bag để thu hồi

---

## UI Structure

```
HUD (CanvasLayer)
├── StatsWidget       — avatar, player name, level, game time
├── CurrencyContainer — coin + gem display
├── ShopBtn / BagBtn  — mở Shop / Bag panel
├── ShopPanel         — cửa hàng mua items
└── BagPanel          — kho đồ + drag-to-place
```

### Visual Theme
- Pixel art style, font Jersey 25
- Màu chủ đạo: nâu ấm, kem, tan
- Buttons: 4 theme màu (brown, cream, pink, tan)

---

## Game Time

- 1 giây thực = 1 phút game (scale 1/60)
- Hiển thị dạng 12-hour (6:00 AM → 11:59 PM → ...)
- Night overlay shader: tối dần từ 11:00 PM, sáng lại từ 6:00 AM
- WallLamp tạo vùng sáng cục bộ trong đêm

---

## Save System

| File | Nội dung |
|---|---|
| `user://player_data.json` | coins, gems, player name, level, game time |
| `user://inventory.json` | danh sách item đã mua |
| `res://data/rooms/room_1.json` | trạng thái phòng (items, positions, background) |

---

## Milestones

| Phase | Nội dung | Status |
|---|---|---|
| Phase 1 | Core pet + stats + room + shop + bag | ✅ Done |
| Phase 2 | Cat Customization (Layered Sprite System) | 🔲 Next |
| Phase 3 | Accessory system (item on pet) | 🔲 Planned |
| Phase 4 | Progression + leveling + evolution | 🔲 Planned |
| Phase 5 | Multiple rooms | 🔲 Planned |
| Phase 6 | Polish + monetization balancing | 🔲 Planned |
