extends Node

signal stats_changed(stat_name: String, value: float)
signal state_changed(new_state: int)

var stats: PetStats
var is_sleeping: bool = false
var current_state: int = PetStateMachine.State.IDLE

var _override_state: int = -1
var _override_timer: float = 0.0

func _ready() -> void:
	stats = PetStats.new()

func _process(delta: float) -> void:
	stats.tick(delta, is_sleeping)

	stats_changed.emit("hunger",    stats.hunger)
	stats_changed.emit("thirst",    stats.thirst)
	stats_changed.emit("energy",    stats.energy)
	stats_changed.emit("happiness", stats.happiness)

	_update_state(delta)

func _update_state(delta: float) -> void:
	if _override_timer > 0.0:
		_override_timer -= delta
		if _override_timer <= 0.0:
			_override_state = -1

	var new_state: int
	if _override_state >= 0:
		new_state = _override_state
	else:
		new_state = PetStateMachine.evaluate(stats, is_sleeping)

	if new_state != current_state:
		current_state = new_state
		state_changed.emit(current_state)

# --- Actions ---

func feed() -> void:
	stats.apply_feed()
	_set_override(PetStateMachine.State.HAPPY, 2.0)

func water() -> void:
	stats.apply_water()
	_set_override(PetStateMachine.State.HAPPY, 2.0)

func pet_action() -> void:
	stats.apply_pet()
	_set_override(PetStateMachine.State.HAPPY, 2.0)

func toggle_sleep() -> void:
	is_sleeping = !is_sleeping
	if not is_sleeping:
		_override_state = -1
		_override_timer = 0.0

func _set_override(state: int, duration: float) -> void:
	_override_state = state
	_override_timer = duration
