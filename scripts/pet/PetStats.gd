extends Resource
class_name PetStats

var hunger: float    = 80.0
var thirst: float    = 80.0
var energy: float    = 80.0
var happiness: float = 80.0

const DEBUG_MODE: bool = true

const HUNGER_DECAY:   float = 0.5   if DEBUG_MODE else 0.00111
const THIRST_DECAY:   float = 0.4   if DEBUG_MODE else 0.00139
const ENERGY_DECAY:   float = 0.1   if DEBUG_MODE else 0.000278
const ENERGY_RECOVER: float = 2.0   if DEBUG_MODE else 0.05
const HAPPY_DECAY:    float = 0.15  if DEBUG_MODE else 0.000556

func tick(delta: float, is_sleeping: bool) -> void:
	hunger    = maxf(hunger    - HUNGER_DECAY * delta, 0.0)
	thirst    = maxf(thirst    - THIRST_DECAY * delta, 0.0)
	happiness = maxf(happiness - HAPPY_DECAY  * delta, 0.0)
	if is_sleeping:
		energy = minf(energy + ENERGY_RECOVER * delta, 100.0)
	else:
		energy = maxf(energy - ENERGY_DECAY * delta, 0.0)

func apply_feed() -> void:
	hunger = minf(hunger + 30.0, 100.0)

func apply_water() -> void:
	thirst = minf(thirst + 30.0, 100.0)

func apply_pet() -> void:
	happiness = minf(happiness + 15.0, 100.0)
