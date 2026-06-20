class_name CharacterColorManager
extends Node

const SHADER_PATH := "res://assets/shaders/player_color_swap.gdshader"

@export var appearance : CharacterAppearance
@export var target_sprite : Sprite2D   # drag the AnimatedSprite2D/Sprite2D here

var _mat : ShaderMaterial

func _ready() -> void:
	if appearance == null:
		appearance = CharacterAppearance.new()
	# target_sprite may be assigned by parent after _ready — defer setup
	call_deferred("_setup_material")
	call_deferred("apply")

func _setup_material() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	if target_sprite:
		target_sprite.material = _mat

# Push all appearance values into shader uniforms.
func apply() -> void:
	if _mat == null:
		return
	var src_hair  := CharacterAppearance.DEFAULT_HAIR_COLOR
	var src_skirt := CharacterAppearance.DEFAULT_SKIRT_COLOR
	_mat.set_shader_parameter("hair_source",  src_hair)
	_mat.set_shader_parameter("skirt_source", src_skirt)
	_mat.set_shader_parameter("hair_target",  appearance.hair_color)
	_mat.set_shader_parameter("skirt_target", appearance.skirt_color)
	_mat.set_shader_parameter("threshold",    appearance.threshold)

# Call this from UI ColorPicker signals for live preview.
func set_hair_color(color: Color) -> void:
	appearance.hair_color = color
	_mat.set_shader_parameter("hair_target", color)

func set_skirt_color(color: Color) -> void:
	appearance.skirt_color = color
	_mat.set_shader_parameter("skirt_target", color)

func set_threshold(value: float) -> void:
	appearance.threshold = value
	_mat.set_shader_parameter("threshold", value)
