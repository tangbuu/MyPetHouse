extends HBoxContainer
class_name StatBar

@export var stat_name: String = "hunger"
@export var fill_texture: Texture2D

@onready var bar: TextureProgressBar = $Bar

const BAR_BG := preload("res://assets/UI/bars/bar_bg.png")

var _watched_pet = null

func _ready() -> void:
	bar.texture_under    = BAR_BG
	bar.texture_progress = fill_texture
	bar.fill_mode        = TextureProgressBar.FILL_LEFT_TO_RIGHT
	GameManager.stats_changed.connect(_on_stats_changed)

func watch_pet(pet) -> void:
	_watched_pet = pet

func _process(_delta: float) -> void:
	if _watched_pet and is_instance_valid(_watched_pet):
		bar.value = float(_watched_pet.get(stat_name)) * 100.0

func _on_stats_changed(changed_stat: String, value: float) -> void:
	if _watched_pet: return
	if changed_stat == stat_name:
		bar.value = value * 100.0
