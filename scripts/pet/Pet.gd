extends CharacterBody2D
class_name Pet

const IDLE2_SHEET  := "res://assets/cat/sheets/idle2_sheet.png"
const IDLE3_SHEET  := "res://assets/cat/sheets/idle3_sheet.png"
const IDLE4_SHEET  := "res://assets/cat/sheets/idle4_sheet.png"
const IDLE6_SHEET  := "res://assets/cat/sheets/idle6_sheet.png"
const TIRED_SHEET  := "res://assets/cat/sheets/tired_sheet.png"

const DRINK_DIR := "res://assets/cat/drink/"
const WALK_SIDE_SHEET := "res://assets/cat/sheets/walk_side_sheet.png"
const WALK_DOWN_SHEET := "res://assets/cat/sheets/walk_down_sheet.png"
const WALK_UP_SHEET   := "res://assets/cat/sheets/walk_up_sheet.png"
const EAT_SHEET   := "res://assets/cat/sheets/eat_sheet.png"
const SLEEP_SHEET := "res://assets/cat/sheets/sleep_sheet.png"
const FRAME_COUNT  := 4
const MOVE_SPEED   := 45.0
const ARRIVE_DIST  := 5.0
const ACCELERATION := 400.0
const FRICTION     := 500.0

const HUNGER_DECAY      := 0.0015
const HUNGER_EAT_GAIN   := 1.0
const THIRST_DECAY      := 0.0020
const THIRST_DRINK_GAIN := 1.0
const ENERGY_DECAY      := 0.0008
const ENERGY_SLEEP_GAIN := 0.003

# ── Tunable game-balance constants ────────────────────────────────────────────
const URGENCY_THRESHOLD       := 0.3   # hunger/thirst/energy below this → behave urgently
const ENERGY_FULL_THRESHOLD   := 0.95  # energy level that ends sleep
const WANDER_AFTER_ACTION_MIN := 1.0   # min wander duration after eat/drink/sleep finish
const WANDER_AFTER_ACTION_MAX := 2.0   # max wander duration after eat/drink/sleep finish
const IDLE_RANDOM_NEXT_DELAY  := 0.3   # pause before next behavior after idle_random
const BEHAVIOR_COOLDOWN_RESET := 3.0   # rate-limit on urgent idle→behavior triggers
const NAV_TIMEOUT_BOWL        := 10.0  # give up navigating to bowl after this many seconds
const NAV_TIMEOUT_BED         := 15.0  # give up navigating to bed after this many seconds
const COLLISION_RESTORE_DELAY := 2.0   # delay before re-enabling item collision after action
const VEL_IDLE_THRESHOLD_SQ   := 25.0  # velocity² above this = "still moving" (5 px/s)
const ARRIVE_DIST_DEFAULT     := 52.0  # relaxed arrive radius reset after purposeful nav

# Trạng thái animation nội bộ — dùng để quản lý chuỗi chuyển anim tập trung
enum AnimState {
	IDLE, IDLE_RANDOM, WALK,
	EAT_START, EAT_LOOP, EAT_END,
	DRINK_START, DRINK_LOOP, DRINK_END,
	SLEEP_PREPARE, SLEEPING, SLEEP_DONE,
}

@export var bed_node       : Node2D = null
@export var food_bowl      : Node2D = null
@export var water_bowl     : Node2D = null
@export var standalone_anim: String = ""
@export var cat_name       : String = "Cat"
@export var cat_style      : Dictionary = {}
@export var debug_log      : bool   = false

signal clicked(pet: Pet)

@onready var sprite         : AnimatedSprite2D = $Sprite
@onready var _shadow_sprite : AnimatedSprite2D = $ShadowSprite

var _anim_state       : AnimState = AnimState.IDLE
var _idle_random_anim : String    = "idle3"

var _tween        : Tween
var _spawn_pos    : Vector2
var _target_pos   : Vector2
var _on_arrive    : Callable = Callable()
var _arrive_dist  : float    = 52.0
var _current_state: int      = -1
var _move_dir     : Vector2  = Vector2.ZERO
var _wander_timer : float    = 0.0
var _detour_dir         : Vector2  = Vector2.ZERO
var _detour_timer       : float    = 0.0
var _detour_count       : int      = 0
var _stuck_timer        : float    = 0.0
var _stuck_pos          : Vector2  = Vector2.ZERO
var _nav_target              : String   = ""     # "bowl" | "water" | "bed" | ""
var _interaction_timeout     : float   = 0.0
var _cat_bump_cooldown       : float   = 0.0
var _behavior_cooldown       : float   = 0.0
var _bed_collision_disabled  : bool    = false
var _last_idle_name          : String  = ""

var hunger : float = 1.0
var thirst : float = 1.0
var energy : float = 1.0

var _laziness    : float
var _playfulness : float
var _shadow_mat : ShaderMaterial = null
var _affection   : float
var _curiosity   : float

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
	# Một kết nối duy nhất cho animation_finished — không connect/disconnect thủ công
	sprite.animation_finished.connect(_on_animation_finished)
	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.current_state)
	if standalone_anim != "":
		_play(standalone_anim)
		return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = get_global_transform().affine_inverse() * event.global_position
		if local.length() < 40.0:
			clicked.emit(self)
			get_viewport().set_input_as_handled()

func _setup_frames() -> void:
	var frames := SpriteFrames.new()
	_add_anim_sheet(frames, "idle",  TIRED_SHEET, 6, 1, 6, 3.0, false)
	_add_anim_sheet(frames, "idle3", IDLE3_SHEET, 4, 1, 4, 3.0, false)
	_add_anim_sheet(frames, "idle4", IDLE4_SHEET, 5, 1, 5, 3.0, false)
	_add_anim_sheet(frames, "idle6", IDLE6_SHEET, 5, 1, 5, 3.0, false)
	_add_anim_sheet(frames, "walk_side", WALK_SIDE_SHEET, 4, 2, 6, 6.0)
	_add_anim_sheet(frames, "walk_down", WALK_DOWN_SHEET, 8, 1, 7, 6.0, true, [2, 5])
	_add_anim_sheet(frames, "walk_up",   WALK_UP_SHEET,   11, 1, 11, 10.0, true)
	_add_anim_sheet_range(frames, "eat_start", EAT_SHEET, 3, 3, 0, 3, 3.0, false)
	_add_anim_sheet_range(frames, "eat_loop",  EAT_SHEET, 3, 3, 3, 6, 3.0, true)
	_add_anim_sheet_range(frames, "eat_end",   EAT_SHEET, 3, 3, 6, 8, 2.0, false)
	_add_anim_sheet_range(frames, "drink_start", EAT_SHEET, 3, 3, 0, 3, 3.0, false)
	_add_anim_sheet_range(frames, "drink_loop",  EAT_SHEET, 3, 3, 3, 6, 3.0, true)
	_add_anim_sheet_range(frames, "drink_end",   EAT_SHEET, 3, 3, 6, 8, 2.0, false)
	_add_anim_sheet_range(frames, "sleep_prepare", SLEEP_SHEET, 3, 3, 0, 3, 3.0, false)
	_add_anim_sheet_range(frames, "sleeping",      SLEEP_SHEET, 3, 3, 3, 5, 2.0, true)
	_add_anim_sheet_range(frames, "sleep_done",    SLEEP_SHEET, 3, 3, 6, 9, 3.0, false)
	sprite.sprite_frames         = frames
	_shadow_sprite.sprite_frames = frames
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = load("res://shaders/pet_shadow.gdshader")
	_shadow_sprite.material = shadow_mat
	_shadow_mat             = shadow_mat

	if not cat_style.is_empty():
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/cat_style.gdshader")
		mat.set_shader_parameter("hue_shift",       float(cat_style.get("hue_shift",   0.0)))
		mat.set_shader_parameter("saturation_mult", float(cat_style.get("saturation",  1.0)))
		mat.set_shader_parameter("value_mult",      float(cat_style.get("value",       1.0)))
		sprite.material = mat

func _add_anim_sheet(frames: SpriteFrames, anim: String, path: String,
					  hf: int, vf: int, n: int, fps: float, loop: bool = true, skip: Array = []) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	var tex: Texture2D = load(path)
	var cw := float(tex.get_width())  / hf
	var ch := float(tex.get_height()) / vf
	for i in range(n):
		if i in skip: continue
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2((i % hf) * cw, (i / hf) * ch, cw, ch)
		frames.add_frame(anim, atlas)

func _add_anim_sheet_range(frames: SpriteFrames, anim: String, path: String,
						   hf: int, vf: int, from_i: int, to_i: int,
						   fps: float, loop: bool = true) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	var tex: Texture2D = load(path)
	var cw := float(tex.get_width())  / hf
	var ch := float(tex.get_height()) / vf
	for i in range(from_i, to_i):
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2((i % hf) * cw, (i / hf) * ch, cw, ch)
		frames.add_frame(anim, atlas)

func _add_anim(frames: SpriteFrames, anim: String, dir: String,
			   prefix: String, n: int, fps: float, loop: bool = true) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	for i: int in range(1, n + 1):
		frames.add_frame(anim, load(dir + prefix + "_%d.png" % i))

# ── Animation State Machine ───────────────────────────────────────────────────

func _change_anim_state(new_state: AnimState) -> void:
	if debug_log and new_state != _anim_state:
		print("[%s] State: %s → %s" % [cat_name, AnimState.keys()[_anim_state], AnimState.keys()[new_state]])
	_anim_state = new_state
	match new_state:
		AnimState.IDLE:          _play("idle")
		AnimState.IDLE_RANDOM:   _play(_idle_random_anim)
		AnimState.EAT_START:     _play("eat_start")
		AnimState.EAT_LOOP:      _play("eat_loop")
		AnimState.EAT_END:       _play("eat_end")
		AnimState.DRINK_START:   _play("drink_start")
		AnimState.DRINK_LOOP:    _play("drink_loop")
		AnimState.DRINK_END:     _play("drink_end")
		AnimState.SLEEP_PREPARE: _play("sleep_prepare")
		AnimState.SLEEPING:      _play("sleeping")
		AnimState.SLEEP_DONE:    _play("sleep_done")
		# WALK không xử lý ở đây — _set_move_anim chọn walk_side/down/up trực tiếp

func _on_animation_finished() -> void:
	if standalone_anim != "": return
	match _anim_state:
		AnimState.IDLE:
			_do_natural_behavior()
		AnimState.IDLE_RANDOM:
			get_tree().create_timer(IDLE_RANDOM_NEXT_DELAY).timeout.connect(func(): _do_natural_behavior())
		AnimState.EAT_START:
			_change_anim_state(AnimState.EAT_LOOP)
		AnimState.EAT_END:
			_start_wander(randf_range(WANDER_AFTER_ACTION_MIN, WANDER_AFTER_ACTION_MAX))
		AnimState.DRINK_START:
			_change_anim_state(AnimState.DRINK_LOOP)
		AnimState.DRINK_END:
			_start_wander(randf_range(WANDER_AFTER_ACTION_MIN, WANDER_AFTER_ACTION_MAX))
		AnimState.SLEEP_PREPARE:
			_change_anim_state(AnimState.SLEEPING)
		AnimState.SLEEP_DONE:
			_start_wander(randf_range(WANDER_AFTER_ACTION_MIN, WANDER_AFTER_ACTION_MAX))
			if _bed_collision_disabled and bed_node:
				_bed_collision_disabled = false
				var b := bed_node
				get_tree().create_timer(COLLISION_RESTORE_DELAY).timeout.connect(func():
					if is_instance_valid(b): b.set("collision_layer", 1))

# ── Physics ───────────────────────────────────────────────────────────────────

# Nếu IDLE/IDLE_RANDOM đang play nhưng velocity vẫn đáng kể (bị đẩy bởi physics),
# ép ngay sang walk animation để tránh trạng thái "đứng yên nhưng đang trượt".
func _sync_state_to_velocity() -> void:
	if _anim_state not in [AnimState.IDLE, AnimState.IDLE_RANDOM]: return
	if velocity.length_squared() > VEL_IDLE_THRESHOLD_SQ:
		if debug_log:
			print("[%s] sync_velocity: forced IDLE → WALK (vel=%.1f)" % [cat_name, velocity.length()])
		_set_move_anim(true)

func _update_shadow() -> void:
	if not _shadow_mat: return

	var blended_dir  := Vector2.ZERO
	var blended_len  := 0.0
	var total_weight := 0.0
	var radius       := 600.0

	for lamp in WallLamp.all_lamps:
		var l := lamp as WallLamp
		if not l.is_on: continue
		var to_entity := global_position - l.global_position
		var dist      := to_entity.length()
		if dist > radius: continue

		var weight  := 1.0 - dist / radius
		var dx      := to_entity.x
		var iso     := Vector2(dx, abs(dx) * 0.5)
		var iso_dir := iso.normalized() if iso.length_squared() > 1.0 else Vector2(0.0, 1.0)
		blended_dir  += iso_dir * weight
		blended_len  += clampf(dist * 0.25, 40.0, 100.0) * weight
		total_weight += weight

	if total_weight > 0.01:
		var final_dir : Vector2
		if blended_dir.length_squared() > 0.001:
			final_dir = blended_dir.normalized()
		else:
			final_dir = Vector2(0.0, 1.0)
		_shadow_mat.set_shader_parameter("light_dir",     final_dir)
		_shadow_mat.set_shader_parameter("shadow_length", blended_len / total_weight)
		_shadow_mat.set_shader_parameter("shadow_alpha",  0.35)
	else:
		_shadow_mat.set_shader_parameter("light_dir",     Vector2(-0.894, 0.447))
		_shadow_mat.set_shader_parameter("shadow_length", 60.0)
		_shadow_mat.set_shader_parameter("shadow_alpha",  0.18)

func _physics_process(delta: float) -> void:
	if standalone_anim != "": return
	_update_shadow()
	_tick_stats(delta)
	_cat_bump_cooldown = maxf(_cat_bump_cooldown - delta, 0.0)
	_behavior_cooldown = maxf(_behavior_cooldown - delta, 0.0)
	_sync_state_to_velocity()

	# Timeout: mèo bỏ cuộc nếu không tới được mục tiêu sau N giây
	if _nav_target != "" and _on_arrive.is_valid():
		_interaction_timeout -= delta
		if _interaction_timeout <= 0.0:
			print("[Pet] gave up navigating to: ", _nav_target)
			if _nav_target == "bed" and bed_node:
				bed_node.set("collision_layer", 1)
				_bed_collision_disabled = false
			elif _nav_target == "bowl" and food_bowl:
				food_bowl.set("collision_layer", 1)
			elif _nav_target == "water" and water_bowl:
				water_bowl.set("collision_layer", 1)
			_nav_target  = ""
			_on_arrive   = Callable()
			velocity     = Vector2.ZERO
			_move_dir    = Vector2.ZERO
			_do_natural_behavior()
			return

	# Interrupt khi có nhu cầu cấp bách (không làm gián đoạn hành động đang dở)
	if not _on_arrive.is_valid() and not PetStateMachine.is_busy(_anim_state):
		var urgent := hunger < URGENCY_THRESHOLD or thirst < URGENCY_THRESHOLD or energy < URGENCY_THRESHOLD
		if urgent:
			if _move_dir != Vector2.ZERO:
				# Đang wander → dừng ngay, để friction coast xong rồi idle gọi _do_natural_behavior
				_move_dir     = Vector2.ZERO
				_wander_timer = 0.0
				velocity      = Vector2.ZERO
			elif _anim_state in [AnimState.IDLE, AnimState.IDLE_RANDOM] and _behavior_cooldown <= 0.0:
				# Đang idle → react ngay không chờ animation kết thúc
				_behavior_cooldown = BEHAVIOR_COOLDOWN_RESET
				_do_natural_behavior()

	var speed_mult := lerpf(0.45, 1.0, clampf(hunger / 0.65, 0.0, 1.0))

	# ── Purposeful movement ───────────────────────────────────────────────────
	if _on_arrive.is_valid():
		var diff := _target_pos - global_position
		if diff.length() < maxf(_arrive_dist, 2.0) or (_detour_timer <= 0.0 and diff.length() < _arrive_dist * 1.5) or _detour_count >= 3:
			velocity      = Vector2.ZERO
			_move_dir     = Vector2.ZERO
			_arrive_dist  = ARRIVE_DIST_DEFAULT
			_detour_count = 0
			z_index = int(global_position.y)
			var cb := _on_arrive
			_on_arrive  = Callable()
			_nav_target = ""
			cb.call()
		else:
			_stuck_timer -= delta
			if _stuck_timer <= 0.0:
				if global_position.distance_to(_stuck_pos) < 6.0 and _detour_timer <= 0.0:
					if _nav_target == "bed" and not _bed_is_free():
						_nav_target = ""
						_on_arrive  = Callable()
						if bed_node and _bed_collision_disabled:
							bed_node.set("collision_layer", 1)
							_bed_collision_disabled = false
						_change_anim_state(AnimState.SLEEP_PREPARE)
						return
					if diff.length() < _arrive_dist * 2.0:
						velocity = Vector2.ZERO
						_move_dir = Vector2.ZERO
						_arrive_dist = 52.0
						z_index = int(global_position.y)
						var cb := _on_arrive
						_on_arrive  = Callable()
						_nav_target = ""
						cb.call()
						return
					var perp := Vector2(-diff.y, diff.x).normalized() * (1.0 if randf() > 0.5 else -1.0)
					_detour_dir   = (diff.normalized() * 0.3 + perp).normalized()
					_detour_timer = randf_range(0.4, 0.8)
				_stuck_pos   = global_position
				_stuck_timer = 0.5

			var target_vel : Vector2
			if _detour_timer > 0.0:
				_detour_timer -= delta
				target_vel = _detour_dir * MOVE_SPEED * speed_mult
			else:
				target_vel = diff.normalized() * MOVE_SPEED * speed_mult

			velocity = velocity.move_toward(target_vel, ACCELERATION * delta)
			move_and_slide()

			if get_slide_collision_count() > 0 and _detour_timer <= 0.0:
				if _nav_target == "bed" and not _bed_is_free():
					if bed_node and _bed_collision_disabled:
						bed_node.set("collision_layer", 1)
						_bed_collision_disabled = false
					_nav_target = ""
					_on_arrive  = Callable()
					_change_anim_state(AnimState.SLEEP_PREPARE)
					return
				_detour_dir   = get_slide_collision(0).get_normal()
				_detour_timer = 1.0
				_detour_count += 1

			_set_move_anim(true)
			z_index = int(global_position.y)
		return

	# ── Free wander ───────────────────────────────────────────────────────────
	if _move_dir != Vector2.ZERO:
		_wander_timer -= delta
		if _wander_timer > 0.0:
			var target_vel := _move_dir * MOVE_SPEED * speed_mult
			velocity = velocity.move_toward(target_vel, ACCELERATION * delta)
			move_and_slide()

			if get_slide_collision_count() > 0 and _cat_bump_cooldown <= 0.0:
				_move_dir          = get_slide_collision(0).get_normal()
				_wander_timer      = 1.0
				_cat_bump_cooldown = 1.0

			_set_move_anim(true)
			z_index = int(global_position.y)
			return
		# Timer hết: xoá hướng đi, để fall-through xuống idle (friction xử lý decel)
		_move_dir = Vector2.ZERO

	# ── Idle (kể cả friction coast sau khi wander dừng) ──────────────────────
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	z_index = int(global_position.y)

	if velocity.length_squared() > VEL_IDLE_THRESHOLD_SQ: return  # đang trượt dần, chưa đổi anim

	if _anim_state in [
		AnimState.EAT_START, AnimState.EAT_LOOP, AnimState.EAT_END,
		AnimState.DRINK_START, AnimState.DRINK_LOOP, AnimState.DRINK_END,
		AnimState.SLEEP_PREPARE, AnimState.SLEEPING, AnimState.SLEEP_DONE,
	]: return
	if _anim_state in [AnimState.IDLE, AnimState.IDLE_RANDOM]: return
	_change_anim_state(AnimState.IDLE)

# ── Stats ─────────────────────────────────────────────────────────────────────

func _tick_stats(delta: float) -> void:
	if _anim_state == AnimState.SLEEPING:
		energy = minf(energy + ENERGY_SLEEP_GAIN * delta, 1.0)
		if energy >= ENERGY_FULL_THRESHOLD:
			_change_anim_state(AnimState.SLEEP_DONE)
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
	if _current_state == PetStateMachine.State.SLEEPING: return
	if _anim_state == AnimState.SLEEPING and energy < ENERGY_FULL_THRESHOLD: return
	# EAT/DRINK loop không gọi hàm này nên không cần guard is_busy ở đây

	# Priority queue: ăn → uống → ngủ → hành vi bình thường
	if hunger < URGENCY_THRESHOLD:
		_decide_hunger()
		return
	if thirst < URGENCY_THRESHOLD:
		_decide_thirst()
		return
	if energy < URGENCY_THRESHOLD:
		_decide_sleep()
		return

	if hunger > 0.65:
		_decide_active()
	else:
		_decide_calm()

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

func _bowl_arrive_pos(bowl: Node2D) -> Vector2:
	var spot := bowl.get_node_or_null("ArriveSpot") as Node2D
	return spot.global_position if spot else bowl.global_position

func _decide_thirst() -> void:
	if _water_bowl_has_water():
		water_bowl.set("collision_layer", 0)
		_move_to(_bowl_arrive_pos(water_bowl))
		_arrive_dist         = ARRIVE_DIST
		_nav_target          = "water"
		_interaction_timeout = NAV_TIMEOUT_BOWL
		_on_arrive = func():
			_nav_target = ""
			if not _water_bowl_has_water():
				water_bowl.set("collision_layer", 1)
				_do_natural_behavior()
				return
			water_bowl.start_drink(self)
	else:
		_play_idle()

func _decide_hunger() -> void:
	if _food_bowl_has_food():
		food_bowl.set("collision_layer", 0)
		_move_to(_bowl_arrive_pos(food_bowl))
		_arrive_dist         = ARRIVE_DIST
		_nav_target          = "bowl"
		_interaction_timeout = NAV_TIMEOUT_BOWL
		_on_arrive = func():
			_nav_target = ""
			if not _food_bowl_has_food():
				food_bowl.set("collision_layer", 1)
				_do_natural_behavior()
				return
			food_bowl.start_feed(self)
	else:
		_play_idle()

func _decide_sleep() -> void:
	if bed_node and _bed_is_free():
		_go_to_bed()
	else:
		_change_anim_state(AnimState.SLEEP_PREPARE)

func _bed_is_free() -> bool:
	if not bed_node: return false
	var sleep_spot := bed_node.get_node_or_null("SleepSpot") as Node2D
	var dest := sleep_spot.global_position if sleep_spot else bed_node.global_position
	for p in _other_pets:
		if not is_instance_valid(p): continue
		var other := p as Pet
		if other == null: continue
		if other._nav_target == "bed" and other.bed_node == bed_node:
			return false
		if other.global_position.distance_to(dest) < 40.0:
			if other._anim_state in [AnimState.SLEEPING, AnimState.SLEEP_PREPARE]:
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
		_on_arrive = func(): get_tree().create_timer(wait_after).timeout.connect(
			func(): _do_natural_behavior())

# ── State handling ────────────────────────────────────────────────────────────

func _on_state_changed(new_state: int) -> void:
	_current_state = new_state
	if _anim_state in [
		AnimState.EAT_START, AnimState.EAT_LOOP, AnimState.EAT_END,
		AnimState.DRINK_START, AnimState.DRINK_LOOP, AnimState.DRINK_END,
		AnimState.SLEEPING, AnimState.SLEEP_PREPARE
	]: return
	if _on_arrive.is_valid() or _move_dir != Vector2.ZERO:
		return
	_kill_tween()
	_on_arrive = Callable()
	match new_state:
		PetStateMachine.State.IDLE, PetStateMachine.State.HAPPY, \
		PetStateMachine.State.TIRED, PetStateMachine.State.HUNGRY:
			_play_idle()
		PetStateMachine.State.SLEEPING:
			_go_to_bed()

# ── Bed ───────────────────────────────────────────────────────────────────────

func _go_to_bed() -> void:
	if bed_node:
		var sleep_spot := bed_node.get_node_or_null("SleepSpot") as Node2D
		var dest       := sleep_spot.global_position if sleep_spot else bed_node.global_position
		bed_node.set("collision_layer", 0)
		_bed_collision_disabled = true
		_move_to(dest)
		_arrive_dist         = ARRIVE_DIST
		_nav_target          = "bed"
		_interaction_timeout = NAV_TIMEOUT_BED
		_on_arrive = func():
			_nav_target = ""
			_change_anim_state(AnimState.SLEEP_PREPARE)
	else:
		_change_anim_state(AnimState.SLEEP_PREPARE)

# ── Eat ───────────────────────────────────────────────────────────────────────

func eat() -> void:
	_change_anim_state(AnimState.EAT_START)

func on_eat_completed() -> void:
	hunger = minf(hunger + HUNGER_EAT_GAIN, 1.0)
	_change_anim_state(AnimState.EAT_END)

# ── Drink ─────────────────────────────────────────────────────────────────────

func drink() -> void:
	_change_anim_state(AnimState.DRINK_START)

func on_drink_completed() -> void:
	thirst = minf(thirst + THIRST_DRINK_GAIN, 1.0)
	_change_anim_state(AnimState.DRINK_END)

# ── Idle animations ───────────────────────────────────────────────────────────

func _play_idle() -> void:
	if _on_arrive.is_valid() or _move_dir != Vector2.ZERO: return
	_change_anim_state(AnimState.IDLE)

func _play_random_idle() -> void:
	if _on_arrive.is_valid() or _move_dir != Vector2.ZERO: return
	var anims := ["idle3", "idle4", "idle6"]
	if _last_idle_name != "":
		var filtered := anims.filter(func(a: String) -> bool: return a != _last_idle_name)
		if not filtered.is_empty(): anims = filtered
	_idle_random_anim = anims[randi() % anims.size()]
	_last_idle_name   = _idle_random_anim
	sprite.stop()
	_shadow_sprite.stop()
	_change_anim_state(AnimState.IDLE_RANDOM)

# ── Animations ────────────────────────────────────────────────────────────────

const _BASE_SCALE := 0.28

func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.scale = Vector2(_BASE_SCALE, _BASE_SCALE)
	if _shadow_sprite.animation != anim:
		_shadow_sprite.play(anim)
	_shadow_sprite.scale = sprite.scale

func _set_move_anim(moving: bool) -> void:
	if not moving:
		_play(_current_idle_anim())
		return
	_anim_state = AnimState.WALK
	var vel := velocity
	if abs(vel.y) > abs(vel.x):
		_play("walk_down" if vel.y > 0 else "walk_up")
		sprite.flip_h = false
	else:
		_play("walk_side")
		sprite.flip_h = vel.x < 0

func _current_idle_anim() -> String:
	if _current_state == PetStateMachine.State.SLEEPING: return "sleeping"
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
	sprite.scale          = Vector2(_BASE_SCALE, _BASE_SCALE)
	_shadow_sprite.scale  = sprite.scale
