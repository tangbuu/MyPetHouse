extends CharacterBody2D
class_name Pet

const IDLE_DIR   := "res://assets/cat/blackCat/idle/idel_1/"
const IDLE_DIRS := [
	"res://assets/cat/blackCat/idle/idel_2/",
	"res://assets/cat/blackCat/idle/idel_3/",
	"res://assets/cat/blackCat/idle/idel_4/",
	"res://assets/cat/blackCat/idle/idel_5/",
	"res://assets/cat/blackCat/idle/idel_6/",
]
const IDLE_COUNTS := [5, 4, 5, 4, 5]

const DRINK_DIR := "res://assets/cat/blackCat/drink/"
const WALK_DIR   := "res://assets/cat/blackCat/walk/"
const TIRED_DIR  := "res://assets/cat/blackCat/tired/"
const EAT_DIR    := "res://assets/cat/blackCat/eat/"
const CRY_DIR    := "res://assets/cat/blackCat/cry/"
const SLEEP_DIR  := "res://assets/cat/blackCat/sleep/"
const SOFULL_IMG := "res://assets/cat/blackCat/sofull/sofull_nobg.png"
const FRAME_COUNT := 4
const MOVE_SPEED  := 45.0

const HUNGER_DECAY      := 0.0015  # per second → full drain ~11 min
const HUNGER_EAT_GAIN   := 1.0     # restored per eat session
const THIRST_DECAY      := 0.0020  # per second → full drain ~8 min
const THIRST_DRINK_GAIN := 1.0     # restored per drink session
const ENERGY_DECAY      := 0.0008  # per second → full drain ~20 min
const ENERGY_SLEEP_GAIN := 0.003   # per second while sleeping

@export var bed_node       : Node2D = null
@export var food_bowl      : Node2D = null
@export var water_bowl     : Node2D = null
@export var standalone_anim: String = ""

@onready var sprite: AnimatedSprite2D = $Sprite

var _tween        : Tween
var _spawn_pos    : Vector2
var _target_pos   : Vector2
var _on_arrive    : Callable = Callable()
var _arrive_dist  : float    = 52.0
var _idle_timer   : float    = 0.0
var _current_state: int      = -1
var _move_dir     : Vector2  = Vector2.ZERO
var _wander_timer : float    = 0.0
var _is_eating    : bool     = false
var _is_drinking  : bool     = false
var _detour_dir         : Vector2  = Vector2.ZERO
var _detour_timer       : float    = 0.0
var _detour_count       : int      = 0
var _stuck_timer        : float    = 0.0
var _stuck_pos          : Vector2  = Vector2.ZERO
var _nav_to_bed         : bool     = false
var _cat_bump_cooldown  : float    = 0.0

# ── Hunger (0.0–1.0): depletes over time, restored by eating ──────────────────
# > 0.65  → active   < 0.3 → go eat
var hunger : float = 1.0

# ── Thirst (0.0–1.0): depletes over time, restored by drinking ────────────────
# < 0.3 → go drink
var thirst : float = 1.0

# ── Energy (0.0–1.0): depletes over time, restored by sleeping ────────────────
# < 0.3 → go sleep
var energy : float = 1.0

# ── Personality ───────────────────────────────────────────────────────────────
var _laziness    : float
var _playfulness : float
var _affection   : float
var _curiosity   : float

# ── Social ────────────────────────────────────────────────────────────────────
var _other_pets   : Array   = []
var _floor_center : Vector2 = Vector2.ZERO

# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_spawn_pos   = global_position
	_target_pos  = global_position
	_laziness    = randf()
	_playfulness = randf()
	_affection   = randf()
	_curiosity   = randf()
	_setup_frames()
	if standalone_anim != "":
		_play(standalone_anim)
		return
	if not GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.current_state)
	_idle_timer = randf_range(1.0, 3.0)

func _setup_frames() -> void:
	var frames := SpriteFrames.new()
	_add_anim(frames, "idle", IDLE_DIR, "idle", 6, 3.0)
	for i in range(IDLE_DIRS.size()):
		_add_anim(frames, "idle%d" % (i + 2), IDLE_DIRS[i], "idle", IDLE_COUNTS[i], 3.0, false)
	_add_anim(frames, "walk",     WALK_DIR,  "walk",  6,           8.0)
	_add_anim(frames, "tired",    TIRED_DIR, "tired", 6,           5.0, false)
	_add_anim(frames, "cry",      CRY_DIR,   "cry",   FRAME_COUNT, 4.0)
	_add_anim(frames, "sleeping", SLEEP_DIR, "sleep", FRAME_COUNT, 2.0)
	_add_anim_frames(frames, "eat_start",   EAT_DIR,   "eat",   [1,2,3,4],             3.0, false)
	_add_anim_frames(frames, "eat_loop",    EAT_DIR,   "eat",   [2,3,4],               3.0, true)
	_add_anim_frames(frames, "eat_end",     EAT_DIR,   "eat",   [5],                   2.0, false)
	_add_anim_frames(frames, "drink_start", DRINK_DIR, "drink", [1,2,3,4],          4.0, false)
	_add_anim_frames(frames, "drink_loop",  DRINK_DIR, "drink", [5,6,7],             4.0, true)
	_add_anim_frames(frames, "drink_end",   DRINK_DIR, "drink", [8],                 4.0, false)
	frames.add_animation("sofull")
	frames.set_animation_loop("sofull", false)
	frames.add_frame("sofull", load(SOFULL_IMG))
	sprite.sprite_frames = frames

func _add_anim(frames: SpriteFrames, anim: String, dir: String,
			   prefix: String, n: int, fps: float, loop: bool = true) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	for i: int in range(1, n + 1):
		frames.add_frame(anim, load(dir + prefix + "_%d.png" % i))

func _add_anim_frames(frames: SpriteFrames, anim: String, dir: String,
					  prefix: String, indices: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	for i in indices:
		frames.add_frame(anim, load(dir + prefix + "_%d.png" % i))

# ── Physics ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if standalone_anim != "": return
	_tick_stats(delta)
	_cat_bump_cooldown = maxf(_cat_bump_cooldown - delta, 0.0)
	# Urgent needs interrupt wandering immediately
	if not _on_arrive.is_valid() and not _is_eating and not _is_drinking:
		if hunger < 0.3 or thirst < 0.3 or energy < 0.3:
			_move_dir     = Vector2.ZERO
			_wander_timer = 0.0
			_idle_timer   = 0.0

	var speed_mult := lerpf(0.45, 1.0, clampf(hunger / 0.65, 0.0, 1.0))

	# ── Purposeful movement (eat, drink, sleep, follow) ──────────────────────
	if _on_arrive.is_valid():
		var diff := _target_pos - global_position
		if diff.length() < maxf(_arrive_dist, 2.0) or (_detour_timer <= 0.0 and diff.length() < _arrive_dist * 1.5) or _detour_count >= 3:
			velocity      = Vector2.ZERO
			_move_dir     = Vector2.ZERO
			_arrive_dist  = 52.0
			_detour_count = 0
			z_index = int(global_position.y)
			var cb := _on_arrive
			_on_arrive = Callable()
			cb.call()
		else:
			# Stuck detection: every 0.5s check if barely moved
			_stuck_timer -= delta
			if _stuck_timer <= 0.0:
				if global_position.distance_to(_stuck_pos) < 6.0 and _detour_timer <= 0.0:
					if _nav_to_bed and not _bed_is_free():
						_nav_to_bed = false
						_on_arrive  = Callable()
						_play("sofull")
						return
					# Close enough but blocked by another cat — just arrive
					if diff.length() < _arrive_dist * 2.0:
						velocity = Vector2.ZERO
						_move_dir = Vector2.ZERO
						_arrive_dist = 52.0
						z_index = int(global_position.y)
						var cb := _on_arrive
						_on_arrive = Callable()
						cb.call()
						return
					var perp := Vector2(-diff.y, diff.x).normalized() * (1.0 if randf() > 0.5 else -1.0)
					_detour_dir   = (diff.normalized() * 0.3 + perp).normalized()
					_detour_timer = randf_range(0.4, 0.8)
				_stuck_pos   = global_position
				_stuck_timer = 0.5

			if _detour_timer > 0.0:
				_detour_timer -= delta
				velocity = _detour_dir * MOVE_SPEED * speed_mult
			else:
				velocity = diff.normalized() * MOVE_SPEED * speed_mult

			move_and_slide()

			if get_slide_collision_count() > 0 and _detour_timer <= 0.0:
				if _nav_to_bed and not _bed_is_free():
					_nav_to_bed = false
					_on_arrive  = Callable()
					_play("sofull")
					return
				_detour_dir   = get_slide_collision(0).get_normal()
				_detour_timer = 1.0
				_detour_count += 1

			var move_ref := _detour_dir if _detour_timer > 0.0 else diff
			_set_move_anim(true)
			sprite.flip_h = move_ref.x < 0
			z_index = int(global_position.y)
		return

	# ── Free wander ───────────────────────────────────────────────────────────
	if _move_dir != Vector2.ZERO:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_move_dir = Vector2.ZERO
			velocity  = Vector2.ZERO
			z_index   = int(global_position.y)
			_play_random_idle()
			return

		velocity = _move_dir * MOVE_SPEED * speed_mult
		move_and_slide()

		if get_slide_collision_count() > 0 and _cat_bump_cooldown <= 0.0:
			_move_dir          = get_slide_collision(0).get_normal()
			_wander_timer      = 1.0
			_cat_bump_cooldown = 1.0

		_set_move_anim(true)
		sprite.flip_h = _move_dir.x < 0
		z_index = int(global_position.y)
		return

	# ── Idle ──────────────────────────────────────────────────────────────────
	velocity = Vector2.ZERO
	z_index = int(global_position.y)
	if _is_eating or _is_drinking: return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_do_natural_behavior()
		return
	var cur_anim: String = sprite.animation if sprite.sprite_frames else ""
	if cur_anim in ["sleeping", "sofull"]: return
	if cur_anim in ["idle", "idle2", "idle3", "idle4", "idle5", "idle6", "tired"]: return
	_set_move_anim(false)

# ── Energy ────────────────────────────────────────────────────────────────────

func _tick_stats(delta: float) -> void:
	var anim: String = sprite.animation if sprite.sprite_frames else ""
	if anim in ["sleeping", "sofull"]:
		energy = minf(energy + ENERGY_SLEEP_GAIN * delta, 1.0)
		if energy >= 0.95 and _current_state != PetStateMachine.State.SLEEPING:
			_start_wander(randf_range(1.0, 2.0))
	else:
		energy = maxf(energy - ENERGY_DECAY * delta, 0.0)
	hunger = maxf(hunger - HUNGER_DECAY * delta, 0.0)
	thirst = maxf(thirst - THIRST_DECAY * delta, 0.0)

func _food_bowl_has_food() -> bool:
	if not food_bowl: return false
	var v = food_bowl.get("has_food")
	return bool(v) if v != null else true

func _water_bowl_has_water() -> bool:
	if not water_bowl: return false
	var v = water_bowl.get("has_water")
	return bool(v) if v != null else true

# ── Natural behavior ──────────────────────────────────────────────────────────

func _do_natural_behavior() -> void:
	if _current_state == PetStateMachine.State.SLEEPING:
		_idle_timer = randf_range(4.0, 8.0)
		return

	var cur_anim: String = sprite.animation if sprite.sprite_frames else ""
	if cur_anim == "sleeping" and energy < 0.95:
		_idle_timer = randf_range(3.0, 6.0)
		return

	if energy < 0.3:
		_decide_sleep()
		return

	if thirst < 0.3:
		_decide_thirst()
		return

	if hunger > 0.65:
		_decide_active()
	elif hunger > 0.3:
		_decide_calm()
	else:
		_decide_hunger()

# High energy → lots of options
func _decide_active() -> void:
	var w := {}
	w["idle"]   = 0.3 + _laziness  * 0.2
	w["wander"] = 0.35 + _curiosity * 0.2

	var active_others := _other_pets.filter(func(p: Pet) -> bool:
		return p != self and p._current_state != PetStateMachine.State.SLEEPING)
	if not active_others.is_empty():
		w["follow"] = _affection * 0.2

	var sleeping_others := _other_pets.filter(func(p: Pet) -> bool:
		return p != self and p._current_state == PetStateMachine.State.SLEEPING)
	if not sleeping_others.is_empty():
		w["bother"] = _playfulness * 0.1

	match _weighted_pick(w):
		"idle":   _play_random_idle()
		"wander": _start_wander(randf_range(1.0, 2.0))
		"follow": _go_near_cat(active_others[randi() % active_others.size()])
		"bother": _bother_cat(sleeping_others[0])
		_:        _play_random_idle()

# Medium energy → calm, limited options
func _decide_calm() -> void:
	var w := {}
	w["idle"]   = 0.3 + _laziness  * 0.2
	w["wander"] = 0.3 + _curiosity * 0.1

	var active_others := _other_pets.filter(func(p: Pet) -> bool:
		return p != self and p._current_state != PetStateMachine.State.SLEEPING)
	if not active_others.is_empty():
		w["follow"] = _affection * 0.1

	match _weighted_pick(w):
		"idle":   _play_random_idle()
		"wander": _start_wander(randf_range(1.0, 2.0))
		"follow": _go_near_cat(active_others[randi() % active_others.size()])
		_:        _play_random_idle()

# Low thirst → drink
func _decide_thirst() -> void:
	if _water_bowl_has_water():
		water_bowl.set("collision_layer", 0)
		_move_to(water_bowl.global_position)
		_arrive_dist = 35.0
		_on_arrive = func(): water_bowl.start_drink(self)
	else:
		_play("tired")
		_idle_timer = randf_range(3.0, 6.0)

# Low hunger → eat
func _decide_hunger() -> void:
	if _food_bowl_has_food():
		food_bowl.set("collision_layer", 0)
		_move_to(food_bowl.global_position)
		_arrive_dist = 35.0
		_on_arrive = func(): food_bowl.start_feed(self)
	else:
		_play("tired")
		_idle_timer = randf_range(3.0, 6.0)

# Low energy → sleep
func _decide_sleep() -> void:
	if bed_node and _bed_is_free():
		_go_to_bed()
	else:
		_play("sofull")

func _bed_is_free() -> bool:
	if not bed_node: return false
	var sleep_spot := bed_node.get_node_or_null("SleepSpot") as Node2D
	var dest := sleep_spot.global_position if sleep_spot else bed_node.global_position
	for p in _other_pets:
		if not is_instance_valid(p): continue
		var other := p as Pet
		if other == null: continue
		if other.global_position.distance_to(dest) < 40.0:
			var anim: String = other.sprite.animation if other.sprite.sprite_frames else ""
			if anim in ["sleeping", "sofull"]:
				return false
	return true

# ── Action helpers ────────────────────────────────────────────────────────────

func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for v in weights.values(): total += v
	if total <= 0.0: return weights.keys()[0]
	var r := randf() * total
	var cum := 0.0
	for key in weights:
		cum += weights[key]
		if r <= cum: return key
	return weights.keys()[-1]

func _start_wander(duration: float) -> void:
	var random_dir := Vector2(cos(randf() * TAU), sin(randf() * TAU))
	var to_center  := _floor_center - global_position
	var center_dir := to_center.normalized() if to_center.length() > 20.0 else random_dir
	_move_dir     = (random_dir * 0.8 + center_dir * 0.2).normalized()
	_wander_timer = duration

func _go_near_cat(other: Pet) -> void:
	var offset := Vector2(randf_range(-35.0, 35.0), randf_range(-15.0, 15.0))
	_move_to(other.global_position + offset, randf_range(3.0, 8.0))

func _bother_cat(other: Pet) -> void:
	var offset := Vector2(randf_range(-20.0, 20.0), 0.0)
	_move_to(other.global_position + offset, randf_range(2.0, 4.0))

func _move_to(world_pos: Vector2, wait_after: float = 0.0) -> void:
	_target_pos   = world_pos
	_move_dir     = Vector2.ZERO
	_detour_timer = 0.0
	_detour_count = 0
	_stuck_timer  = 0.5
	_stuck_pos    = global_position
	if wait_after > 0.0:
		_on_arrive = func(): _idle_timer = wait_after

# ── State handling ────────────────────────────────────────────────────────────

func _on_state_changed(new_state: int) -> void:
	_current_state = new_state
	var anim: String = sprite.animation if sprite.sprite_frames else ""
	if anim in ["eat_start", "eat_loop", "eat_end", "drink_start", "drink_loop", "drink_end", "sleeping", "sofull"]:
		return
	if _on_arrive.is_valid():
		return
	_kill_tween()
	_on_arrive = Callable()
	match new_state:
		PetStateMachine.State.IDLE, PetStateMachine.State.HAPPY:
			_play("idle")
			_idle_timer = randf_range(1.0, 3.0)
		PetStateMachine.State.TIRED:
			_play("tired")
			_idle_timer = randf_range(1.0, 2.0)
		PetStateMachine.State.HUNGRY:
			_idle_timer = randf_range(1.0, 2.0)
		PetStateMachine.State.SLEEPING:
			_go_to_bed()

# ── Bed ───────────────────────────────────────────────────────────────────────

func _go_to_bed() -> void:
	if bed_node:
		var sleep_spot := bed_node.get_node_or_null("SleepSpot") as Node2D
		var dest       := sleep_spot.global_position if sleep_spot else bed_node.global_position
		_move_to(dest)
		_arrive_dist = 0.0
		_nav_to_bed  = true
		_on_arrive   = func():
			_nav_to_bed = false
			_play("sleeping")
	else:
		_play("sleeping")

# ── Eat ───────────────────────────────────────────────────────────────────────

func eat() -> void:
	_is_eating = true
	_play("eat_start")
	if not sprite.animation_finished.is_connected(_on_eat_start_done):
		sprite.animation_finished.connect(_on_eat_start_done)

func _on_eat_start_done() -> void:
	if sprite.animation == "eat_start":
		sprite.animation_finished.disconnect(_on_eat_start_done)
		_play("eat_loop")

func stop_eat() -> void:
	if sprite.animation_finished.is_connected(_on_eat_start_done):
		sprite.animation_finished.disconnect(_on_eat_start_done)
	hunger = minf(hunger + HUNGER_EAT_GAIN, 1.0)
	_play("eat_end")
	if not sprite.animation_finished.is_connected(_on_eat_end_done):
		sprite.animation_finished.connect(_on_eat_end_done)

func _on_eat_end_done() -> void:
	if sprite.animation != "eat_end": return
	sprite.animation_finished.disconnect(_on_eat_end_done)
	_is_eating = false
	_start_wander(randf_range(1.0, 2.0))

# ── Drink ─────────────────────────────────────────────────────────────────────

func drink() -> void:
	_is_drinking = true
	_play("drink_start")
	if not sprite.animation_finished.is_connected(_on_drink_start_done):
		sprite.animation_finished.connect(_on_drink_start_done)

func _on_drink_start_done() -> void:
	if sprite.animation == "drink_start":
		sprite.animation_finished.disconnect(_on_drink_start_done)
		_play("drink_loop")

func stop_drink() -> void:
	if sprite.animation_finished.is_connected(_on_drink_start_done):
		sprite.animation_finished.disconnect(_on_drink_start_done)
	_play("drink_end")
	if not sprite.animation_finished.is_connected(_on_drink_end_done):
		sprite.animation_finished.connect(_on_drink_end_done)

func _on_drink_end_done() -> void:
	if sprite.animation != "drink_end": return
	sprite.animation_finished.disconnect(_on_drink_end_done)
	_is_drinking = false
	_start_wander(randf_range(1.0, 2.0))

# ── Random idle ───────────────────────────────────────────────────────────────

func _play_random_idle(exclude: String = "") -> void:
	var anims := ["idle2", "idle3", "idle4", "idle5", "idle6"]
	if exclude != "":
		anims = anims.filter(func(a): return a != exclude)
	_play(anims[randi() % anims.size()])
	_idle_timer = randf_range(4.0, 8.0)
	if not sprite.animation_finished.is_connected(_on_idle_anim_done):
		sprite.animation_finished.connect(_on_idle_anim_done)

func _on_idle_anim_done() -> void:
	var finished := sprite.animation
	if finished not in ["idle2", "idle3", "idle4", "idle5", "idle6"]: return
	sprite.animation_finished.disconnect(_on_idle_anim_done)
	var prev := finished
	get_tree().create_timer(0.3).timeout.connect(func():
		_idle_timer = 0.0)

# ── Animations ────────────────────────────────────────────────────────────────

const _BASE_SCALE := 0.28

func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.scale = Vector2(_BASE_SCALE, _BASE_SCALE)

func _set_move_anim(moving: bool) -> void:
	_play("walk" if moving else _current_idle_anim())

func _current_idle_anim() -> String:
	if _current_state == PetStateMachine.State.SLEEPING: return "sleeping"
	if hunger < 0.3: return "tired"
	return "idle"

func _jump() -> void:
	_tween = create_tween()
	for _i: int in 3:
		_tween.tween_property(sprite, "scale:y", _BASE_SCALE * 0.65, 0.14).set_ease(Tween.EASE_OUT)
		_tween.tween_property(sprite, "scale:y", _BASE_SCALE,         0.14).set_ease(Tween.EASE_IN)

func force_anim(anim: String) -> void:
	standalone_anim = anim
	if anim == "":
		_on_state_changed(GameManager.current_state)
	else:
		_play(anim)

func place_at(world_pos: Vector2) -> void:
	position    = world_pos
	_spawn_pos  = world_pos
	_target_pos = world_pos

func _kill_tween() -> void:
	if _tween and _tween.is_valid(): _tween.kill()
	sprite.scale = Vector2(_BASE_SCALE, _BASE_SCALE)
