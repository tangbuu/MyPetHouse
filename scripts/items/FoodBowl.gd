extends StaticBody2D

@export var config: PetConfig = null

var _feeding_pets : Array     = []
var _eat_timer    : float     = 0.0
var _cfg          : PetConfig

func _ready() -> void:
	_cfg = config if config else PetConfig.new()

func _process(delta: float) -> void:
	if _feeding_pets.is_empty(): return
	_eat_timer -= delta
	if _eat_timer <= 0.0:
		_finish_feed()

func start_feed(pet: Node) -> void:
	if pet in _feeding_pets: return
	_feeding_pets.append(pet)
	if _eat_timer <= 0.0:
		_eat_timer = _cfg.eat_duration
	pet.eat()

func _finish_feed() -> void:
	for pet in _feeding_pets:
		if is_instance_valid(pet):
			pet.on_eat_completed()
	_feeding_pets.clear()
