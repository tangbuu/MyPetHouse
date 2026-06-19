extends Resource
class_name PetConfig

## Tất cả hằng số game-balance tập trung tại đây.
## Tạo file .tres trong Godot: FileSystem → chuột phải → New Resource → PetConfig
## Gán file .tres vào Pet.config trong Inspector.
## Tạo nhiều file (CatConfig_Lazy.tres, CatConfig_Active.tres) cho các loại mèo khác nhau.

@export_group("Stats — Decay (per second)")
@export var hunger_decay     : float = 0.0015
@export var thirst_decay     : float = 0.0020
@export var energy_decay     : float = 0.0008
@export var energy_sleep_gain: float = 0.003

@export_group("Stats — Gains on action")
@export var hunger_eat_gain  : float = 1.0
@export var thirst_drink_gain: float = 1.0

@export_group("Stats — Thresholds")
## Dưới ngưỡng này → Pet bắt đầu tìm Ăn/Uống/Ngủ
@export var urgency_threshold    : float = 0.3
## Năng lượng đủ cao → Pet thức dậy khỏi giấc ngủ
@export var energy_full_threshold: float = 0.95

@export_group("Movement")
@export var move_speed  : float = 45.0
@export var acceleration: float = 400.0
@export var friction    : float = 500.0
## Tốc độ (px/s) dưới mức này → xem là "đứng yên" và cho phép idle animation
@export var vel_idle_threshold: float = 5.0

@export_group("Animation Timing")
## Delay nhỏ giữa idle_random kết thúc và lần chọn hành vi tiếp theo
@export var idle_random_next_delay : float = 0.3
## Rate-limit: khoảng thời gian tối thiểu giữa 2 lần trigger urgent behavior
@export var behavior_cooldown_reset: float = 3.0

@export_group("Food Bowl")
@export var eat_duration    : float = 5.0   # thời gian 1 lần ăn (giây)
@export var food_per_session: float = 0.25  # lượng thức ăn tiêu hao mỗi lần

@export_group("Water Bowl")
@export var drink_duration    : float = 3.0  # thời gian 1 lần uống (giây)
@export var water_per_session : float = 0.2  # lượng nước tiêu hao mỗi lần
