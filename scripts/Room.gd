@tool
extends Node2D
class_name Room

@export var room_data_path: String = "res://data/rooms/room_1.json":
	set(v):
		room_data_path = v
		if Engine.is_editor_hint() and is_node_ready():
			_editor_rebuild()

@onready var _center : Marker2D = $Center

var _item_map     : Dictionary = {}
var _object_grid  : Dictionary = {}
var grid_system   : RoomGridSystem = null
var _grid_overlay : Node2D         = null
var _world        : Node2D         = null

var center_world : Vector2:
	get: return _center.global_position if _center else global_position

var floor_poly_world : PackedVector2Array:
	get:
		var out := PackedVector2Array()
		for v in _floor_zone_local:
			out.append(to_global(Vector2(float(v[0]), float(v[1]))))
		return out

var _floor_zone_local : Array = []

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_rebuild()

func _editor_rebuild() -> void:
	for child in get_children():
		if child == _center: continue
		if child.name == "Walls": continue
		child.free()
	_item_map.clear()
	_object_grid.clear()
	grid_system   = null
	_grid_overlay = null
	_world        = null

	if room_data_path == "" or not FileAccess.file_exists(room_data_path): return
	var file := FileAccess.open(room_data_path, FileAccess.READ)
	if not file: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary: return
	build(data)

func build(data: Dictionary) -> void:
	var vp := get_viewport().get_visible_rect().size
	position = _v2(data["room_position"]) if data.has("room_position") else vp / 2.0
	scale    = _v2(data["room_scale"])
	_center.position = _v2(data.get("center", [0, 75]))

	# ── Room background ──────────────────────────────────────────────────────
	if data.has("room_layers"):
		var layers : Dictionary = data["room_layers"]
		var z_map := {"floor": -4, "wall_left": -3, "wall_right": -2}
		for key in ["floor", "wall_left", "wall_right"]:
			if not layers.has(key): continue
			var spr     := Sprite2D.new()
			spr.name     = "Layer_" + key
			spr.z_index  = z_map[key]
			spr.texture  = load(layers[key])
			add_child(spr)
	elif data.has("room_texture") and data["room_texture"] != "":
		var spr     := Sprite2D.new()
		spr.name     = "Layer_room"
		spr.z_index  = -2
		spr.texture  = load(data["room_texture"])
		var ts      := float(data.get("room_texture_scale", 1.0))
		spr.scale    = Vector2(ts, ts)
		var off     : Array = data.get("room_texture_offset", [0.0, 0.0])
		spr.position = Vector2(float(off[0]), float(off[1]))
		add_child(spr)

	# ── Grid system ───────────────────────────────────────────────────────────
	grid_system = RoomGridSystem.new()
	grid_system.name = "GridSystem"
	add_child(grid_system)
	grid_system.setup(data)

	_floor_zone_local = data.get("zones", {}).get("floor", [])

	# ── World (y_sort container for all items + pets) ─────────────────────────
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	add_child(_world)

	# ── Decorations ───────────────────────────────────────────────────────────
	for dec : Dictionary in data.get("decorations", []):
		var spr     := Sprite2D.new()
		spr.name     = dec["name"]
		spr.position = _v2(dec["position"])
		spr.scale    = _v2(dec["scale"])
		spr.texture  = load(dec["texture"])
		add_child(spr)

	# ── Object grid definitions ───────────────────────────────────────────────
	# objectGrid.json format: { "w_d_h": ["SceneName", ...] }
	# Build reverse map: sceneName → {w, d, h}
	var og_file := FileAccess.open("res://data/objectGrid.json", FileAccess.READ)
	if og_file:
		var og = JSON.parse_string(og_file.get_as_text())
		og_file.close()
		if og is Dictionary:
			for size_key in og:
				var parts := (size_key as String).split("_")
				if parts.size() != 3: continue
				var def := {"w": int(parts[0]), "d": int(parts[1]), "h": int(parts[2])}
				for sname in og[size_key]:
					_object_grid[sname] = def

	# ── Items ─────────────────────────────────────────────────────────────────
	for item : Dictionary in data.get("items", []):
		var node : Node
		if item.has("scene"):
			node = (load(item["scene"]) as PackedScene).instantiate()
		else:
			continue
		# Inject script before add_child so _ready() runs with correct script
		if item.has("script"):
			node.set_script(load(item["script"]))
		# Inject texture/scale if specified (for generic scenes like WallDeco, Bowl, Toy)
		if item.has("texture"):
			for child in node.get_children():
				if child is Sprite2D:
					(child as Sprite2D).texture = load(item["texture"])
					if item.has("sprite_scale"):
						(child as Sprite2D).scale = _v2(item["sprite_scale"])
					break
		node.name = item["name"]
		_world.add_child(node)
		# Godot may sanitise the name (e.g. "@" → "_") — keep entry in sync
		if node.name != item["name"]:
			item["name"] = node.name
		_item_map[node.name] = node
		node.set_meta("item_id",   item.get("id", item["name"]))
		node.set_meta("sceneName", item.get("sceneName", ""))

		# Look up grid dimensions from objectGrid.json by sceneName
		var og_def : Dictionary = _object_grid.get(item.get("sceneName", ""), {})
		var gw    : int     = og_def.get("w", item.get("grid_w", 1))
		var gd    : int     = og_def.get("d", item.get("grid_d", 1))
		var gh    : int     = og_def.get("h", item.get("grid_h", 0))
		var gsurf : String  = item.get("grid_surface", "")
		node.set_meta("grid_w",       gw)
		node.set_meta("grid_d",       gd)
		node.set_meta("grid_h",       gh)
		node.set_meta("place_offset", Vector2.ZERO)
		if gsurf != "":
			node.set_meta("preferred_surface", gsurf)

		var node2d := node as Node2D
		if node2d == null:
			continue

		if gsurf != "" and item.has("grid_col") and item.has("grid_row"):
			grid_system.place_item(node2d, gsurf, item["grid_col"], item["grid_row"], gw, gd, gh)
			for child in node2d.get_children():
				if child is CollisionShape2D:
					node2d.position -= (child as CollisionShape2D).position
					break
		else:
			node2d.position = _v2(item.get("position", [0.0, 0.0]))

		if item.has("scale_x"):
			node2d.scale.x = float(item["scale_x"])

	# ── Grid overlay ─────────────────────────────────────────────────────────
	var grid := Node2D.new()
	grid.name    = "GridOverlay"
	grid.z_index = 0
	grid.visible = false
	grid.set_script(load("res://scripts/RoomGrid.gd"))
	add_child(grid)
	grid.call("setup", data)
	_grid_overlay = grid

	# Walls are placed directly in Room.tscn for visual editing in the editor.

# ── Public API ────────────────────────────────────────────────────────────────

func get_item(item_name: String) -> Node:
	return _item_map.get(item_name, null)

# Tìm item đầu tiên có sceneName khớp (dùng khi pet data dùng tên scene thay vì instance name)
func get_item_by_scene(scene_name: String) -> Node:
	for node in _item_map.values():
		if node.get_meta("sceneName", "") == scene_name:
			return node
	return null

# Tìm item đầu tiên có script khớp với tên file (vd: "FoodBowl", "WaterBowl", "CatBed")
func get_item_by_script(script_basename: String) -> Node:
	for node in _item_map.values():
		var scr = node.get_script()
		if scr and (scr as Script).resource_path.get_file().get_basename() == script_basename:
			return node
	return null

func register_item(item_name: String, node: Node) -> void:
	_item_map[item_name] = node

func unregister_item(item_name: String) -> void:
	_item_map.erase(item_name)

func item_names() -> Array:
	return _item_map.keys()

func placed_item_ids() -> Array:
	var ids := []
	for node in _item_map.values():
		if is_instance_valid(node) and node.has_meta("item_id"):
			ids.append(node.get_meta("item_id"))
		else:
			ids.append(node.name)
	return ids

func set_highlight(quads, valid: bool) -> void:
	if _grid_overlay:
		_grid_overlay.call("set_highlight", quads, valid)

func clear_highlight() -> void:
	if _grid_overlay:
		_grid_overlay.call("clear_highlight")

# ── Util ──────────────────────────────────────────────────────────────────────

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
