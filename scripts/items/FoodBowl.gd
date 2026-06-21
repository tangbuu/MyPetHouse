extends StaticBody2D

@export var config: PetConfig = null

var _feeding_pet  : Node      = null
var _eat_timer    : float     = 0.0
var _cfg          : PetConfig

func _ready() -> void:
	_cfg = config if config else PetConfig.new()

func is_in_use() -> bool:
	return _feeding_pet != null and is_instance_valid(_feeding_pet)

func _process(delta: float) -> void:
	if not _feeding_pet: return
	_eat_timer -= delta
	if _eat_timer <= 0.0:
		_finish_feed()

func start_feed(pet: Node) -> void:
	if _feeding_pet: return
	_feeding_pet = pet
	_eat_timer   = _cfg.eat_duration
	pet.eat()

func _finish_feed() -> void:
	if is_instance_valid(_feeding_pet):
		_feeding_pet.on_eat_completed()
	_feeding_pet = null
