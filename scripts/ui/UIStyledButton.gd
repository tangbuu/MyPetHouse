extends Button
class_name UIStyledButton

@export var bg_color:     Color = Color(0.97, 0.73, 0.82, 1.0)
@export var border_color: Color = Color(0.76, 0.52, 0.62, 1.0)
@export var font_color:   Color = Color(0.42, 0.26, 0.16, 1.0)
@export var corner_radius: int  = 10
@export var font_size:     int  = 16

const _FONT = preload("res://assets/fonts/Jersey_25/Jersey25-Regular.ttf")

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color    = bg_color
	style.border_color = border_color
	style.set_corner_radius_all(corner_radius)
	style.set_border_width_all(2)

	add_theme_stylebox_override("normal",  style)
	add_theme_stylebox_override("hover",   style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus",   style)
	add_theme_font_override("font",              _FONT)
	add_theme_font_size_override("font_size",    font_size)
	add_theme_color_override("font_color",       font_color)
	add_theme_color_override("font_hover_color", font_color)

	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.90, 0.90), 0.07).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(1.0,  1.0),  0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
