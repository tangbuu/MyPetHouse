# System Architecture Overview — Take Care Pets

> Mục đích: nắm vững "bộ khung" toàn dự án trước khi mở rộng tính năng mới.

---

## 1. KIẾN TRÚC ĐIỀU KHIỂN (Control Architecture)

### PetStateMachine (`scripts/pet/PetStateMachine.gd`)
Đây **không phải** một node điều khiển luồng — nó là một `RefCounted` thuần túy đóng vai trò **thư viện static utility**. Không có trạng thái nội tại, không nhận signal, không cập nhật mỗi frame.

Hai nhóm chức năng:
- **Query helpers (static):** `is_eating()`, `is_drinking()`, `is_sleeping()`, `is_busy()`, `is_interruptible()` — nhận `AnimState` int, trả về bool. Pet.gd dùng để guard/kiểm tra trước khi thay đổi hành vi.
- **Macro-state evaluator:** `evaluate(stats, is_sleeping)` → trả `State` enum (IDLE / HAPPY / HUNGRY / TIRED / SLEEPING). Hiện chỉ dùng để tương thích với `GameManager.state_changed`.

> **Tóm lại:** PetStateMachine là "bộ từ điển trạng thái" cho Pet.gd gọi nhờ, không phải engine điều khiển thực sự.

---

### Pet.gd (`scripts/pet/Pet.gd`)
Đây là **brain duy nhất** của con mèo — monolith xử lý tất cả:

| Trách nhiệm | Nơi xử lý |
|---|---|
| Quản lý Stats (hunger/thirst/energy) | `_tick_stats(delta)` — mỗi frame |
| AI hành vi tự nhiên | `_do_natural_behavior()` → priority queue + weighted random |
| Navigation có mục tiêu | `_on_arrive` Callable + timeout counter |
| Wander tự do | `_move_dir` + `_wander_timer` |
| Animation state machine nội bộ | `AnimState` enum + `_change_anim_state()` |
| Shadow rendering | `_update_shadow()` đọc `WallLamp.all_lamps` |
| Personality traits | `_laziness`, `_playfulness`, `_affection`, `_curiosity` (random khi spawn) |
| Social awareness | `_other_pets` array (được inject từ Main.gd) |

### Sự kết nối giữa các thành phần

```
GameManager ──signal state_changed──► Pet._on_state_changed()
                                          (chỉ react nếu không đang busy)

Pet ──direct call──► food_bowl.start_feed(self)
Pet ──direct call──► water_bowl.start_drink(self)
Pet ──direct call──► bed_node.collision_layer = 0/1

FoodBowl ──direct call──► pet.eat()  /  pet.on_eat_completed()
WaterBowl ──direct call──► pet.drink() / pet.on_drink_completed()

Pet ──signal clicked(pet)──► (HUD/Main lắng nghe nếu cần)
WallLamp ──static array all_lamps──► Pet._update_shadow() đọc trực tiếp
```

**Cơ chế giao tiếp chính:** Direct calls (không dùng signal cho luồng eat/drink/sleep). Signal chỉ dùng cho: `GameManager.state_changed` (global), `Pet.clicked` (UI), `FoodBowl.food_changed` / `WaterBowl.water_changed` (cho HUD nếu kết nối).

---

## 2. QUẢN LÝ DỮ LIỆU & TRẠNG THÁI (State & Data Management)

### Stats: Hunger / Thirst / Energy
Ba biến float `0.0 → 1.0` nằm trực tiếp trong Pet.gd.

**Luồng decay (mỗi frame):**
```
_tick_stats(delta):
  hunger  -= HUNGER_DECAY * delta   (0.0015/frame → ~11 phút hết)
  thirst  -= THIRST_DECAY * delta   (0.0020/frame → ~8 phút hết)
  energy  -= ENERGY_DECAY * delta   (0.0008/frame → ~20 phút hết)
  // Nếu đang SLEEPING: energy += ENERGY_SLEEP_GAIN * delta thay vì decay
```

**Luồng phục hồi (qua Item):**
```
Pet nhận ra hunger < 0.3 (URGENCY_THRESHOLD)
  → _decide_hunger()
  → disable food_bowl.collision_layer
  → _move_to(bowl ArriveSpot)
  → (tới nơi) food_bowl.start_feed(self)
  → FoodBowl chạy timer 5 giây
  → FoodBowl gọi pet.on_eat_completed()
  → Pet: hunger = min(hunger + 1.0, 1.0), chuyển EAT_END
```

Tương tự cho Thirst (WaterBowl, 3 giây) và Energy (CatBed, tăng khi SLEEPING).

### Bộ nhớ trạng thái quan trọng

| Biến | Loại | Vai trò |
|---|---|---|
| `_anim_state` | AnimState enum | Trạng thái animation hiện tại (internal FSM của Pet) |
| `_current_state` | int | Mirror của GameManager.current_state |
| `_nav_target` | String | Mục tiêu navigation hiện tại: `"bowl"` / `"water"` / `"bed"` / `""` |
| `_on_arrive` | Callable | Callback thực thi khi đến đích |
| `_interaction_timeout` | float | Countdown timer — bỏ cuộc nếu về 0 |
| `_last_idle_name` | String | Tên idle animation vừa phát — lọc để **không lặp lại** lần tiếp |
| `_behavior_cooldown` | float | Rate-limit: tránh spam urgent behavior mỗi frame (reset = 3s) |
| `_move_dir` / `_wander_timer` | Vector2 / float | Hướng và thời gian còn lại của lần wander tự do |
| `_bed_collision_disabled` | bool | Guard để chỉ restore bed collision đúng 1 lần |

---

## 3. HỆ THỐNG PHẢN ỨNG VỚI MÔI TRƯỜNG (Interaction Logic)

### Navigation & Collision

Pet dùng **pure steering** (không có NavMesh):
- `_target_pos` là điểm đích tuyệt đối trong world space
- Mỗi frame tính `diff = _target_pos - global_position`, normalize → `velocity`
- `move_and_slide()` xử lý va chạm với StaticBody2D (tường, đồ vật)

**Xử lý khi bị chặn (Detour system):**
1. Nếu `get_slide_collision_count() > 0` → lấy collision normal → đặt `_detour_dir`, `_detour_timer = 1.0`
2. Trong `_detour_timer > 0`: đi theo `_detour_dir` (perpendicular + forward blend) thay vì thẳng đến đích
3. `_detour_count` tăng mỗi lần detour. Nếu `>= 3` → chấp nhận arrived (snap đến vị trí gần)
4. **Stuck detection:** Mỗi 0.5s kiểm tra `global_position.distance_to(_stuck_pos) < 6px` — nếu không nhúc nhích và còn xa → trigger detour

**Va chạm với mèo khác (Cat bumping):**
- Wander mode: nếu slide collision → đổi hướng sang collision normal, set `_cat_bump_cooldown = 1.0s`
- Cooldown ngăn mèo liên tục đổi hướng khi bị kẹp giữa hai vật

### Cơ chế "Bỏ cuộc" (Timeout logic)

```
Khi _nav_target != "" và _on_arrive.is_valid():
  _interaction_timeout -= delta
  Nếu <= 0:
    → print "gave up navigating to: X"
    → Restore collision_layer = 1 cho item mục tiêu
    → Reset _nav_target = "", _on_arrive = Callable()
    → velocity = Vector2.ZERO
    → _do_natural_behavior()  ← thử lại với priority khác
```

Timeout constants:
- `NAV_TIMEOUT_BOWL = 10.0s` — food và water bowl
- `NAV_TIMEOUT_BED = 15.0s` — CatBed (xa hơn, phức tạp hơn)

**Trường hợp đặc biệt:** Nếu mèo bị stuck gần giường nhưng giường đã bị mèo khác chiếm (`_bed_is_free() == false`) → bỏ qua navigation, sleep ngay tại chỗ (SLEEP_PREPARE tại vị trí hiện tại).

---

## 4. BỘ KHUNG PHÁT TRIỂN (Development Framework)

### Các thành phần "tĩnh" tương tác với hệ thống

| Item | Script | Tương tác với Pet |
|---|---|---|
| **FoodBowl** | `FoodBowl.gd` (StaticBody2D) | Nhận `start_feed(pet)`, gọi ngược `pet.eat()` + `pet.on_eat_completed()`. Hỗ trợ nhiều mèo cùng lúc (`_feeding_pets` array). Refill khi tap. |
| **WaterBowl** | `WaterBowl.gd` (StaticBody2D) | Nhận `start_drink(pet)`, gọi ngược `pet.drink()` + `pet.on_drink_completed()`. Chỉ 1 mèo tại một thời điểm. Refill khi tap. |
| **CatBed** | Không có script riêng | Chỉ là Node2D với child `SleepSpot` Marker2D. Pet đọc `bed_node.get_node_or_null("SleepSpot")` để lấy vị trí đích. Pet tự quản lý collision_layer của bed. |
| **WallLamp** | `WallLamp.gd` | Không tương tác trực tiếp với AI. Dùng static array `WallLamp.all_lamps` — Pet đọc để tính hướng bóng shader mỗi frame. |
| **Toy, CatTree, Shelf, Plants** | Không có script tương tác | Pure visual/physics nodes. Chưa kết nối với hệ thống AI. |

### Các hằng số điều chỉnh hành vi

**Tất cả hằng số game balance của Pet tập trung tại đầu `Pet.gd` (lines 22–39):**

```gdscript
# Stat rates
HUNGER_DECAY / THIRST_DECAY / ENERGY_DECAY         # tốc độ giảm mỗi frame
HUNGER_EAT_GAIN / THIRST_DRINK_GAIN / ENERGY_SLEEP_GAIN  # phục hồi khi action

# Behavior tuning
URGENCY_THRESHOLD     = 0.3    # dưới ngưỡng này → hành xử khẩn cấp
ENERGY_FULL_THRESHOLD = 0.95   # energy đủ để thức dậy
WANDER_AFTER_ACTION_{MIN/MAX}  # wander ngắn sau khi ăn/uống/ngủ xong
BEHAVIOR_COOLDOWN_RESET = 3.0  # rate-limit urgent behavior trigger

# Navigation
NAV_TIMEOUT_BOWL = 10.0s / NAV_TIMEOUT_BED = 15.0s
COLLISION_RESTORE_DELAY = 2.0s
ARRIVE_DIST_DEFAULT = 52.0 / ARRIVE_DIST = 5.0
```

**Hằng số của Items** nằm tại đầu file tương ứng (không được gom về một chỗ):
- `FoodBowl.gd`: `EAT_DURATION = 5.0s`, `FOOD_PER_SESSION = 0.25`
- `WaterBowl.gd`: `DRINK_DURATION = 3.0s`, `WATER_PER_SESSION = 0.2`

---

## 5. MỤC TIÊU VÀ KHẢ NĂNG MỞ RỘNG (Scalability)

### Điểm mạnh của kiến trúc hiện tại

**Thêm item tương tác mới rất dễ** — chỉ cần tuân theo pattern đã thiết lập:
1. Tạo scene + script kế thừa `StaticBody2D`
2. Implement `start_X(pet)` → chạy timer → gọi `pet.on_X_completed()`
3. Thêm `ARRIVE_DIST` nhỏ để Pet navigate đúng
4. Đăng ký trong `Pet.gd` qua `_room.get_item_by_script("NewItem")` (lookup bằng tên file script)

**Multi-pet tự động hoạt động** — `_other_pets` array cho phép mỗi Pet biết về nhau mà không cần coordinator trung tâmn. Social behaviors (follow, bother) đã có framework.

**Grid system tách biệt** — `RoomGridSystem` xử lý placement hoàn toàn độc lập với AI. Item mới chỉ cần đăng ký trong `objectGrid.json` để có drag-drop đúng grid.

**Data-driven room** — Room load từ JSON, không cần sửa code để thêm đồ vật. Item thêm vào `room_1.json` là có ngay trong game.

### Điểm cần chú ý khi mở rộng

- **Pet.gd là monolith** — Thêm hành vi mới (ví dụ: chơi với CatTree) đồng nghĩa thêm `_decide_play()` + `_nav_target` case mới trực tiếp vào Pet.gd. Hiện tại manageable nhưng sẽ phức tạp nếu thêm nhiều loại interaction.
- **Hằng số item phân tán** — `EAT_DURATION`, `DRINK_DURATION` nằm ở item scripts riêng, không cùng chỗ với hằng số Pet. Cần nhớ sửa cả hai nơi khi balance.
- **Không có pathfinding** — Steering+detour hoạt động tốt cho room nhỏ, nhưng với layout phức tạp hơn (nhiều vật cản) sẽ cần nâng cấp hoặc thêm NavigationAgent2D.
- **WaterBowl chỉ 1 mèo** — FoodBowl hỗ trợ multi-pet, WaterBowl chưa. Cần đồng bộ nếu có nhiều mèo.

---

*Cập nhật lần cuối: 2026-06-19*
