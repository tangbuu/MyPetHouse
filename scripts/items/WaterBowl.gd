extends StaticBody2D

signal water_changed(amount: float)

const DRINK_DURATION       := 3.0  # seconds per drink session
const WATER_PER_SESSION    := 0.2  # depleted per drink → 5 drinks = empty
const DRINK_THIRST_RESTORE := 1.0  # fully restores thirst

var has_water    : bool  = true
var water_amount : float = 1.0

var _drinking_pet : Node  = null
var _drink_timer  : float = 0.0

@onready var _sprite : Sprite2D = $Sprite2D

func _ready() -> void:
	input_event.connect(_on_input_event)
	_update_visual()

func _process(delta: float) -> void:
	if not _drinking_pet: return
	_drink_timer -= delta
	if _drink_timer <= 0.0:
		_finish_drink()

# ── Called by Pet when it arrives at the bowl ─────────────────────────────────

func start_drink(pet: Node) -> void:
	if not has_water or _drinking_pet: return
	_drinking_pet = pet
	_drink_timer  = DRINK_DURATION
	if pet.has_method("drink"):
		pet.drink()

func _finish_drink() -> void:
	collision_layer = 1
	if _drinking_pet and is_instance_valid(_drinking_pet):
		_drinking_pet.set("thirst", 1.0)
		if _drinking_pet.has_method("stop_drink"):
			_drinking_pet.stop_drink()
	_drinking_pet = null
	water_amount  = maxf(water_amount - WATER_PER_SESSION, 0.0)
	has_water     = water_amount > 0.05
	_update_visual()
	emit_signal("water_changed", water_amount)

# ── Player taps to refill ─────────────────────────────────────────────────────

func refill() -> void:
	water_amount = 1.0
	has_water    = true
	_update_visual()
	emit_signal("water_changed", water_amount)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if has_water: return
	if event is InputEventScreenTouch and event.pressed:
		refill()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		refill()

# ── Visual ────────────────────────────────────────────────────────────────────

func _update_visual() -> void:
	if not _sprite: return
	_sprite.modulate = Color(1.0, 1.0, 1.0) if has_water else Color(0.55, 0.55, 0.55)
