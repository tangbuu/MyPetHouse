@tool
extends Node2D
class_name Room

@export var room_data_path: String = "res://data/rooms/room_1.json":
	set(v):
		room_data_path = v
		if Engine.is_editor_hint() and is_node_ready():
			_editor_rebuild()

@onready var _room_sprite : Sprite2D  = $RoomSprite
@onready var _center      : Marker2D  = $Center

var _item_map : Dictionary = {}

var center_world : Vector2:
	get: return _center.global_position if _center else global_position

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_rebuild()

func _editor_rebuild() -> void:
	# Remove previously built dynamic children
	for child in get_children():
		if child == _center or child == _room_sprite: continue
		child.free()
	_item_map.clear()

	if room_data_path == "" or not FileAccess.file_exists(room_data_path): return
	var file := FileAccess.open(room_data_path, FileAccess.READ)
	if not file: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary: return
	build(data)

func build(data: Dictionary) -> void:
	position = _v2(data["room_position"])
	scale    = _v2(data["room_scale"])

	_room_sprite.texture = load(data["room_texture"])
	_center.position     = _v2(data.get("center", [0, 75]))

	for dec: Dictionary in data.get("decorations", []):
		var spr     := Sprite2D.new()
		spr.name     = dec["name"]
		spr.position = _v2(dec["position"])
		spr.scale    = _v2(dec["scale"])
		spr.texture  = load(dec["texture"])
		add_child(spr)

	for item: Dictionary in data.get("items", []):
		var node     := (load(item["scene"]) as PackedScene).instantiate()
		node.name     = item["name"]
		node.position = _v2(item["position"])
		add_child(node)
		_item_map[item["name"]] = node

	for w: Dictionary in data.get("walls", []):
		var wall      := StaticBody2D.new()
		wall.position  = _v2(w["position"])
		wall.rotation  = float(w["rotation"])
		var col        := CollisionShape2D.new()
		col.shape      = RectangleShape2D.new()
		(col.shape as RectangleShape2D).size = _v2(w["size"])
		wall.add_child(col)
		add_child(wall)

func get_item(name: String) -> Node:
	return _item_map.get(name, null)

func item_names() -> Array:
	return _item_map.keys()

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
