extends StaticBody2D

signal food_changed(amount: float)

const EAT_DURATION            := 5.0
const FOOD_PER_SESSION        := 0.25
const COLLISION_RESTORE_DELAY := 2.0

var has_food    : bool  = true
var food_amount : float = 1.0

var _feeding_pets : Array = []
var _eat_timer    : float = 0.0

@onready var _sprite : Sprite2D = $Sprite2D

func _ready() -> void:
	input_event.connect(_on_input_event)
	_update_visual()

func _process(delta: float) -> void:
	if _feeding_pets.is_empty(): return
	_eat_timer -= delta
	if _eat_timer <= 0.0:
		_finish_feed()

func start_feed(pet: Node) -> void:
	if not has_food: return
	if pet in _feeding_pets: return
	_feeding_pets.append(pet)
	if _eat_timer <= 0.0:
		_eat_timer = EAT_DURATION
	pet.eat()

func _finish_feed() -> void:
	get_tree().create_timer(COLLISION_RESTORE_DELAY).timeout.connect(func(): collision_layer = 1)
	for pet in _feeding_pets:
		if is_instance_valid(pet):
			pet.on_eat_completed()
	_feeding_pets.clear()
	food_amount = maxf(food_amount - FOOD_PER_SESSION, 0.0)
	has_food    = food_amount > 0.05
	_update_visual()
	emit_signal("food_changed", food_amount)

func refill() -> void:
	food_amount = 1.0
	has_food    = true
	_update_visual()
	emit_signal("food_changed", food_amount)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if has_food: return
	if event is InputEventScreenTouch and event.pressed:
		refill()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		refill()

func _update_visual() -> void:
	if not _sprite: return
	_sprite.modulate = Color(1.0, 1.0, 1.0) if has_food else Color(0.55, 0.55, 0.55)
