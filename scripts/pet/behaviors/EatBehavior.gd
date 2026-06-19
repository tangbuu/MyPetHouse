extends PetBehavior
class_name EatBehavior

func _init() -> void:
	priority = 30.0

func should_activate(pet: Pet) -> bool:
	return enabled and pet.hunger < pet._cfg.urgency_threshold and pet.food_bowl_has_food()

func activate(pet: Pet) -> void:
	var dest     := pet.bowl_arrive_pos(pet.food_bowl)
	var face_pos := pet.food_bowl.global_position
	var cb       := func():
		if not pet.food_bowl_has_food():
			pet._do_natural_behavior()
			return
		pet.food_bowl.start_feed(pet)
	pet.begin_action(dest, cb, face_pos)
