extends PetBehavior
class_name DrinkBehavior

func _init() -> void:
	priority = 20.0

func should_activate(pet: Pet) -> bool:
	return enabled and pet.thirst < pet._cfg.urgency_threshold and pet.water_bowl_has_water()

func activate(pet: Pet) -> void:
	var dest     := pet.bowl_arrive_pos(pet.water_bowl)
	var face_pos := pet.water_bowl.global_position
	var cb       := func():
		if not pet.water_bowl_has_water():
			pet._do_natural_behavior()
			return
		pet.water_bowl.start_drink(pet)
	pet.begin_action(dest, cb, face_pos)
