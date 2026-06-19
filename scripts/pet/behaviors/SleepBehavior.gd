extends PetBehavior
class_name SleepBehavior

func _init() -> void:
	priority = 10.0

func should_activate(pet: Pet) -> bool:
	return enabled and pet.energy < pet._cfg.urgency_threshold

func activate(pet: Pet) -> void:
	if pet.bed_node and pet.bed_is_free():
		pet.go_to_bed()
	else:
		pet._change_anim_state(Pet.AnimState.SLEEP_PREPARE)
