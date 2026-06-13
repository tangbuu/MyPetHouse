extends Resource
class_name PetStats

var hunger: float = 80.0
var happiness: float = 80.0
var energy: float = 80.0

# Production rates (per second)
const HUNGER_DECAY_PROD: float    = 0.00111   # -1 per 15 min
const HAPPINESS_DECAY_PROD: float = 0.000556  # -1 per 30 min
const ENERGY_DECAY_PROD: float    = 0.000278  # -1 per 60 min
const ENERGY_RECOVER_PROD: float  = 0.05      # +3 per min when sleeping

# Debug rates — visible in ~2–5 min
const HUNGER_DECAY_DEBUG: float    = 0.5
const HAPPINESS_DECAY_DEBUG: float = 0.2
const ENERGY_DECAY_DEBUG: float    = 0.1
const ENERGY_RECOVER_DEBUG: float  = 2.0

const DEBUG_MODE: bool = true

var hunger_decay: float    = HUNGER_DECAY_DEBUG    if DEBUG_MODE else HUNGER_DECAY_PROD
var happiness_decay: float = HAPPINESS_DECAY_DEBUG if DEBUG_MODE else HAPPINESS_DECAY_PROD
var energy_decay: float    = ENERGY_DECAY_DEBUG    if DEBUG_MODE else ENERGY_DECAY_PROD
var energy_recover: float  = ENERGY_RECOVER_DEBUG  if DEBUG_MODE else ENERGY_RECOVER_PROD

func tick(delta: float, is_sleeping: bool) -> void:
	hunger    = max(0.0, hunger    - hunger_decay    * delta)
	happiness = max(0.0, happiness - happiness_decay * delta)
	if is_sleeping:
		energy = min(100.0, energy + energy_recover * delta)
	else:
		energy = max(0.0, energy - energy_decay * delta)

func apply_feed() -> void:
	hunger = min(100.0, hunger + 20.0)

func apply_pet() -> void:
	happiness = min(100.0, happiness + 15.0)
