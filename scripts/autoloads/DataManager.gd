extends Node

signal coins_changed(amount: int)
signal gems_changed(amount: int)

const SAVE_PATH      := "user://player_data.json"
const INVENTORY_PATH := "user://inventory.json"
const INVENTORY_DEFAULT := "res://data/inventory.json"

var coins: int = 999999
var gems:  int = 9999
var owned_items: Array = []

var player_name  : String = "PLAYER"
var player_level : int    = 1

# In-game clock: 1 real second = 1 game minute
var game_day         : int   = 1
var game_time_hours  : float = 6.0
const GAME_TIME_SCALE := 1.0 / 60.0  # real seconds → game hours

func _ready() -> void:
	load_data()
	_load_inventory()

func _process(delta: float) -> void:
	game_time_hours += delta * GAME_TIME_SCALE
	if game_time_hours >= 24.0:
		game_time_hours -= 24.0
		game_day += 1

func game_time_string() -> String:
	var h := int(game_time_hours)
	var m := int((game_time_hours - h) * 60.0)
	var ampm := "AM" if h < 12 else "PM"
	var h12  := h % 12
	if h12 == 0: h12 = 12
	return "%d:%02d %s" % [h12, m, ampm]

# ── Resources ─────────────────────────────────────────────────────────────────

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	save_data()

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	save_data()
	return true

func add_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit(gems)
	save_data()

func spend_gems(amount: int) -> bool:
	if gems < amount:
		return false
	gems -= amount
	gems_changed.emit(gems)
	save_data()
	return true

# ── Save / Load ───────────────────────────────────────────────────────────────

func save_data() -> void:
	var data := {
		"coins": coins, "gems": gems,
		"player_name": player_name, "player_level": player_level,
		"game_day": game_day, "game_time_hours": game_time_hours
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		coins            = int(data.get("coins", 999999))
		gems             = int(data.get("gems",  9999))
		player_name      = str(data.get("player_name",  "PLAYER"))
		player_level     = int(data.get("player_level", 1))
		game_day         = int(data.get("game_day",     1))
		game_time_hours  = float(data.get("game_time_hours", 6.0))

# ── Inventory ─────────────────────────────────────────────────────────────────

func is_owned(item_id: String) -> bool:
	return item_id in owned_items

func own_item(item_id: String) -> void:
	owned_items.append(item_id)
	_save_inventory()

func _load_inventory() -> void:
	var path := INVENTORY_PATH if FileAccess.file_exists(INVENTORY_PATH) else INVENTORY_DEFAULT
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		owned_items = data.get("owned", [])

func reset_inventory() -> void:
	owned_items = []
	if FileAccess.file_exists(INVENTORY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(INVENTORY_PATH))

func _save_inventory() -> void:
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.WRITE)
	if not file: return
	file.store_string(JSON.stringify({"owned": owned_items}, "  "))
	file.close()
