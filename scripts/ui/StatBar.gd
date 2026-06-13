extends HBoxContainer
class_name StatBar

@export var stat_name: String = "hunger"
@export var icon_text: String = "🍔"
@export var bar_color: Color = Color(1.0, 0.6, 0.2)

@onready var icon_label: Label = $Icon
@onready var bar: ProgressBar = $Bar

func _ready() -> void:
	icon_label.text = icon_text
	_style_bar()
	GameManager.stats_changed.connect(_on_stats_changed)

func _style_bar() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = bar_color
	fill.corner_radius_top_left    = 4
	fill.corner_radius_top_right   = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2, 0.6)
	bg.corner_radius_top_left    = 4
	bg.corner_radius_top_right   = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)

func _on_stats_changed(changed_stat: String, value: float) -> void:
	if changed_stat == stat_name:
		bar.value = value
