extends StaticBody2D

@export var config: PetConfig = null

var _drinking_pet : Node      = null
var _drink_timer  : float     = 0.0
var _cfg          : PetConfig

func _ready() -> void:
	_cfg = config if config else PetConfig.new()

func _process(delta: float) -> void:
	if not _drinking_pet: return
	_drink_timer -= delta
	if _drink_timer <= 0.0:
		_finish_drink()

func is_in_use() -> bool:
	return _drinking_pet != null and is_instance_valid(_drinking_pet)

func start_drink(pet: Node) -> void:
	if _drinking_pet: return
	_drinking_pet = pet
	_drink_timer  = _cfg.drink_duration
	if pet.has_method("drink"):
		pet.drink()

func _finish_drink() -> void:
	if _drinking_pet and is_instance_valid(_drinking_pet):
		if _drinking_pet.has_method("on_drink_completed"):
			_drinking_pet.on_drink_completed()
	_drinking_pet = null
