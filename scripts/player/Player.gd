class_name Player
extends CharacterBody2D

@onready var sprite         : Sprite2D             = $Sprite
@onready var shadow_sprite  : Sprite2D             = $ShadowSprite
@onready var color_manager  : CharacterColorManager = $CharacterColorManager

const SPEED : float = 90.0

const IDLE_FRAMES    : Array = [0, 1, 2, 3, 4]
const IDLE_TIME      : float = 0.14
const WALK_FRAMES         : int   = 6
const WALK_UP_FRAMES      : int   = 8
const WALK_UP_USE_FRAMES  : Array = [0, 1, 2, 3, 4]
const WALK_DOWN_FRAMES    : int   = 4
const WALK_TIME           : float = 0.16

enum Dir { IDLE, SIDE, UP, DOWN }

var _idle_tex      : Texture2D
var _walk_tex      : Texture2D
var _walk_up_tex   : Texture2D
var _walk_down_tex : Texture2D

var _frame_idx   : int   = 0
var _frame_timer : float = 0.0
var _cur_dir     : Dir   = Dir.IDLE
var _shadow_mat  : ShaderMaterial = null

func _ready() -> void:
	sprite.scale        = Vector2(0.5, 0.5)
	shadow_sprite.scale = sprite.scale

	_idle_tex    = load("res://assets/player/player_idle_sheet.png")
	_walk_tex    = load("res://assets/player/player_walk_side_sheet.png")
	_walk_up_tex   = load("res://assets/player/player_walk_up_sheet.png")
	_walk_down_tex = load("res://assets/player/walk_down.png")

	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = load("res://shaders/pet_shadow.gdshader")
	_shadow_mat.set_shader_parameter("shadow_alpha",  0.30)
	_shadow_mat.set_shader_parameter("shadow_length", 50.0)
	_shadow_mat.set_shader_parameter("light_dir",     Vector2(-0.894, 0.447))
	shadow_sprite.material = _shadow_mat

	motion_mode = MOTION_MODE_FLOATING
	z_index = 0
	color_manager.target_sprite = sprite
	color_manager.apply()

func _update_shadow() -> void:
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
		var final_dir := blended_dir.normalized() if blended_dir.length_squared() > 0.001 else Vector2(0.0, 1.0)
		_shadow_mat.set_shader_parameter("light_dir",     final_dir)
		_shadow_mat.set_shader_parameter("shadow_length", blended_len / total_weight)
		_shadow_mat.set_shader_parameter("shadow_alpha",  0.35)
	else:
		_shadow_mat.set_shader_parameter("light_dir",     Vector2(-0.894, 0.447))
		_shadow_mat.set_shader_parameter("shadow_length", 60.0)
		_shadow_mat.set_shader_parameter("shadow_alpha",  0.18)

func _physics_process(_delta: float) -> void:
	_update_shadow()
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up",   "ui_down")
	)
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		velocity = dir * SPEED
		var new_dir : Dir
		if dir.y < 0 and abs(dir.y) > abs(dir.x):
			new_dir = Dir.UP
		elif dir.y > 0 and abs(dir.y) > abs(dir.x):
			new_dir = Dir.DOWN
		else:
			new_dir = Dir.SIDE
		_set_dir(new_dir)
		if new_dir == Dir.SIDE and dir.x != 0:
			sprite.flip_h        = dir.x < 0
			shadow_sprite.flip_h = sprite.flip_h
	else:
		velocity = Vector2.ZERO
		_set_dir(Dir.IDLE)
	move_and_slide()

func _process(delta: float) -> void:
	_frame_timer += delta
	var frame_time := IDLE_TIME if _cur_dir == Dir.IDLE else WALK_TIME
	if _frame_timer >= frame_time:
		_frame_timer = 0.0
		match _cur_dir:
			Dir.IDLE:
				_frame_idx = (_frame_idx + 1) % IDLE_FRAMES.size()
				sprite.frame        = IDLE_FRAMES[_frame_idx]
				shadow_sprite.frame = IDLE_FRAMES[_frame_idx]
			Dir.SIDE:
				_frame_idx = (_frame_idx + 1) % WALK_FRAMES
				sprite.frame        = _frame_idx
				shadow_sprite.frame = _frame_idx
			Dir.UP:
				_frame_idx = (_frame_idx + 1) % WALK_UP_USE_FRAMES.size()
				sprite.frame        = WALK_UP_USE_FRAMES[_frame_idx]
				shadow_sprite.frame = WALK_UP_USE_FRAMES[_frame_idx]
			Dir.DOWN:
				_frame_idx = (_frame_idx + 1) % WALK_DOWN_FRAMES
				sprite.frame        = _frame_idx
				shadow_sprite.frame = _frame_idx

func _set_dir(new_dir: Dir) -> void:
	if new_dir == _cur_dir:
		return
	_cur_dir     = new_dir
	_frame_idx   = 0
	_frame_timer = 0.0
	match new_dir:
		Dir.IDLE:
			sprite.texture = _idle_tex
			sprite.hframes = IDLE_FRAMES.size()
		Dir.SIDE:
			sprite.texture = _walk_tex
			sprite.hframes = WALK_FRAMES
		Dir.UP:
			sprite.texture = _walk_up_tex
			sprite.hframes = WALK_UP_FRAMES
		Dir.DOWN:
			sprite.texture = _walk_down_tex
			sprite.hframes = WALK_DOWN_FRAMES
	shadow_sprite.texture = sprite.texture
	shadow_sprite.hframes = sprite.hframes
	sprite.frame          = 0
	shadow_sprite.frame   = 0
