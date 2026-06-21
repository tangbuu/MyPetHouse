class_name WallLamp
extends StaticBody2D

@onready var _sprite : Sprite2D = $SpriteLamp

var _sheet : Texture2D = preload("res://assets/item/lamp/lamp_sheet.png")

# Global registry — Main reads this to feed positions to the night shader
static var all_lamps : Array = []

var is_on       : bool  = false
var _last_hours : float = -1.0

func _ready() -> void:
	_sprite.texture        = _sheet
	_sprite.region_enabled = true
	_update(DataManager.game_time_hours)

func _enter_tree() -> void:
	if not all_lamps.has(self):
		all_lamps.append(self)

func _process(_delta: float) -> void:
	var h := DataManager.game_time_hours
	if h == _last_hours: return
	_last_hours = h
	_update(h)

func _update(hours: float) -> void:
	var alpha: float
	if hours < 11.0:
		alpha = 0.0
	elif hours < 13.0:
		alpha = lerpf(0.0, 1.0, (hours - 11.0) / 2.0)
	elif hours < 21.0:
		alpha = 1.0
	else:
		alpha = lerpf(1.0, 0.0, (hours - 21.0) / 3.0)
	is_on = alpha > 0.0
	_sprite.region_rect = Rect2(86, 0, 86, 101) if is_on else Rect2(0, 0, 86, 101)

func get_wall_dir() -> float:
	match get_meta("grid_surface", ""):
		"wall_left":  return 1.0
		"wall_right": return -1.0
		_:            return 0.0

func _exit_tree() -> void:
	all_lamps.erase(self)
