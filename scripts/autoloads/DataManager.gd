extends Node

signal coins_changed(amount: int)
signal gems_changed(amount: int)

const SAVE_PATH      := "user://player_data.json"
const INVENTORY_PATH := "user://inventory.json"
const INVENTORY_DEFAULT := "res://data/inventory.json"

var coins: int = 0
var gems:  int = 0
var owned_items: Array = []

func _ready() -> void:
	load_data()
	_load_inventory()

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
	var data := {"coins": coins, "gems": gems}
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
		coins = int(data.get("coins", 0))
		gems  = int(data.get("gems",  0))

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
