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
| **AI Integration** | Gemini Nano (on-device) + Gemini 2.0 Flash (online) |

### Elevator Pitch
> Nuôi một con thú ảo có AI — nó trò chuyện, phản ứng theo cảm xúc thật, và có thể **nhảy ra ngoài màn hình** để đồng hành cùng bạn suốt cả ngày.

---

## Concept

### Core Loop
```
Chăm sóc thú → Thú lớn lên → Unlock tính cách / hình dáng mới → Chăm sóc sâu hơn
```

### Unique Selling Points
1. **AI Personality** — mỗi thú có tính cách riêng, trả lời tự nhiên qua Gemini
2. **Overlay Mode** — thú nhảy ra ngoài, đi lại trên màn hình kể cả khi dùng app khác (Android)
3. **Screen Awareness** — thú có thể "nhìn" màn hình và comment (Gemini Vision)
4. **Offline-first** — Gemini Nano xử lý reactions cơ bản không cần internet

---

## AI Integration

| Tình huống | AI sử dụng | Cost |
|---|---|---|
| Reaction cơ bản (happy, sad, hungry) | Gemini Nano (on-device) | Free hoàn toàn |
| Trò chuyện với thú | Gemini 2.0 Flash | Free tier (1500 req/ngày) |
| Thú nhìn màn hình và comment | Gemini 2.0 Flash Vision | Free tier |
| Phát hiện cảm xúc user qua camera | MediaPipe (on-device) | Free hoàn toàn |

### AI Personality System
- Mỗi thú có **personality prompt** riêng khi khởi tạo
- Lịch sử hội thoại lưu local (giới hạn 20 messages gần nhất)
- Thú nhớ tên user, sở thích, thói quen

---

## Basic Actions

### Pet States (Trạng thái)
```
IDLE          — đứng yên, thở nhẹ, nhìn xung quanh
HAPPY         — nhảy, vẫy đuôi, xoay tròn
SAD           — cúi đầu, mắt rớm nước
HUNGRY        — nhìn food bowl, bụng kêu
TIRED         — ngáp, mắt nặng dần
SLEEPING      — nằm, ZZZ animation
SICK          — xanh mặt, loạng choạng
ANGRY         — mặt đỏ, dậm chân
EXCITED       — chạy lòng vòng
BORED         — nhìn trái nhìn phải, thở dài
LOVE          — tim nổi lên, ánh mắt long lanh
```

### User-triggered Actions
```
EAT           — cho ăn → animation nhai → Hunger +
DRINK         — uống nước → Hunger/Energy +
PET           — chạm vào thú → Happy burst → Happiness +
PLAY          — mini game ngắn → Happiness + / Energy -
SLEEP         — cho ngủ / tự ngủ khi Tired → Energy recover
BATH          — kéo bọt xà phòng → Cleanliness +
TALK          — gọi AI conversation → Happiness +
GIFT          — nhận item → Excited animation
MEDICINE      — khi Sick → Health recover
LEVELUP       — đủ EXP → celebration animation + evolution option
```

### Overlay Actions (ngoài màn hình)
```
WANDER        — đi bộ ngang màn hình
REACT         — comment về app đang dùng (Gemini Vision)
TAP_ESCAPE    — user tap → thú chạy trốn sang góc khác
IDLE_FLOAT    — ngồi góc màn hình, thỉnh thoảng nhìn lên
DRAG          — user kéo thú đến vị trí khác
SLEEP_CORNER  — ngủ ở góc màn hình khi Energy thấp
NOTIFICATION  — rung nhẹ + animation khi thú cần gì đó
```

---

## Stats System

```
Hunger        0–100   giảm -1 mỗi 15 phút thực
Happiness     0–100   giảm -1 mỗi 30 phút thực
Energy        0–100   giảm khi play, recover khi sleep
Cleanliness   0–100   giảm -1 mỗi 1 giờ thực
Health        0–100   bị kéo xuống nếu stats khác < 20
EXP                   tăng theo mọi interaction
Level         1–50    mỗi level unlock content mới
```

### Stat Consequence
| Stat | Nếu = 0 | Effect |
|---|---|---|
| Hunger | Starving | Health -2/giờ, Angry state |
| Happiness | Depressed | Từ chối tương tác, Sad state |
| Energy | Exhausted | Tự ngủ, không play được |
| Cleanliness | Dirty | Sick chance tăng |
| Health | Critical | Animation bệnh nặng, cần medicine |

---

## Progression System

### Evolution Path (ví dụ)
```
Egg → Baby (Lv 1–10) → Child (Lv 11–25) → Adult (Lv 26–40) → Legend (Lv 41–50)
```
- Mỗi stage thay đổi sprite + mở thêm personality traits
- User chọn hướng evolution dựa trên cách chăm sóc

---

## Monetization (cosmetics only)

- Skin / outfit cho thú
- Background / nhà mới
- Accessory (mũ, kính, đồ chơi)
- Tất cả có thể earn in-game (chậm hơn) hoặc mua (không ảnh hưởng gameplay)

---

## Tech Stack

```
Engine        Godot 4.x
Language      GDScript
AI (offline)  Gemini Nano via Android GMS API
AI (online)   Gemini 2.0 Flash REST API
Vision AI     Gemini 2.0 Flash (screenshot → comment)
Face detect   MediaPipe (on-device)
Overlay       Android SYSTEM_ALERT_WINDOW (native plugin)
Storage       Local SQLite (stats, chat history, save data)
```

---

## Milestones

| Phase | Nội dung | Status |
|---|---|---|
| Phase 1 | Core pet + stats + basic actions | Planning |
| Phase 2 | AI conversation (Gemini Flash) | Planning |
| Phase 3 | Overlay mode (Android plugin) | Planning |
| Phase 4 | Screen awareness (Vision AI) | Planning |
| Phase 5 | Progression + evolution | Planning |
| Phase 6 | Monetization + polish | Planning |
