class_name CharacterCustomizeUI
extends Control

# Wire these in the scene inspector or call setup() from code.
@export var color_manager : CharacterColorManager

@onready var hair_picker  : ColorPickerButton = $HairColorBtn
@onready var skirt_picker : ColorPickerButton = $SkirtColorBtn
@onready var threshold_slider : HSlider        = $ThresholdSlider

func _ready() -> void:
	if color_manager == null: return
	var app := color_manager.appearance
	hair_picker.color   = app.hair_color
	skirt_picker.color  = app.skirt_color
	threshold_slider.value = app.threshold

	hair_picker.color_changed.connect(_on_hair_changed)
	skirt_picker.color_changed.connect(_on_skirt_changed)
	threshold_slider.value_changed.connect(_on_threshold_changed)

func _on_hair_changed(c: Color)    -> void: color_manager.set_hair_color(c)
func _on_skirt_changed(c: Color)   -> void: color_manager.set_skirt_color(c)
func _on_threshold_changed(v: float) -> void: color_manager.set_threshold(v)

# ── Minimal scene tree expected ──────────────────────────────────────────────
# CharacterCustomizeUI (Control)
#   HairColorBtn   (ColorPickerButton)
#   SkirtColorBtn  (ColorPickerButton)
#   ThresholdSlider (HSlider, min=0 max=0.5 step=0.01)
