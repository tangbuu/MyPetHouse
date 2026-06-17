extends Node2D

const _FONT = preload("res://assets/fonts/Jersey_25/Jersey25-Regular.ttf")

const _GROUPS := [
	["idle", "idle2", "idle3", "idle4", "idle5", "idle6"],
	["walk_side", "walk_down", "walk_up"],
	["eat_start", "eat_loop", "eat_end"],
	["drink_start", "drink_loop", "drink_end"],
	["sleeping", "sofull", "tired", "cry"],
]

const _C_PANEL  := Color(0.18, 0.14, 0.10, 0.96)
const _C_BTN    := Color(0.68, 0.45, 0.28, 1.0)
const _C_BORDER := Color(0.52, 0.30, 0.14, 1.0)
const _C_ACTIVE := Color(0.94, 0.83, 0.71, 1.0)

@onready var _pet: Pet = $Pet
var _label: Label
var _buttons: Dictionary = {}
var _active_anim: String = "idle"

func _ready() -> void:
	_pet.position = Vector2(200, 480)
	_pet.force_anim("idle")
	_build_ui()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.10, 0.08, 1.0)
	bg.z_index = -1
	layer.add_child(bg)

	# Current anim label (top-left)
	_label = Label.new()
	_label.add_theme_font_override("font", _FONT)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75, 1.0))
	_label.position = Vector2(16, 16)
	_label.text = "idle"
	layer.add_child(_label)

	# Right panel
	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -170.0
	panel.offset_right  = 0.0
	var ps := StyleBoxFlat.new()
	ps.bg_color = _C_PANEL
	ps.content_margin_left   = 8.0
	ps.content_margin_right  = 8.0
	ps.content_margin_top    = 10.0
	ps.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", ps)
	layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	for group in _GROUPS:
		var sep := HSeparator.new()
		vbox.add_child(sep)
		for anim: String in group:
			var btn := Button.new()
			btn.text = anim
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_override("font", _FONT)
			btn.add_theme_font_size_override("font_size", 13)
			_style_btn(btn, false)
			var a := anim
			btn.pressed.connect(func(): _play_anim(a))
			vbox.add_child(btn)
			_buttons[anim] = btn

	_highlight("idle")

func _play_anim(anim: String) -> void:
	_pet.force_anim(anim)
	_label.text = anim
	_highlight(anim)
	_active_anim = anim

func _highlight(anim: String) -> void:
	for a in _buttons:
		_style_btn(_buttons[a], a == anim)

func _style_btn(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color    = _C_ACTIVE if active else _C_BTN
	s.border_color = _C_BORDER
	s.set_corner_radius_all(4)
	s.border_width_top    = 1
	s.border_width_right  = 1
	s.border_width_bottom = 1
	s.border_width_left   = 1
	s.content_margin_left   = 8.0
	s.content_margin_right  = 8.0
	s.content_margin_top    = 4.0
	s.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_stylebox_override("pressed", s)
	var fc := Color(0.35, 0.20, 0.10) if active else Color(1.0, 1.0, 1.0)
	btn.add_theme_color_override("font_color",         fc)
	btn.add_theme_color_override("font_hover_color",   fc)
	btn.add_theme_color_override("font_pressed_color", fc)
