extends Button
class_name UIButton

@export var symbol: String = "+"
@export var font_size: int = 14
@export var corner_radius: int = 6

const _FONT = preload("res://assets/fonts/Jersey_25/Jersey25-Regular.ttf")

const _C_BG     := Color(0.82, 0.62, 0.44, 1.0)
const _C_BORDER := Color(0.58, 0.36, 0.18, 1.0)

func _ready() -> void:
	text = symbol

	var s := StyleBoxFlat.new()
	s.bg_color = _C_BG
	s.set_corner_radius_all(corner_radius)
	s.border_width_top    = 1
	s.border_width_right  = 1
	s.border_width_bottom = 1
	s.border_width_left   = 1
	s.border_color = _C_BORDER

	add_theme_stylebox_override("normal",  s)
	add_theme_stylebox_override("hover",   s)
	add_theme_stylebox_override("pressed", s)
	add_theme_stylebox_override("focus",   s)
	add_theme_font_override("font",              _FONT)
	add_theme_font_size_override("font_size",    font_size)
	add_theme_color_override("font_color",       Color(1.0, 1.0, 1.0, 1.0))
	add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))

	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.82, 0.82), 0.07).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(1.0,  1.0),  0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
