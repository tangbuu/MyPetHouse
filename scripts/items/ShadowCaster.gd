extends Node

const _SHADER := preload("res://shaders/pet_shadow.gdshader")

var _shadow : Sprite2D       = null
var _mat    : ShaderMaterial = null
var _last_h : float          = -999.0

func _ready() -> void:
	_setup_shadow.call_deferred()

func _setup_shadow() -> void:
	var parent := get_parent()
	var src    : Sprite2D = null
	for child in parent.get_children():
		if child is Sprite2D:
			src = child
			break
	if not src: return

	_shadow         = Sprite2D.new()
	_shadow.texture = src.texture
	_shadow.scale   = src.scale
	_shadow.offset  = src.offset

	# shadow_length dựa trên chiều cao texture để tự scale theo kích thước item.
	# UV.y=1 (chân item) không dịch, UV.y=0 (đỉnh) dịch tối đa shadow_length px local.
	var shadow_len : float = float(src.texture.get_height()) * 0.25

	_mat        = ShaderMaterial.new()
	_mat.shader = _SHADER
	_mat.set_shader_parameter("light_dir",     Vector2(-0.894, 0.447))
	_mat.set_shader_parameter("shadow_length", shadow_len)
	_mat.set_shader_parameter("shadow_alpha",  0.15)
	_shadow.material = _mat

	parent.add_child(_shadow)
	parent.move_child(_shadow, 0)
	_update_shadow()

func _process(_delta: float) -> void:
	if not _mat: return
	var h := DataManager.game_time_hours
	if h == _last_h: return
	_last_h = h
	_update_shadow()

func _update_shadow() -> void:
	if not _mat: return
	var pos          := (get_parent() as Node2D).global_position
	var blended_dir  := Vector2.ZERO
	var total_weight := 0.0
	var radius       := 600.0

	for lamp in WallLamp.all_lamps:
		var l := lamp as WallLamp
		if not l.is_on: continue
		var to_entity := pos - l.global_position
		var dist      := to_entity.length()
		if dist > radius: continue

		var weight  := 1.0 - dist / radius
		var dx      := to_entity.x
		var iso     := Vector2(dx, abs(dx) * 0.5)
		var iso_dir := iso.normalized() if iso.length_squared() > 1.0 else Vector2(0.0, 1.0)
		blended_dir  += iso_dir * weight
		total_weight += weight

	if total_weight > 0.01:
		var final_dir : Vector2
		if blended_dir.length_squared() > 0.001:
			final_dir = blended_dir.normalized()
		else:
			final_dir = Vector2(0.0, 1.0)
		_mat.set_shader_parameter("light_dir",    final_dir)
		_mat.set_shader_parameter("shadow_alpha", 0.28)
	else:
		_mat.set_shader_parameter("light_dir",    Vector2(-0.894, 0.447))
		_mat.set_shader_parameter("shadow_alpha", 0.15)
