extends Node2D

@export var room_data_path: String = "res://data/rooms/room_1.json"

@onready var _bg  : ColorRect     = $BG
@onready var _hud : CanvasLayer   = $HUD

var _room_data : Dictionary  = {}
var _room      : Room        = null
var _bg_rect   : TextureRect = null

var _edit_mode     : bool    = false
var _dragging_item : Node2D  = null
var _drag_offset   : Vector2 = Vector2.ZERO
var _pending_item  : Node2D  = null
var _pending_item_data : Dictionary = {}

const _HOLD_THRESHOLD := 0.35
var _hold_active : bool    = false
var _hold_timer  : float   = 0.0
var _hold_pos    : Vector2 = Vector2.ZERO

var _drag_canvas        : CanvasLayer = null
var _drag_in_canvas     : bool        = false
var _drag_offset_canvas : Vector2     = Vector2.ZERO
var _drag_base_scale    : Vector2     = Vector2.ONE

# Grid drag state
var _drag_w               : int    = 1
var _drag_d               : int    = 1
var _drag_h               : int    = 0
var _drag_foot_offset     : Vector2 = Vector2.ZERO
var _drag_origin_surface  : String = ""
var _drag_origin_col      : int    = -1
var _drag_origin_row      : int    = -1
var _drag_preferred_surf  : String = ""

var _camera        : Camera2D = null
var _cam_origin    : Vector2  = Vector2.ZERO
var _zoom_level    : float    = 1.0
const ZOOM_MIN     := 1.0
const ZOOM_MAX     := 2.5
var _active_touches  : int        = 0
var _touch_positions : Dictionary = {}
var _pinch_distance  : float      = 0.0
var _is_panning      : bool       = false
var _pan_distance    : float      = 0.0
const PAN_THRESHOLD               := 8.0

var _pet_nodes       : Array[Node2D]  = []
var _pet_labels      : Array[Label]   = []
var _hunger_sliders  : Array[HSlider] = []
var _thirst_sliders  : Array[HSlider] = []
var _energy_sliders  : Array[HSlider] = []
var _hunger_dragging : Array[bool]    = []
var _thirst_dragging : Array[bool]    = []
var _energy_dragging : Array[bool]    = []

func _ready() -> void:
	_load_room(room_data_path)
	_setup_camera()
	_hud.edit_mode_toggled.connect(_set_edit_mode)
	_hud.room_purchased.connect(_on_room_purchased)
	_hud.place_item.connect(_on_place_item)
	_hud.bag_btn_pressed.connect(func():
		var placed  := _room.placed_item_ids() if _room else []
		var room_tx : String = _room_data.get("room_texture", "")
		_hud.open_bag(placed, room_tx))
	_drag_canvas = CanvasLayer.new()
	_drag_canvas.layer = 20
	add_child(_drag_canvas)
	call_deferred("_build_debug_ui")

func _setup_camera() -> void:
	_camera = Camera2D.new()
	var vp := get_viewport().get_visible_rect().size
	_cam_origin = vp / 2.0
	_camera.position = _cam_origin
	_camera.zoom = Vector2(ZOOM_MIN, ZOOM_MIN)
	add_child(_camera)
	_camera.make_current()

func _clamp_camera() -> void:
	var vp := get_viewport().get_visible_rect().size
	var lx := vp.x / 2.0 * (1.0 - 1.0 / _zoom_level)
	var ly := vp.y / 2.0 * (1.0 - 1.0 / _zoom_level)
	_camera.position = Vector2(
		clamp(_camera.position.x, _cam_origin.x - lx, _cam_origin.x + lx),
		clamp(_camera.position.y, _cam_origin.y - ly, _cam_origin.y + ly)
	)

# ── Room loading ──────────────────────────────────────────────────────────────

func _load_room(res_path: String) -> void:
	var file := FileAccess.open(res_path, FileAccess.READ)
	if not file:
		push_error("Main: cannot open " + res_path)
		return
	_room_data = JSON.parse_string(file.get_as_text())
	file.close()
	_build(_room_data)

func _build(data: Dictionary) -> void:
	# ── Background ──
	var bg_img: String = data.get("background_image", "")
	if bg_img != "" and ResourceLoader.exists(bg_img):
		if not _bg_rect:
			_bg_rect              = TextureRect.new()
			_bg_rect.z_index      = -9
			_bg_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			add_child(_bg_rect)
			_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg_rect.size    = get_viewport().get_visible_rect().size
		_bg_rect.texture = load(bg_img)
		_bg_rect.visible = true
		_bg.visible      = false
	else:
		var c: Array = data.get("background_color", [0.69, 0.82, 0.89])
		_bg.color   = Color(c[0], c[1], c[2], 1.0)
		_bg.visible = true
		if _bg_rect: _bg_rect.visible = false

	# ── Room (sprite, furniture, items, walls) ──
	if _room:
		_room.queue_free()
	_room = (load("res://scenes/Room.tscn") as PackedScene).instantiate()
	_room.name = "Room"
	add_child(_room)
	_room.build(data)

	# ── Pets ──
	var floor_pts := _pts(data.get("zones", {}).get("floor", []))
	var used_spots : Array[Vector2] = []
	var pet_nodes  : Array[Node2D]  = []

	for p: Dictionary in data.get("pets", []):
		var pet      := (load(p["scene"]) as PackedScene).instantiate()
		pet.name      = p["name"]
		var spot      := _find_empty_floor_spot(used_spots, floor_pts)
		pet.position   = spot
		used_spots.append(spot)
		pet.set("standalone_anim", p.get("standalone_anim", ""))
		pet.set("cat_name", p.get("cat_name", p["name"]))
		var bed_name: String = p.get("bed_item", "")
		pet.set("bed_node",      _room.get_item(bed_name) if bed_name != "" else null)
		pet.set("food_bowl",     _room.get_item("FoodBowl"))
		pet.set("water_bowl",    _room.get_item("WaterBowl"))
		pet.set("_floor_center", _room.center_world)
		pet.visible = true
		add_child(pet)
		pet_nodes.append(pet)
		_pet_nodes.append(pet)

	for pet in pet_nodes:
		var others: Array = pet_nodes.filter(func(o): return o != pet)
		pet.set("_other_pets", others)
		pet.clicked.connect(_hud.show_pet)

func _process(delta: float) -> void:
	if _hold_active and not _edit_mode:
		_hold_timer += delta
		if _hold_timer >= _HOLD_THRESHOLD:
			_hold_active = false
			_hold_timer  = 0.0
			_hud.enter_edit_mode()
			var bag_names := _room.placed_item_ids() if _room else []
			var bag_rtex  : String = _room_data.get("room_texture", "")
			_hud.open_bag(bag_names, bag_rtex)
			call_deferred("_try_start_drag", _hold_pos)

	for i in min(_pet_nodes.size(), _pet_labels.size()):
		var pet := _pet_nodes[i]
		if not is_instance_valid(pet): continue
		var h := float(pet.get("hunger"))
		var t := float(pet.get("thirst"))
		var e := float(pet.get("energy"))
		_pet_labels[i].text = pet.name + "  H:%.0f%%  T:%.0f%%  E:%.0f%%" % [h * 100, t * 100, e * 100]
		if not _hunger_dragging[i]:
			_hunger_sliders[i].set_value_no_signal(h)
		if not _thirst_dragging[i]:
			_thirst_sliders[i].set_value_no_signal(t)
		if not _energy_dragging[i]:
			_energy_sliders[i].set_value_no_signal(e)

# ── Pet placement ─────────────────────────────────────────────────────────────

func _find_empty_floor_spot(used: Array[Vector2], floor_pts: PackedVector2Array) -> Vector2:
	var candidates: Array[Vector2] = [
		Vector2(  0.0,  75.0), Vector2(-60.0,  90.0), Vector2( 60.0,  90.0),
		Vector2(  0.0, 130.0), Vector2(-100.0, 90.0), Vector2(100.0,  90.0),
		Vector2(-30.0,  55.0), Vector2( 30.0,  55.0), Vector2(  0.0, 110.0),
	]
	for candidate in candidates:
		if not floor_pts.is_empty() and not Geometry2D.is_point_in_polygon(candidate, floor_pts):
			continue
		var world_pos := _room.to_global(candidate)
		var ok := true
		for item_name in _room.item_names():
			var node := _room.get_item(item_name) as Node2D
			if node and candidate.distance_to(node.position) < 50.0:
				ok = false
				break
		if not ok: continue
		for prev in used:
			if world_pos.distance_to(prev) < 50.0:
				ok = false
				break
		if ok: return world_pos
	return _room.to_global(Vector2(0.0, 75.0))

# ── Shop purchase handlers ────────────────────────────────────────────────────

func _on_room_purchased(texture_path: String) -> void:
	if not _room: return
	var spr := _room.get_node_or_null("Layer_room") as Sprite2D
	if spr and texture_path != "":
		spr.texture = load(texture_path)
	_room_data["room_texture"] = texture_path
	_save_room_data()

func _on_place_item(item_data: Dictionary) -> void:
	if not _room: return
	var scene_path : String = item_data.get("scene", "")
	if scene_path == "" or not ResourceLoader.exists(scene_path): return

	var node := (load(scene_path) as PackedScene).instantiate() as Node2D
	node.name = item_data["id"]
	node.set_meta("item_id", item_data["id"])

	if item_data.has("script") and item_data["script"] != "":
		node.set_script(load(item_data["script"]))

	if item_data.has("texture"):
		for child in node.get_children():
			if child is Sprite2D:
				(child as Sprite2D).texture = load(item_data["texture"])
				break

	var scene_name : String = item_data.get("sceneName", "")
	var og_def : Dictionary = _room._object_grid.get(scene_name, {})
	var gw := int(og_def.get("w", 1))
	var gd := int(og_def.get("d", 1))
	var gh := int(og_def.get("h", 0))
	var gsurf : String = item_data.get("preferred_surface", "floor")
	node.set_meta("grid_w", gw)
	node.set_meta("grid_d", gd)
	node.set_meta("grid_h", gh)
	node.set_meta("place_offset", Vector2.ZERO)
	if gsurf != "":
		node.set_meta("preferred_surface", gsurf)

	node.name = item_data["id"]
	_room.add_child(node)
	_room.register_item(node.name, node)
	node.position = _room._center.position

	# Add entry to room_data so _save_room_data() will persist it
	var entry := {
		"name":         node.name,
		"scene":        scene_path,
		"sceneName":    scene_name,
		"grid_col":     0,
		"grid_row":     0,
		"grid_surface": gsurf,
		"position":     [0.0, 0.0]
	}
	if item_data.has("script") and item_data["script"] != "":
		entry["script"] = item_data["script"]
	if item_data.has("texture"):
		entry["texture"] = item_data["texture"]
	_room_data["items"].append(entry)

	# Enter edit mode and begin dragging the new item.
	# Defer _dragging_item setup by one frame so the Buy button's mouse-up event
	# doesn't immediately trigger _end_drag() via _unhandled_input.
	_pending_item      = node
	_pending_item_data = item_data
	if not _edit_mode:
		_hud.enter_edit_mode()
	call_deferred("_start_pending_drag", node, gw, gd, gh, gsurf)

func _start_pending_drag(node: Node2D, gw: int, gd: int, gh: int, gsurf: String) -> void:
	_dragging_item       = node
	_drag_offset         = Vector2.ZERO
	_drag_w              = gw
	_drag_d              = gd
	_drag_h              = gh
	_drag_foot_offset    = _collision_center(node)
	_drag_origin_surface = ""
	_drag_origin_col     = -1
	_drag_origin_row     = -1
	_drag_preferred_surf = gsurf
	if _drag_canvas:
		var ctf     := get_viewport().get_canvas_transform()
		var item_vp := ctf * _room.to_global(node.position)
		_drag_offset_canvas = Vector2.ZERO
		node.reparent(_drag_canvas, false)
		node.position = item_vp
		_drag_in_canvas = true
	_set_item_collision(node, false)
	_drag_base_scale = Vector2(absf(node.scale.x), node.scale.y)
	if _drag_in_canvas:
		node.scale *= _zoom_level

# ── Edit mode ─────────────────────────────────────────────────────────────────

func _set_edit_mode(enabled: bool) -> void:
	_edit_mode = enabled
	if _room and _room.grid_system:
		if _room._grid_overlay:
			_room._grid_overlay.visible = enabled
	if not enabled and _dragging_item:
		_end_drag()

# ── Item drag & drop ──────────────────────────────────────────────────────────

func _lift_to_canvas(item: Node2D, world_start: Vector2) -> void:
	if not _drag_canvas: return
	var ctf         := get_viewport().get_canvas_transform()
	var item_vp     := ctf * _room.to_global(item.position)
	_drag_offset_canvas = item_vp - ctf * world_start
	item.reparent(_drag_canvas, false)
	item.position   = item_vp
	item.scale      *= _zoom_level
	_drag_in_canvas = true

func _lower_from_canvas() -> void:
	if not _drag_in_canvas or not _dragging_item: return
	var ctf       := get_viewport().get_canvas_transform()
	var world_pos := ctf.affine_inverse() * _dragging_item.position
	_dragging_item.reparent(_room, false)
	_dragging_item.position = _room.to_local(world_pos)
	_dragging_item.scale    = _drag_base_scale
	_drag_in_canvas = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_positions[event.index] = event.position
			_active_touches += 1
			if _active_touches == 2:
				var vals := _touch_positions.values()
				_pinch_distance = (vals[0] as Vector2).distance_to(vals[1])
			else:
				_pan_distance   = 0.0
				_is_panning     = false
				_pinch_distance = 0.0
		else:
			_touch_positions.erase(event.index)
			_active_touches = max(0, _active_touches - 1)
			if _active_touches == 0:
				_is_panning     = false
				_pan_distance   = 0.0
				_pinch_distance = 0.0

	# Manual pinch zoom via two-finger ScreenDrag (iOS doesn't always fire MagnifyGesture)
	if event is InputEventScreenDrag and _active_touches == 2:
		_touch_positions[event.index] = event.position
		if _pinch_distance > 0.0 and _touch_positions.size() == 2:
			var vals     := _touch_positions.values()
			var new_dist := (vals[0] as Vector2).distance_to(vals[1])
			var factor   := new_dist / _pinch_distance
			_pinch_distance = new_dist
			_zoom_level = clamp(_zoom_level * factor, ZOOM_MIN, ZOOM_MAX)
			_camera.zoom = Vector2(_zoom_level, _zoom_level)
			_clamp_camera()
		get_viewport().set_input_as_handled()
		return

	# Trackpad pinch (Mac)
	if event is InputEventMagnifyGesture:
		_zoom_level = clamp(_zoom_level * event.factor, ZOOM_MIN, ZOOM_MAX)
		_camera.zoom = Vector2(_zoom_level, _zoom_level)
		_clamp_camera()
		get_viewport().set_input_as_handled()
		return

	var _can_pan := not _dragging_item and not _edit_mode and not _hold_active
	var _is_pan  := false
	if event is InputEventScreenDrag and _can_pan and _active_touches == 1:
		_pan_distance += event.relative.length()
		if _pan_distance >= PAN_THRESHOLD: _is_panning = true
		_is_pan = _is_panning
	elif event is InputEventMouseMotion and _can_pan \
			and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_pan_distance += event.relative.length()
		if _pan_distance >= PAN_THRESHOLD: _is_panning = true
		_is_pan = _is_panning
	if _is_pan:
		_camera.position -= event.relative / _zoom_level
		_clamp_camera()
		_hold_active = false
		_hold_timer  = 0.0
		get_viewport().set_input_as_handled()
		return
	if not _dragging_item: return
	if event is InputEventMouseMotion:
		if _drag_in_canvas:
			_dragging_item.position = get_viewport().get_mouse_position() + _drag_offset_canvas + Vector2(0, -80)
			var world := get_viewport().get_canvas_transform().affine_inverse() * _dragging_item.position
			_update_drag_highlight(_room.to_local(world) + _drag_foot_offset)
		else:
			var lp := _room.to_local(event.global_position)
			_dragging_item.position = lp + _drag_offset
			_update_drag_highlight(_dragging_item.position + _drag_foot_offset)
	elif event is InputEventScreenDrag:
		if _drag_in_canvas:
			_dragging_item.position = event.position + _drag_offset_canvas + Vector2(0, -80)
			var world := get_viewport().get_canvas_transform().affine_inverse() * _dragging_item.position
			_update_drag_highlight(_room.to_local(world) + _drag_foot_offset)
		else:
			var lp := _room.to_local(event.position)
			_dragging_item.position = lp + _drag_offset
			_update_drag_highlight(_dragging_item.position + _drag_foot_offset)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_end_drag()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	var gpos: Vector2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		gpos = get_viewport().get_canvas_transform().affine_inverse() * event.position
		if event.pressed:
			if _edit_mode:
				_try_start_drag(gpos)
			elif _room:
				var lp := _room.to_local(gpos)
				if _item_exists_at(lp):
					_hold_active = true
					_hold_timer  = 0.0
					_hold_pos    = gpos
		else:
			_hold_active = false
			_hold_timer  = 0.0
	elif event is InputEventScreenTouch:
		gpos = get_viewport().get_canvas_transform().affine_inverse() * event.position
		if _active_touches > 1:
			_hold_active = false
			return
		if event.pressed:
			if _edit_mode:
				_try_start_drag(gpos)
			elif _room:
				var lp := _room.to_local(gpos)
				if _item_exists_at(lp):
					_hold_active = true
					_hold_timer  = 0.0
					_hold_pos    = gpos
		else:
			_hold_active = false
			_hold_timer  = 0.0

func _item_exists_at(local_pos: Vector2) -> bool:
	if not _room: return false
	var gs := _room.grid_system
	for item_name in _room.item_names():
		var node := _room.get_item(item_name) as Node2D
		if node and _sprite_hit(node, local_pos): return true
	if gs:
		for item_name in _room.item_names():
			var node := _room.get_item(item_name) as Node2D
			if not node or not node.has_meta("grid_surface"): continue
			var quad := gs.cell_quad(
				str(node.get_meta("grid_surface")),
				int(node.get_meta("grid_col")),
				int(node.get_meta("grid_row")),
				int(node.get_meta("grid_w", 1)),
				int(node.get_meta("grid_h", 1)))
			if Geometry2D.is_point_in_polygon(local_pos, quad): return true
	return false

func _apply_wall_flip(item: Node2D, surface: String) -> void:
	item.scale.x = -_drag_base_scale.x if surface == "wall_left" else _drag_base_scale.x

func _set_item_collision(item: Node2D, enabled: bool) -> void:
	for shape in item.find_children("*", "CollisionShape2D", true, false):
		(shape as CollisionShape2D).disabled = not enabled

func _try_start_drag(global_pos: Vector2) -> void:
	if not _room: return
	var gs        := _room.grid_system
	var local_pos := _room.to_local(global_pos)
	var best : Node2D = null

	# Primary: click anywhere on the item's visible sprite
	for item_name in _room.item_names():
		var node := _room.get_item(item_name) as Node2D
		if not node: continue
		if _sprite_hit(node, local_pos):
			best = node
			break

	# Fallback: footprint quad (items with no sprite)
	if not best and gs:
		for item_name in _room.item_names():
			var node := _room.get_item(item_name) as Node2D
			if not node: continue
			if not node.has_meta("grid_surface"): continue
			var quad := gs.cell_quad(
				str(node.get_meta("grid_surface")),
				int(node.get_meta("grid_col")),
				int(node.get_meta("grid_row")),
				int(node.get_meta("grid_w", 1)),
				int(node.get_meta("grid_h", 1)))
			if Geometry2D.is_point_in_polygon(local_pos, quad):
				best = node
				break

	if not best: return

	_dragging_item    = best
	_drag_offset      = best.position - local_pos
	_drag_w           = int(best.get_meta("grid_w", 1))
	_drag_d           = int(best.get_meta("grid_d", 1))
	_drag_h           = int(best.get_meta("grid_h", 0))
	_drag_foot_offset = _collision_center(best)

	if gs:
		var og := gs.get_item_grid(best)
		if not og.is_empty():
			_drag_origin_surface = og["surface"]
			_drag_origin_col     = og["col"]
			_drag_origin_row     = og["row"]
			_drag_preferred_surf = _drag_origin_surface
			gs.remove_item(best)
		else:
			_drag_origin_surface = ""
			_drag_origin_col     = -1
			_drag_origin_row     = -1
			_drag_preferred_surf = str(best.get_meta("preferred_surface", ""))

	_drag_base_scale = Vector2(absf(_dragging_item.scale.x), _dragging_item.scale.y)
	_lift_to_canvas(_dragging_item, global_pos)
	_set_item_collision(_dragging_item, false)

func _snap_drag_item(local_pos: Vector2) -> void:
	var gs   := _room.grid_system
	if not gs: return
	var rows := _drag_d if _drag_d > 0 else _drag_h
	var hit  := gs.local_to_cell_topleft(local_pos, _drag_w, rows, _drag_preferred_surf)
	if hit.is_empty():
		_dragging_item.position = local_pos
	else:
		_dragging_item.position = gs.cell_to_local(hit["surface"], hit["col"], hit["row"], _drag_w, rows)

func _update_drag_highlight(local_pos: Vector2) -> void:
	var gs   := _room.grid_system
	if not gs: return
	var rows := _drag_d if _drag_d > 0 else _drag_h
	var hit  := gs.local_to_cell_topleft(local_pos, _drag_w, rows, _drag_preferred_surf)
	if hit.is_empty():
		_room.clear_highlight()
		return
	var surf  : String = hit["surface"]
	var col   : int    = hit["col"]
	var row   : int    = hit["row"]
	var is_wall_item := _drag_d == 0 and _drag_h > 0
	var surf_ok      := (is_wall_item and surf != "floor") or \
						(not is_wall_item and (_drag_preferred_surf == "" or surf == _drag_preferred_surf))
	var valid := gs.can_place(surf, col, row, _drag_w, _drag_d, _drag_h, _dragging_item) and surf_ok

	if is_wall_item:
		_apply_wall_flip(_dragging_item, surf)

	var quads : Array = [gs.cell_quad(surf, col, row, _drag_w, rows)]

	# Show wall contact cells if floor item is against a wall
	if surf == "floor" and _drag_h > 0:
		if row == 0:
			var wr := gs.surface_rows("wall_right")
			if wr > 0:
				quads.append(gs.cell_quad("wall_right", col, wr - _drag_h, _drag_w, _drag_h))
		if col == 0:
			var wr := gs.surface_rows("wall_left")
			if wr > 0:
				quads.append(gs.cell_quad("wall_left", row, wr - _drag_h, _drag_d, _drag_h))

	_room.set_highlight(quads, valid)

func _end_drag() -> void:
	if not _dragging_item: return
	_room.clear_highlight()
	_lower_from_canvas()
	_set_item_collision(_dragging_item, true)

	# Drop onto bag panel → return item to bag
	if _hud.is_bag_panel_hovered(get_viewport().get_mouse_position()):
		var is_pending := _dragging_item == _pending_item
		var item_name  := _dragging_item.name
		var items : Array = _room_data.get("items", [])
		_room_data["items"] = items.filter(func(e): return e.get("name", "") != item_name)
		_room.unregister_item(item_name)
		_dragging_item.queue_free()
		_dragging_item       = null
		_drag_origin_surface = ""
		_drag_origin_col     = -1
		_drag_origin_row     = -1
		_drag_preferred_surf = ""
		if is_pending:
			_pending_item      = null
			_pending_item_data = {}
		_save_room_data()
		_hud.exit_edit_mode()
		var bag_names_r := _room.placed_item_ids() if _room else []
		var bag_rtex_r  : String = _room_data.get("room_texture", "")
		_hud.open_bag(bag_names_r, bag_rtex_r)
		return

	var gs   := _room.grid_system
	var rows := _drag_d if _drag_d > 0 else _drag_h
	var placed := false
	if gs:
		var lp  := _dragging_item.position + _drag_foot_offset
		var hit := gs.local_to_cell_topleft(lp, _drag_w, rows, _drag_preferred_surf)
		if not hit.is_empty():
			var surf : String = hit["surface"]
			var col  : int    = hit["col"]
			var row  : int    = hit["row"]
			var is_wall    := _drag_d == 0 and _drag_h > 0
			var surface_ok := (is_wall and surf != "floor") or \
							  (not is_wall and (_drag_preferred_surf == "" or surf == _drag_preferred_surf))
			if surface_ok and gs.can_place(surf, col, row, _drag_w, _drag_d, _drag_h, _dragging_item):
				gs.place_item(_dragging_item, surf, col, row, _drag_w, _drag_d, _drag_h)
				_dragging_item.position -= _drag_foot_offset
				placed = true

	if not placed:
		if _dragging_item == _pending_item:
			# New bag item failed to place → remove from room, send back to bag
			var item_name := _dragging_item.name
			var items : Array = _room_data.get("items", [])
			_room_data["items"] = items.filter(func(e): return e.get("name", "") != item_name)
			_room.unregister_item(item_name)
			_dragging_item.queue_free()
			_dragging_item       = null
			_pending_item        = null
			_pending_item_data   = {}
			_drag_origin_surface = ""
			_drag_origin_col     = -1
			_drag_origin_row     = -1
			_drag_preferred_surf = ""
			_save_room_data()
			_hud.exit_edit_mode()
			var bag_names_f := _room.placed_item_ids() if _room else []
			var bag_rtex_f  : String = _room_data.get("room_texture", "")
			_hud.open_bag(bag_names_f, bag_rtex_f)
			return
		elif gs and _drag_origin_surface != "":
			gs.place_item(_dragging_item, _drag_origin_surface,
				_drag_origin_col, _drag_origin_row, _drag_w, _drag_d, _drag_h)
			_dragging_item.position -= _drag_foot_offset
			if _drag_d == 0 and _drag_h > 0:
				_apply_wall_flip(_dragging_item, _drag_origin_surface)

	_save_room_data()
	var was_pending := _dragging_item == _pending_item and placed
	_dragging_item       = null
	_drag_origin_surface = ""
	_drag_origin_col     = -1
	_drag_origin_row     = -1
	_drag_preferred_surf = ""
	_hud.exit_edit_mode()
	var bag_names : Array  = _room.placed_item_ids() if _room else []
	var bag_rtex  : String = _room_data.get("room_texture", "")
	if was_pending:
		_pending_item      = null
		_pending_item_data = {}
		_hud.open_bag(bag_names, bag_rtex)
	else:
		_hud.refresh_bag(bag_names, bag_rtex)

func _save_room_data() -> void:
	var gs := _room.grid_system if _room else null
	for i in _room_data.get("items", []).size():
		var entry : Dictionary = _room_data["items"][i]
		var node := _room.get_item(entry["name"]) as Node2D
		if not node: continue
		entry["position"] = [snappedf(node.position.x, 0.001), snappedf(node.position.y, 0.001)]
		entry["scale_x"]  = snappedf(node.scale.x, 0.001)
		if gs and node.has_meta("grid_surface"):
			entry["grid_col"]     = int(node.get_meta("grid_col"))
			entry["grid_row"]     = int(node.get_meta("grid_row"))
			entry["grid_surface"] = str(node.get_meta("grid_surface"))
		_room_data["items"][i] = entry
	var abs_path := ProjectSettings.globalize_path(room_data_path)
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if not file: return
	file.store_string(JSON.stringify(_room_data, "  "))
	file.close()

# ── Debug UI ──────────────────────────────────────────────────────────────────

func _build_debug_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	# Small arrow toggle button in top-right corner
	var toggle := Button.new()
	toggle.text = "▶"
	toggle.flat = true
	toggle.custom_minimum_size = Vector2(24, 24)
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.anchor_left   = 1.0
	toggle.anchor_right  = 1.0
	toggle.anchor_top    = 0.0
	toggle.anchor_bottom = 0.0
	toggle.offset_left   = -32.0
	toggle.offset_top    = 8.0
	toggle.offset_right  = -8.0
	toggle.offset_bottom = 32.0
	layer.add_child(toggle)

	# Panel starts hidden
	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_right  = -8.0
	panel.offset_top    = 40.0
	panel.grow_horizontal = 0
	panel.visible = false
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	toggle.pressed.connect(func():
		panel.visible = not panel.visible
		toggle.text = "◀" if panel.visible else "▶")

	var max_btn := Button.new()
	max_btn.text = "Max $"
	max_btn.pressed.connect(func():
		DataManager.add_coins(999999)
		DataManager.add_gems(9999))
	vbox.add_child(max_btn)

	var reset_bag_btn := Button.new()
	reset_bag_btn.text = "Reset Bag"
	reset_bag_btn.pressed.connect(func():
		DataManager.reset_inventory()
		_room_data["items"] = []
		_save_room_data()
		get_tree().reload_current_scene())
	vbox.add_child(reset_bag_btn)

	var anims := [
		"idle","idle3","idle4","idle6",
		"walk_side","walk_down","walk_up",
		"eat",
		"sleep","sofull","— reset —",
	]
	for anim in anims:
		var btn := Button.new()
		btn.text = anim
		btn.custom_minimum_size = Vector2(90, 24)
		btn.add_theme_font_size_override("font_size", 11)
		var a: String = anim if anim != "— reset —" else ""
		btn.pressed.connect(func(): _force_all_pets(a))
		vbox.add_child(btn)

	call_deferred("_build_stats_ui", vbox)

func _build_stats_ui(vbox: VBoxContainer) -> void:
	vbox.add_child(HSeparator.new())

	var title := Label.new()
	title.text = "STATS"
	title.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title)

	for i in _pet_nodes.size():
		var pet := _pet_nodes[i]

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(lbl)
		_pet_labels.append(lbl)

		var h_row := HBoxContainer.new()
		var h_lbl := Label.new()
		h_lbl.text = "H"
		h_lbl.add_theme_font_size_override("font_size", 10)
		h_row.add_child(h_lbl)
		var h_slider := HSlider.new()
		h_slider.min_value = 0.0
		h_slider.max_value = 1.0
		h_slider.step      = 0.01
		h_slider.custom_minimum_size = Vector2(78, 20)
		h_slider.value = float(pet.get("hunger"))
		h_row.add_child(h_slider)
		vbox.add_child(h_row)
		_hunger_sliders.append(h_slider)
		_hunger_dragging.append(false)

		var t_row := HBoxContainer.new()
		var t_lbl := Label.new()
		t_lbl.text = "T"
		t_lbl.add_theme_font_size_override("font_size", 10)
		t_row.add_child(t_lbl)
		var t_slider := HSlider.new()
		t_slider.min_value = 0.0
		t_slider.max_value = 1.0
		t_slider.step      = 0.01
		t_slider.custom_minimum_size = Vector2(78, 20)
		t_slider.value = float(pet.get("thirst"))
		t_row.add_child(t_slider)
		vbox.add_child(t_row)
		_thirst_sliders.append(t_slider)
		_thirst_dragging.append(false)

		var e_row := HBoxContainer.new()
		var e_lbl := Label.new()
		e_lbl.text = "E"
		e_lbl.add_theme_font_size_override("font_size", 10)
		e_row.add_child(e_lbl)
		var e_slider := HSlider.new()
		e_slider.min_value = 0.0
		e_slider.max_value = 1.0
		e_slider.step      = 0.01
		e_slider.custom_minimum_size = Vector2(78, 20)
		e_slider.value = float(pet.get("energy"))
		e_row.add_child(e_slider)
		vbox.add_child(e_row)
		_energy_sliders.append(e_slider)
		_energy_dragging.append(false)

		var idx := i
		h_slider.drag_started.connect(func(): _hunger_dragging[idx] = true)
		h_slider.drag_ended.connect(func(_c): _hunger_dragging[idx] = false)
		h_slider.value_changed.connect(func(v: float): _set_pet_hunger(idx, v))

		t_slider.drag_started.connect(func(): _thirst_dragging[idx] = true)
		t_slider.drag_ended.connect(func(_c): _thirst_dragging[idx] = false)
		t_slider.value_changed.connect(func(v: float): _set_pet_thirst(idx, v))

		e_slider.drag_started.connect(func(): _energy_dragging[idx] = true)
		e_slider.drag_ended.connect(func(_c): _energy_dragging[idx] = false)
		e_slider.value_changed.connect(func(v: float): _set_pet_energy(idx, v))

func _set_pet_hunger(idx: int, v: float) -> void:
	var pet := _pet_nodes[idx]
	if not is_instance_valid(pet): return
	pet.set("hunger", v)
	pet.set("_move_dir",     Vector2.ZERO)
	pet.set("_wander_timer", 0.0)

func _set_pet_thirst(idx: int, v: float) -> void:
	var pet := _pet_nodes[idx]
	if not is_instance_valid(pet): return
	pet.set("thirst", v)
	pet.set("_move_dir",     Vector2.ZERO)
	pet.set("_wander_timer", 0.0)

func _set_pet_energy(idx: int, v: float) -> void:
	var pet := _pet_nodes[idx]
	if not is_instance_valid(pet): return
	pet.set("energy", v)
	pet.set("_move_dir",     Vector2.ZERO)
	pet.set("_wander_timer", 0.0)

func _force_all_pets(anim: String) -> void:
	for pet in _pet_nodes:
		if not pet: continue
		if anim == "sleep" and pet.has_method("force_anim"):
			pet.force_anim("sleep_prepare")
			var p := pet
			get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(p): p.force_anim("sleeping"))
			get_tree().create_timer(6.0).timeout.connect(func():
				if is_instance_valid(p): p.force_anim("sleep_done"))
		elif anim == "eat" and pet.has_method("eat"):
			pet.eat()
			var p := pet
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(p) and p.has_method("stop_eat"):
					p.stop_eat())
		elif anim == "drink" and pet.has_method("drink"):
			pet.drink()
			var p := pet
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(p) and p.has_method("stop_drink"):
					p.stop_drink())
		elif pet.has_method("force_anim"):
			pet.force_anim(anim)

# ── Util ──────────────────────────────────────────────────────────────────────

# Returns true if room_local_pos falls inside any Sprite2D child of item.
func _sprite_hit(item: Node2D, room_local_pos: Vector2) -> bool:
	const PAD := 1.0
	for child in item.get_children():
		if not child is Sprite2D: continue
		var spr := child as Sprite2D
		if not spr.texture: continue
		var tex_size   := spr.texture.get_size()
		var vis_center := item.position + spr.position + spr.offset * spr.scale
		var half       := tex_size * spr.scale / 2.0 + Vector2(PAD, PAD)
		var size       := tex_size * spr.scale + Vector2(PAD * 2.0, PAD * 2.0)
		if Rect2(vis_center - half, size).has_point(room_local_pos):
			return true
	return false

func _collision_center(item: Node2D) -> Vector2:
	for child in item.get_children():
		if child is CollisionShape2D:
			return (child as CollisionShape2D).position
	return Vector2.ZERO

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out
