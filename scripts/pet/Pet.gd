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

# Trạng thái animation nội bộ — dùng để quản lý chuỗi chuyển anim tập trung
enum AnimState {
	IDLE, IDLE_RANDOM, WALK,
	EAT_START, EAT_LOOP, EAT_END,
	DRINK_START, DRINK_LOOP, DRINK_END,
	SLEEP_PREPARE, SLEEPING, SLEEP_DONE,
}

@export var bed_node       : Node2D    = null
@export var food_bowl      : Node2D    = null
@export var water_bowl     : Node2D    = null
@export var standalone_anim: String    = ""
@export var cat_name       : String    = "Cat"
@export var cat_style      : Dictionary = {}
@export var debug_log      : bool      = false
## Config chứa toàn bộ hằng số game-balance. Tạo .tres trong Inspector và gán vào đây.
@export var config         : PetConfig = null
## Thêm behavior tùy chỉnh (ScratchPostBehavior, ToyBehavior…) không cần sửa Pet.gd
@export var extra_behaviors: Array[PetBehavior] = []

signal clicked(pet: Pet)

@onready var sprite         : AnimatedSprite2D = $Sprite
@onready var _shadow_sprite : AnimatedSprite2D = $ShadowSprite

var _anim_state       : AnimState = AnimState.IDLE
var _idle_random_anim : String    = "idle3"

var _tween        : Tween
var _spawn_pos    : Vector2
var _current_state: int      = -1
var _move_dir     : Vector2  = Vector2.ZERO
var _wander_timer : float    = 0.0
var _cat_bump_cooldown : float = 0.0
var _behavior_cooldown : float = 0.0
var _last_idle_name    : String = ""
var _last_walk_dir     : Vector2 = Vector2.DOWN  # hướng di chuyển cuối — tránh flicker frame đổi hướng
var _pre_action_pos    : Vector2 = Vector2.ZERO  # vị trí trước khi teleport tới item
var _action_item_pos   : Vector2 = Vector2.ZERO  # vị trí item, dùng cho return teleport
var _action_face_pos   : Vector2 = Vector2.INF   # item center để xác định hướng mặt sau teleport

var hunger : float = 1.0
var thirst : float = 1.0
var energy : float = 1.0

var _laziness    : float
var _curiosity   : float
var _shadow_mat : ShaderMaterial = null

var _other_pets   : Array   = []
var _floor_center : Vector2 = Vector2.ZERO
var _behaviors    : Array[PetBehavior] = []  # sorted by priority desc, built in _ready
var _cfg          : PetConfig                # resolved in _ready; never null

# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_cfg       = config if config else PetConfig.new()
	_spawn_pos = global_position
	_laziness  = randf()
	_curiosity = randf()
	_setup_frames()
	_setup_behaviors()
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

## Frozen = tĩnh tuyệt đối: velocity=0, không nhận tác động di chuyển.
## Mèo thoát frozen bằng cách set _move_dir (wander) hoặc _on_arrive (nav).
func _is_frozen() -> bool:
	return _anim_state != AnimState.WALK and _move_dir == Vector2.ZERO

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
			get_tree().create_timer(_cfg.idle_random_next_delay).timeout.connect(func(): _do_natural_behavior())
		AnimState.EAT_START:
			_change_anim_state(AnimState.EAT_LOOP)
		AnimState.EAT_END:
			_return_after_action()
		AnimState.DRINK_START:
			_change_anim_state(AnimState.DRINK_LOOP)
		AnimState.DRINK_END:
			_return_after_action()
		AnimState.SLEEP_PREPARE:
			_change_anim_state(AnimState.SLEEPING)
		AnimState.SLEEP_DONE:
			_return_after_action()

# ── Physics ───────────────────────────────────────────────────────────────────

# Nếu IDLE/IDLE_RANDOM đang play nhưng velocity vẫn đáng kể (bị đẩy bởi physics),
# ép ngay sang walk animation để tránh trạng thái "đứng yên nhưng đang trượt".

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
	if _is_frozen():
		velocity = Vector2.ZERO
		return

	# ── Free wander ───────────────────────────────────────────────────────────
	if _move_dir != Vector2.ZERO:
		_wander_timer -= delta
		if _wander_timer > 0.0:
			var target_vel := _move_dir * _cfg.move_speed
			velocity = velocity.move_toward(target_vel, _cfg.acceleration * delta)
			move_and_slide()

			var _hit_pet := false
			for _ci in get_slide_collision_count():
				var _col := get_slide_collision(_ci)
				if _col.get_collider() is Pet:
					velocity      = Vector2.ZERO
					_move_dir     = _col.get_normal()
					_wander_timer = maxf(_wander_timer, 0.8)
					_hit_pet      = true
					break
			if not _hit_pet and get_slide_collision_count() > 0 and _cat_bump_cooldown <= 0.0:
				_move_dir          = get_slide_collision(0).get_normal()
				_wander_timer      = 1.0
				_cat_bump_cooldown = 1.0

			_set_move_anim(true)
			return
		# Timer hết: xoá hướng đi, để fall-through xuống idle (friction xử lý decel)
		_move_dir = Vector2.ZERO

	# ── Idle (kể cả friction coast sau khi wander dừng) ──────────────────────
	velocity = velocity.move_toward(Vector2.ZERO, _cfg.friction * delta)
	move_and_slide()

	if velocity.length_squared() > _cfg.vel_idle_threshold * _cfg.vel_idle_threshold: return  # đang trượt dần, chưa đổi anim

	if _anim_state in [AnimState.IDLE, AnimState.IDLE_RANDOM]: return
	_change_anim_state(AnimState.IDLE)

# ── Stats ─────────────────────────────────────────────────────────────────────

func _tick_stats(delta: float) -> void:
	if _anim_state == AnimState.SLEEPING:
		energy = minf(energy + _cfg.energy_sleep_gain * delta, 1.0)
		if energy >= _cfg.energy_full_threshold:
			_change_anim_state(AnimState.SLEEP_DONE)
	else:
		energy = maxf(energy - _cfg.energy_decay * delta, 0.0)
	hunger = maxf(hunger - _cfg.hunger_decay * delta, 0.0)
	thirst = maxf(thirst - _cfg.thirst_decay * delta, 0.0)

func food_bowl_has_food() -> bool:
	if not food_bowl: return false
	var v = food_bowl.get("has_food")
	return bool(v) if v != null else true

func water_bowl_has_water() -> bool:
	if not water_bowl: return false
	var v = water_bowl.get("has_water")
	return bool(v) if v != null else true

# ── Behavior system ───────────────────────────────────────────────────────────

func _setup_behaviors() -> void:
	_behaviors.clear()
	_behaviors.append(EatBehavior.new())
	_behaviors.append(DrinkBehavior.new())
	_behaviors.append(SleepBehavior.new())
	_behaviors.append_array(extra_behaviors)
	_behaviors.sort_custom(func(a: PetBehavior, b: PetBehavior) -> bool: return a.priority > b.priority)

## Cố gắng kích hoạt behavior đầu tiên phù hợp (theo priority).
## Trả về true nếu có behavior được kích hoạt.
func _evaluate_behaviors() -> bool:
	for b: PetBehavior in _behaviors:
		if b.enabled and b.should_activate(self):
			if debug_log: print("[%s] behavior activated: %s" % [cat_name, b.get_class()])
			b.activate(self)
			return true
	return false

## Hook gọi ngay đầu sequence — override để thêm sound/signal trước khi mèo biến mất.
func _on_teleport_triggered() -> void:
	pass

func _do_teleport_sequence(dest: Vector2, cb: Callable) -> void:
	# Đóng băng ngay lập tức
	velocity             = Vector2.ZERO
	_move_dir            = Vector2.ZERO
	_anim_state          = AnimState.IDLE     # _is_frozen() → true, physics không can thiệp
	sprite.stop()
	_shadow_sprite.stop()
	_on_teleport_triggered()

	var tw := create_tween()
	tw.tween_interval(1.0)                                         # đứng yên 1s
	tw.tween_property(self, "modulate:a", 0.0, 0.3)               # fade out
	tw.tween_callback(func():                                      # teleport + reset
		global_position = dest
		velocity        = Vector2.ZERO
		if _action_face_pos != Vector2.INF:
			var face_left := _action_face_pos.x < dest.x
			sprite.flip_h         = face_left
			_shadow_sprite.flip_h = face_left)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)               # fade in
	tw.tween_callback(func(): _change_anim_state(AnimState.IDLE)) # resume idle anim
	tw.tween_interval(1.0)                                         # idle 1s trước action
	tw.tween_callback(cb)                                          # bắt đầu ăn/ngủ

## API gọi từ Behavior — lưu vị trí hiện tại rồi teleport tới item.
## face_toward: global_position của item để mèo quay mặt đúng hướng sau khi teleport.
func begin_action(dest: Vector2, action_cb: Callable, face_toward: Vector2 = Vector2.INF) -> void:
	_pre_action_pos  = global_position
	_action_item_pos = dest
	_action_face_pos = face_toward
	_do_teleport_sequence(dest, action_cb)

## Sau khi action kết thúc, teleport về vị trí ngẫu nhiên gần item rồi tiếp tục.
func _return_after_action() -> void:
	var angle      := randf() * TAU
	var dist       := randf_range(20.0, 50.0)
	var return_pos := _action_item_pos + Vector2(cos(angle), sin(angle)) * dist
	_do_teleport_sequence(return_pos, func(): _do_natural_behavior())

# ── Natural behavior ──────────────────────────────────────────────────────────

func _do_natural_behavior() -> void:
	if _current_state == PetStateMachine.State.SLEEPING: return
	if _anim_state == AnimState.SLEEPING and energy < _cfg.energy_full_threshold: return

	if _evaluate_behaviors(): return

	if hunger > 0.65:
		_decide_active()
	else:
		_decide_calm()

func _decide_active() -> void:
	var w := {}
	w["idle"]   = 0.3 + _laziness  * 0.2
	w["wander"] = 0.35 + _curiosity * 0.2
	match _weighted_pick(w):
		"idle":   _play_random_idle()
		"wander": _start_wander(randf_range(1.0, 2.0))
		_:        _play_random_idle()

func _decide_calm() -> void:
	var w := {}
	w["idle"]   = 0.3 + _laziness  * 0.2
	w["wander"] = 0.3 + _curiosity * 0.1
	match _weighted_pick(w):
		"idle":   _play_random_idle()
		"wander": _start_wander(randf_range(1.0, 2.0))
		_:        _play_random_idle()

func bowl_arrive_pos(bowl: Node2D) -> Vector2:
	var spot := bowl.get_node_or_null("ArriveSpot") as Node2D
	return spot.global_position if spot else bowl.global_position

func bed_is_free() -> bool:
	if not bed_node: return false
	var sleep_spot := bed_node.get_node_or_null("SleepSpot") as Node2D
	var dest := sleep_spot.global_position if sleep_spot else bed_node.global_position
	for p in _other_pets:
		if not is_instance_valid(p): continue
		var other := p as Pet
		if other == null: continue
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


# ── State handling ────────────────────────────────────────────────────────────

func _on_state_changed(new_state: int) -> void:
	_current_state = new_state
	if PetStateMachine.is_busy(_anim_state): return
	if _move_dir != Vector2.ZERO: return
	_kill_tween()
	match new_state:
		PetStateMachine.State.TIRED:
			_play_idle()
		PetStateMachine.State.IDLE, PetStateMachine.State.HAPPY, \
		PetStateMachine.State.HUNGRY:
			_play_random_idle()
		PetStateMachine.State.SLEEPING:
			go_to_bed()

# ── Bed ───────────────────────────────────────────────────────────────────────

func go_to_bed() -> void:
	if bed_node:
		var sleep_spot := bed_node.get_node_or_null("SleepSpot") as Node2D
		var dest       := sleep_spot.global_position if sleep_spot else bed_node.global_position
		begin_action(dest, func(): _change_anim_state(AnimState.SLEEP_PREPARE))
	else:
		_change_anim_state(AnimState.SLEEP_PREPARE)

# ── Eat ───────────────────────────────────────────────────────────────────────

func eat() -> void:
	_change_anim_state(AnimState.EAT_START)

func on_eat_completed() -> void:
	hunger = minf(hunger + _cfg.hunger_eat_gain, 1.0)
	_change_anim_state(AnimState.EAT_END)

# ── Drink ─────────────────────────────────────────────────────────────────────

func drink() -> void:
	_change_anim_state(AnimState.DRINK_START)

func on_drink_completed() -> void:
	thirst = minf(thirst + _cfg.thirst_drink_gain, 1.0)
	_change_anim_state(AnimState.DRINK_END)

# ── Idle animations ───────────────────────────────────────────────────────────

func _play_idle() -> void:
	if _move_dir != Vector2.ZERO: return
	_change_anim_state(AnimState.IDLE)

func _play_random_idle() -> void:
	if _move_dir != Vector2.ZERO: return
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
	# _move_dir đổi tức thì → không lag như velocity qua acceleration
	# Khi _move_dir = 0 (friction coast) thì giữ hướng latch cuối
	if _move_dir != Vector2.ZERO:
		_last_walk_dir = _move_dir
	var dir := _last_walk_dir
	if abs(dir.y) > abs(dir.x):
		_play("walk_down" if dir.y > 0 else "walk_up")
		sprite.flip_h = false
	else:
		_play("walk_side")
		sprite.flip_h = dir.x < 0

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
	position   = world_pos
	_spawn_pos = world_pos

func _kill_tween() -> void:
	if _tween and _tween.is_valid(): _tween.kill()
	sprite.scale          = Vector2(_BASE_SCALE, _BASE_SCALE)
	_shadow_sprite.scale  = sprite.scale
