extends RefCounted
class_name PetStateMachine

enum State {
	IDLE,
	HAPPY,
	HUNGRY,
	TIRED,
	SLEEPING,
}

static func evaluate(stats: PetStats, is_sleeping: bool) -> State:
	if is_sleeping:
		return State.SLEEPING
	if stats.energy < 20.0:
		return State.TIRED
	if stats.hunger < 20.0:
		return State.HUNGRY
	return State.IDLE
