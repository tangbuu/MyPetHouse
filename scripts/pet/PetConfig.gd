extends Resource
class_name PetConfig

## Tất cả hằng số game-balance tập trung tại đây.
## Tạo file .tres trong Godot: FileSystem → chuột phải → New Resource → PetConfig
## Gán file .tres vào Pet.config trong Inspector.

@export_group("Movement")
@export var move_speed  : float = 45.0
@export var acceleration: float = 400.0
@export var friction    : float = 500.0
## Tốc độ (px/s) dưới mức này → xem là "đứng yên" và cho phép idle animation
@export var vel_idle_threshold: float = 5.0

@export_group("Animation Timing")
## Delay nhỏ giữa idle_random kết thúc và lần chọn hành vi tiếp theo
@export var idle_random_next_delay : float = 0.3

@export_group("Food Bowl")
@export var eat_duration : float = 5.0

@export_group("Water Bowl")
@export var drink_duration : float = 3.0

@export_group("Sleep")
## Thời gian ngủ tối thiểu / tối đa (giây) trước khi mèo tự thức
@export var sleep_duration_min : float = 10.0
@export var sleep_duration_max : float = 20.0
