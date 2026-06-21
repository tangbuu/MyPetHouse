extends Node2D

@export var room_data_path: String = "res://data/rooms/room_1.json"

@onready var _bg  : ColorRect     = $BG
@onready var _hud : CanvasLayer   = $HUD

var _room_data : Dictionary  = {}
var _room      : Room        = null
var _room_brightness : float = 1.0
var _bg_sprite     : Sprite2D    = null
var _night_overlay     : ColorRect      = null
var _night_shader      : ShaderMaterial = null
var _sunset_overlay     : ColorRect      = null
var _sunset_max_alpha   : float          = 0.10
var _rain_overlay  : ColorRect      = null
var _rain_shader   : ShaderMaterial = null
var _rain_player   : AudioStreamPlayer = null
var _music_player  : AudioStreamPlayer = null
var _bg_layer      : CanvasLayer    = null
var _base_light_radius  : float = 0.23
var _light_y_offset     : float = -60.0
var _light_x_offset     : float = 1.0
var _light_intensity    : float = 1.0
var _iso_shear          : float = 0.15
var _edge_feather       : float = 1.0
# Fixed evening ambient — no day/night cycle
var _evening_alpha : float = 0.5

var _dbg_prefs    : Dictionary = {}
const _DBG_PREFS_PATH := "user://debug_prefs.json"
var _dbg_panel    : Control  = null
var _dbg_dragging : bool     = false
var _dbg_drag_off : Vector2  = Vector2.ZERO

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
var _drag_bag_was_open  : bool        = false
var _drag_screen_pos    : Vector2     = Vector2.ZERO

# Grid drag state
var _drag_w               : int    = 1
var _drag_d               : int    = 1
var _drag_h               : int    = 0
var _drag_foot_offset     : Vector2 = Vector2.ZERO
var _drag_origin_surface  : String = ""
var _drag_origin_col      : int    = -1
var _drag_origin_row      : int    = -1
var _drag_preferred_surf  : String = ""
var _drag_current_surface : String = ""   # surface đang hover trong khi drag (real-time)

var _camera        : Camera2D = null
var _collision_overlay : Node2D = null
var _cam_origin    : Vector2  = Vector2.ZERO
const DEBUG_GRID   := false   # set true to show grid + zone sliders
const ZOOM_MIN     := 0.8
const ZOOM_MAX     := 2.5
const ZOOM_INIT    := 1.0
var _active_touches  : int        = 0
var _touch_positions : Dictionary = {}
var _pinch_distance  : float      = 0.0
var _is_panning      : bool       = false
var _pan_distance    : float      = 0.0
const PAN_THRESHOLD               := 8.0

var _item_place_counter : int = 0

const _LAMP_PARAMS     := ["light_pos_0", "light_pos_1", "light_pos_2", "light_pos_3"]
const _LAMP_DIR_PARAMS := ["light_dir_0", "light_dir_1", "light_dir_2", "light_dir_3"]
var _vp_size : Vector2 = Vector2.ZERO

var _pet_nodes       : Array[Node2D]  = []
var _pet_labels      : Array[Label]   = []
var _player          : Node2D         = null

func _ready() -> void:
	_vp_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_bg.visible = false   # clear color handles solid bg
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
	_setup_night_overlay()
	_setup_sunset_overlay()
	_setup_rain()
	_setup_music()
	call_deferred("_build_debug_ui")

func _setup_sunset_overlay() -> void:
	# Simple warm color overlay — cam nhạt phủ nhẹ lên toàn scene trong golden hour
	var layer := CanvasLayer.new()
	layer.layer = 2   # under night overlay so lamps still visible on top
	add_child(layer)
	_sunset_overlay = ColorRect.new()
	_sunset_overlay.color = Color(1.0, 0.55, 0.15, 0.0)
	_sunset_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sunset_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sunset_overlay.size = _vp_size
	layer.add_child(_sunset_overlay)

func _setup_night_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3   # above blue hour (layer 2) and rain (layer 1)
	add_child(layer)
	_night_overlay = ColorRect.new()
	_night_overlay.color = Color(1, 1, 1, 1)  # driven entirely by shader
	_night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_overlay.size = _vp_size
	_night_shader = ShaderMaterial.new()
	_night_shader.shader = load("res://shaders/night_overlay.gdshader")
	_night_overlay.material = _night_shader
	layer.add_child(_night_overlay)
	# Static shader params — only update on change, not every frame
	_night_shader.set_shader_parameter("viewport_size",  _vp_size)
	_night_shader.set_shader_parameter("light_intensity", _light_intensity)
	_night_shader.set_shader_parameter("iso_shear",       _iso_shear)
	_night_shader.set_shader_parameter("edge_feather",    _edge_feather)

func _setup_rain() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1   # above world (room), below night overlay (layer 2)
	add_child(layer)
	_rain_overlay = ColorRect.new()
	_rain_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain_overlay.size = _vp_size
	_rain_shader = ShaderMaterial.new()
	_rain_shader.shader = load("res://shaders/rain.gdshader")
	_rain_overlay.material = _rain_shader
	layer.add_child(_rain_overlay)

	_rain_player = AudioStreamPlayer.new()
	var stream := load("res://assets/audio/rain_loop.mp3") as AudioStream
	if stream:
		(_rain_player as AudioStreamPlayer).stream = stream
		_rain_player.volume_db = _opacity_to_db(0.13)
		_rain_player.autoplay = true
		add_child(_rain_player)
		# Loop the stream
		var playback := _rain_player.get_stream_playback()
		_rain_player.finished.connect(func(): _rain_player.play())

func _opacity_to_db(opacity: float) -> float:
	# rain_opacity 0.0→silence, 0.5→full; map to -20db→6db
	return lerp(-20.0, 6.0, clampf(opacity / 0.5, 0.0, 1.0))

func _setup_music() -> void:
	const MUSIC_PATH := "res://assets/audio/music_loop.mp3"
	if not ResourceLoader.exists(MUSIC_PATH): return
	_music_player = AudioStreamPlayer.new()
	_music_player.stream   = load(MUSIC_PATH)
	_music_player.volume_db = -18.0
	_music_player.autoplay  = true
	add_child(_music_player)
	_music_player.finished.connect(func(): _music_player.play())

func _setup_camera() -> void:
	_camera = Camera2D.new()
	_cam_origin = _vp_size / 2.0
	_camera.position = _cam_origin
	_camera.zoom = Vector2(ZOOM_INIT, ZOOM_INIT)
	add_child(_camera)
	_camera.make_current()

func _clamp_camera() -> void:
	var z  := _camera.zoom.x
	# Image half-size in world units (852×1846 at scale 0.8, room_scale ~1)
	var ihx := 852.0 * 0.8 / 2.0   # 340.8
	var ihy := 1846.0 * 0.8 / 2.0  # 738.4
	var lx  := maxf(0.0, ihx - _vp_size.x  / (2.0 * z))
	var ly  := maxf(0.0, ihy - _vp_size.y / (2.0 * z))
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
	# Sync counter so new placements don't collide with loaded instance names
	for item : Dictionary in _room_data.get("items", []):
		var n : String = item.get("name", "")
		var idx := n.rfind("_i")
		if idx >= 0:
			var num := n.substr(idx + 2).to_int()
			if num > _item_place_counter:
				_item_place_counter = num
	_build(_room_data)
	if _room and _room._grid_overlay:
		_room._grid_overlay.visible = DEBUG_GRID

func _build(data: Dictionary) -> void:
	# ── Background ──
	var bg_img: String = data.get("background_image", "")
	if bg_img != "" and ResourceLoader.exists(bg_img):
		if not _bg_sprite:
			_bg_sprite          = Sprite2D.new()
			_bg_sprite.centered = true
			_bg_sprite.z_index  = -100
			add_child(_bg_sprite)
		_bg_sprite.texture  = load(bg_img)
		var tex_size        := _bg_sprite.texture.get_size()
		var s               := maxf(_vp_size.x / tex_size.x, _vp_size.y / tex_size.y) * 1.0
		_bg_sprite.scale    = Vector2(s, s)
		_bg_sprite.position = _vp_size * 0.5
		_bg_sprite.visible  = true
	else:
		if _bg_sprite: _bg_sprite.visible = false

	# ── Room (sprite, furniture, items, walls) ──
	if _room:
		_room.queue_free()
	_room = (load("res://scenes/Room.tscn") as PackedScene).instantiate()
	_room.name = "Room"
	add_child(_room)
	_room.build(data)
	_room_brightness = data.get("room_brightness", 0.70)

	# ── Pets ──
	var floor_pts := _pts(data.get("zones", {}).get("floor", []))
	var used_spots : Array[Vector2] = []
	var pet_nodes  : Array[Node2D]  = []

	for p: Dictionary in data.get("pets", []):
		var pet      := (load(p["scene"]) as PackedScene).instantiate()
		pet.name      = p["name"]
		var spot      := _find_empty_floor_spot(used_spots, floor_pts)
		pet.position   = _room.to_local(spot)
		used_spots.append(spot)
		pet.set("standalone_anim", p.get("standalone_anim", ""))
		pet.set("cat_name", p.get("cat_name", p["name"]))
		var bed_name: String = p.get("bed_item", "")
		var bed_node: Node = null
		if bed_name != "":
			bed_node = _room.get_item(bed_name)
			if not bed_node:
				bed_node = _room.get_item_by_scene(bed_name)
			if not bed_node:
				bed_node = _room.get_item_by_script(bed_name)
		pet.set("bed_node",   bed_node)
		pet.set("food_bowl",  _room.get_item_by_script("FoodBowl"))
		pet.set("water_bowl", _room.get_item_by_script("WaterBowl"))
		pet.set("_floor_center", _room.center_world)
		pet.set("_floor_poly",   _room.floor_poly_world)
		pet.visible = true
		_room._world.add_child(pet)
		pet_nodes.append(pet)
		_pet_nodes.append(pet)

	for pet in pet_nodes:
		var others: Array = pet_nodes.filter(func(o): return o != pet)
		pet.set("_other_pets", others)

	# ── Player ──
	var player_data : Dictionary = data.get("player", {})
	if not player_data.is_empty():
		if _player:
			_player.queue_free()
		_player = (load(player_data.get("scene", "res://scenes/player/Player.tscn")) as PackedScene).instantiate()
		_player.name = "Player"
		_player.position = _v2(player_data.get("position", [0.0, 0.0]))
		_room._world.add_child(_player)
	_apply_room_brightness()

func _process(delta: float) -> void:
	if _night_shader:
		var ctf := get_viewport().get_canvas_transform()
		var t := DataManager.game_time_hours
		var alpha: float
		if t < 5.0:
			alpha = _evening_alpha                                      # still night
		elif t < 7.0:
			alpha = lerpf(_evening_alpha, 0.0, (t - 5.0) / 2.0)       # dawn fade out
		elif t < 18.5:
			alpha = 0.0                                                  # full day
		elif t < 20.0:
			alpha = lerpf(0.0, _evening_alpha, (t - 18.5) / 1.5)      # dusk fade in
		else:
			alpha = _evening_alpha                                      # full night
		_night_shader.set_shader_parameter("overlay_color", Color(0.03, 0.04, 0.16, alpha))
		# Scale light radius with canvas zoom so the glow stays the same world-space size
		_night_shader.set_shader_parameter("light_radius_norm", _base_light_radius * ctf.x.length())
		var lamps := WallLamp.all_lamps
		for i in 4:
			var lamp_uv  := Vector2(-9.0, -9.0)
			var wall_dir := 0.0
			if i < lamps.size():
				var lamp := lamps[i] as Node2D
				if lamp and lamp.is_inside_tree() and (lamp as WallLamp).is_on:
					var wl := lamp as WallLamp
					if _dragging_item == lamp and _drag_current_surface != "":
						match _drag_current_surface:
							"wall_left":  wall_dir =  1.0
							"wall_right": wall_dir = -1.0
							_:            wall_dir =  0.0
					else:
						wall_dir = wl.get_wall_dir()
					lamp_uv = (ctf * (lamp.global_position + Vector2(_light_x_offset * wall_dir, _light_y_offset))) / _vp_size
			_night_shader.set_shader_parameter(_LAMP_PARAMS[i],     lamp_uv)
			_night_shader.set_shader_parameter(_LAMP_DIR_PARAMS[i], wall_dir)

	if _sunset_overlay:
		var _t := DataManager.game_time_hours
		# Fade in 15h → peak 17h (alpha max) → fade out 19h
		var s_alpha := 0.0
		if _t >= 15.0 and _t < 17.0:
			s_alpha = lerpf(0.0, _sunset_max_alpha, (_t - 15.0) / 2.0)
		elif _t >= 17.0 and _t < 19.0:
			s_alpha = lerpf(_sunset_max_alpha, 0.0, (_t - 17.0) / 2.0)
		# Color shifts: pale amber (early) → deep orange (peak) → dim orange (late)
		var warm_r := lerpf(1.0,  1.0,  s_alpha / _sunset_max_alpha) if _sunset_max_alpha > 0 else 1.0
		var warm_g := lerpf(0.72, 0.45, clampf((_t - 15.0) / 4.0, 0.0, 1.0))
		var warm_b := lerpf(0.28, 0.10, clampf((_t - 15.0) / 4.0, 0.0, 1.0))
		_sunset_overlay.color = Color(warm_r, warm_g, warm_b, s_alpha)

	_hud.set_bag_drop_highlight(_dragging_item != null and _hud.is_bag_panel_hovered(_drag_screen_pos))

	if _hold_active and not _edit_mode:
		_hold_timer += delta
		if _hold_timer >= _HOLD_THRESHOLD:
			_hold_active = false
			_hold_timer  = 0.0
			if not _hold_pos_is_permanent(_hold_pos):
				_hud.enter_edit_mode()
				call_deferred("_try_start_drag", _hold_pos)

	for i in min(_pet_nodes.size(), _pet_labels.size()):
		var pet := _pet_nodes[i]
		if not is_instance_valid(pet): continue
		var new_text := pet.name
		if _pet_labels[i].text != new_text:
			_pet_labels[i].text = new_text

# ── Pet placement ─────────────────────────────────────────────────────────────

func _find_empty_floor_spot(used: Array[Vector2], floor_pts: PackedVector2Array) -> Vector2:
	var candidates: Array[Vector2] = [
		Vector2(  0.0,  75.0), Vector2(-60.0,  90.0), Vector2( 60.0,  90.0),
		Vector2(  0.0, 130.0), Vector2(-100.0, 90.0), Vector2(100.0,  90.0),
		Vector2(-30.0,  55.0), Vector2( 30.0,  55.0), Vector2(  0.0, 110.0),
	]
	candidates.shuffle()
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

	# Assign a unique instance name before add_child to avoid Godot auto-renaming
	_item_place_counter += 1
	var inst_name : String = str(item_data["id"]) + "_i" + str(_item_place_counter)
	node.name = inst_name
	_room._world.add_child(node)
	_room.register_item(inst_name, node)
	node.position = _room._center.position

	# Add entry to room_data so _save_room_data() will persist it
	var entry := {
		"name":         inst_name,
		"id":           item_data["id"],
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
	_drag_bag_was_open = true
	_hud.close_bag()
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
		node.scale *= _camera.zoom.x

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
	item.scale      *= _camera.zoom.x
	_drag_in_canvas = true

func _lower_from_canvas() -> void:
	if not _drag_in_canvas or not _dragging_item: return
	var ctf       := get_viewport().get_canvas_transform()
	var world_pos := ctf.affine_inverse() * _dragging_item.position
	_dragging_item.reparent(_room._world, false)
	_dragging_item.position = _room.to_local(world_pos)
	_dragging_item.scale    = _drag_base_scale
	_drag_in_canvas = false

func _input(event: InputEvent) -> void:
	# Debug panel drag (highest priority)
	if _dbg_dragging and event is InputEventMouseMotion:
		_dbg_panel.position = get_viewport().get_mouse_position() + _dbg_drag_off
		get_viewport().set_input_as_handled()
		return

	# Capture bag state here — _input fires before gui_input (backdrop close) and _unhandled_input.
	if not _dragging_item:
		if (event is InputEventScreenTouch and event.pressed and _active_touches == 0) \
				or (event is InputEventMouseButton and event.pressed \
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
			_drag_bag_was_open = _hud.is_bag_open()

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
			var nz : float = clamp(_camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
			_camera.zoom = Vector2(nz, nz)
			_clamp_camera()
		get_viewport().set_input_as_handled()
		return

	# Trackpad pinch (Mac)
	if event is InputEventMagnifyGesture:
		var nz : float = clamp(_camera.zoom.x * event.factor, ZOOM_MIN, ZOOM_MAX)
		_camera.zoom = Vector2(nz, nz)
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
		_camera.position -= event.relative / _camera.zoom.x
		_clamp_camera()
		_hold_active = false
		_hold_timer  = 0.0
		get_viewport().set_input_as_handled()
		return
	if not _dragging_item: return
	if event is InputEventMouseMotion:
		_drag_screen_pos = get_viewport().get_mouse_position()
		if _drag_in_canvas:
			_dragging_item.position = _drag_screen_pos + _drag_offset_canvas + Vector2(0, -80)
			var world := get_viewport().get_canvas_transform().affine_inverse() * _dragging_item.position
			_update_drag_highlight(_room.to_local(world) + _drag_foot_offset)
		else:
			var lp := _room.to_local(event.global_position)
			_dragging_item.position = lp + _drag_offset
			_update_drag_highlight(_dragging_item.position + _drag_foot_offset)
	elif event is InputEventScreenDrag:
		_drag_screen_pos = event.position
		if _drag_in_canvas:
			_dragging_item.position = _drag_screen_pos + _drag_offset_canvas + Vector2(0, -80)
			var world := get_viewport().get_canvas_transform().affine_inverse() * _dragging_item.position
			_update_drag_highlight(_room.to_local(world) + _drag_foot_offset)
		else:
			var lp := _room.to_local(event.position)
			_dragging_item.position = lp + _drag_offset
			_update_drag_highlight(_dragging_item.position + _drag_foot_offset)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drag_screen_pos = event.position
		_end_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_drag_screen_pos = event.position
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
			_drag_screen_pos = event.position
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

func _hold_pos_is_permanent(global_pos: Vector2) -> bool:
	if not _room: return false
	var local_pos := _room.to_local(global_pos)
	for item_name in _room.item_names():
		var node := _room.get_item(item_name) as Node2D
		if not node: continue
		if _sprite_hit(node, local_pos):
			return _room_data.get("items", []).any(func(e): return e.get("name","") == node.name and e.get("permanent", false))
	return false

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

	# Block drag on permanent fixtures (door, window, etc.)
	var _items_arr : Array = _room_data.get("items", [])
	var _is_perm := _items_arr.any(func(e): return e.get("name","") == best.name and e.get("permanent", false))
	if _is_perm: return

	if _drag_bag_was_open:
		_hud.close_bag()

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
		_drag_current_surface = surf

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
	_hud.set_bag_drop_highlight(false)
	_lower_from_canvas()
	_set_item_collision(_dragging_item, true)
	var bag_was_open := _drag_bag_was_open
	_drag_bag_was_open = false

	# Drop onto bag panel → return item to bag (skip if permanent)
	if _hud.is_bag_panel_hovered(_drag_screen_pos):
		var item_name  := _dragging_item.name
		var items_arr  : Array = _room_data.get("items", [])
		var is_perm    := items_arr.any(func(e): return e.get("name","") == item_name and e.get("permanent", false))
		if is_perm:
			# Put it back to original grid position and abort
			var gs2 := _room.grid_system
			if gs2 and _drag_origin_surface != "":
				gs2.place_item(_dragging_item, _drag_origin_surface, _drag_origin_col, _drag_origin_row, _drag_w, _drag_d, _drag_h)
				_dragging_item.position -= _drag_foot_offset
			_dragging_item = null; _drag_origin_surface = ""; _drag_origin_col = -1
			_drag_origin_row = -1; _drag_preferred_surf = ""; _drag_current_surface = ""
			_hud.exit_edit_mode()
			return
		var is_pending := _dragging_item == _pending_item
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
		if bag_was_open:
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
				if _drag_d == 0 and _drag_h > 0:
					_apply_wall_flip(_dragging_item, surf)
				placed = true

	if not placed:
		if _dragging_item == _pending_item:
			# New bag item failed to place → remove from room, send back to bag
			var item_name := _dragging_item.name
			var items : Array = _room_data.get("items", [])
			_room_data["items"] = items.filter(func(e): return e.get("name", "") != item_name)
			_room.unregister_item(item_name)
			_dragging_item.queue_free()
			_dragging_item        = null
			_pending_item         = null
			_pending_item_data    = {}
			_drag_current_surface = ""
			_drag_origin_surface  = ""
			_drag_origin_col      = -1
			_drag_origin_row      = -1
			_drag_preferred_surf  = ""
			_save_room_data()
			_hud.exit_edit_mode()
			if bag_was_open:
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
	_dragging_item        = null
	_drag_current_surface = ""
	_drag_origin_surface  = ""
	_drag_origin_col      = -1
	_drag_origin_row      = -1
	_drag_preferred_surf  = ""
	_hud.exit_edit_mode()
	if was_pending:
		_pending_item      = null
		_pending_item_data = {}
	if bag_was_open:
		var bag_names : Array  = _room.placed_item_ids() if _room else []
		var bag_rtex  : String = _room_data.get("room_texture", "")
		_hud.open_bag(bag_names, bag_rtex)

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

func _on_viewport_size_changed() -> void:
	_vp_size = get_viewport().get_visible_rect().size
	if _night_overlay:
		_night_overlay.size = _vp_size
	if _rain_overlay:
		_rain_overlay.size = _vp_size
	if _night_shader:
		_night_shader.set_shader_parameter("viewport_size", _vp_size)

# ── Debug UI ──────────────────────────────────────────────────────────────────

func _load_debug_prefs() -> void:
	if not FileAccess.file_exists(_DBG_PREFS_PATH): return
	var f := FileAccess.open(_DBG_PREFS_PATH, FileAccess.READ)
	if not f: return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary: _dbg_prefs = d

func _save_debug_prefs() -> void:
	var f := FileAccess.open(_DBG_PREFS_PATH, FileAccess.WRITE)
	if not f: return
	f.store_string(JSON.stringify(_dbg_prefs, "\t"))
	f.close()

func _build_debug_ui() -> void:
	# Load saved prefs and apply to runtime state
	_load_debug_prefs()
	_evening_alpha = _dbg_prefs.get("night_max", 0.5)
	_sunset_max_alpha = _dbg_prefs.get("sunset_alpha", 0.10)
	if _rain_shader:
		var ro : float = _dbg_prefs.get("rain_opacity", 0.13)
		_rain_shader.set_shader_parameter("rain_opacity", ro)
		if _rain_player: _rain_player.volume_db = _opacity_to_db(ro)

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	# Draggable panel — positioned freely (no anchors)
	var panel := PanelContainer.new()
	panel.position = Vector2(
		_dbg_prefs.get("panel_x", _vp_size.x - 210.0),
		_dbg_prefs.get("panel_y", 40.0))
	layer.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 2)
	panel.add_child(root_vbox)

	# ── Title / drag bar ──
	var title_row := HBoxContainer.new()
	root_vbox.add_child(title_row)

	var drag_lbl := Label.new()
	drag_lbl.text = "≡  Debug"
	drag_lbl.add_theme_font_size_override("font_size", 12)
	drag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drag_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_lbl.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_row.add_child(drag_lbl)

	var collapse_btn := Button.new()
	collapse_btn.text = "▼"
	collapse_btn.flat = true
	collapse_btn.custom_minimum_size = Vector2(22, 20)
	collapse_btn.add_theme_font_size_override("font_size", 11)
	title_row.add_child(collapse_btn)

	# Collapsible content area
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	root_vbox.add_child(content)

	# Drag logic — motion handled in _input() for reliable viewport coords
	_dbg_panel = panel
	drag_lbl.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			_dbg_dragging = ev.pressed
			if ev.pressed:
				_dbg_drag_off = _dbg_panel.position - get_viewport().get_mouse_position()
			else:
				_dbg_prefs["panel_x"] = _dbg_panel.position.x
				_dbg_prefs["panel_y"] = _dbg_panel.position.y
				_save_debug_prefs())

	collapse_btn.pressed.connect(func():
		content.visible = not content.visible
		collapse_btn.text = "▶" if not content.visible else "▼"
		if is_instance_valid(_player):
			_player.set_process(content.visible)
			_player.set_physics_process(content.visible))

	# Helper: slider that auto-saves value to prefs
	var dbg_slider := func(label: String, min_v: float, max_v: float, step_v: float,
			key: String, default_v: float, fmt: String, setter: Callable) -> void:
		_add_shader_slider(content, label, min_v, max_v, step_v,
			float(_dbg_prefs.get(key, default_v)), fmt,
			func(v: float):
				setter.call(v)
				_dbg_prefs[key] = v
				_save_debug_prefs())

	# ── Content ──
	var max_btn := Button.new()
	max_btn.text = "Max $"
	max_btn.pressed.connect(func():
		DataManager.add_coins(999999)
		DataManager.add_gems(9999))
	content.add_child(max_btn)

	content.add_child(HSeparator.new())
	var time_lbl := Label.new()
	time_lbl.text = "Time: " + DataManager.game_time_string()
	time_lbl.add_theme_font_size_override("font_size", 11)
	content.add_child(time_lbl)
	var time_slider := HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = 24.0
	time_slider.step      = 0.25
	time_slider.custom_minimum_size = Vector2(90, 20)
	time_slider.value = DataManager.game_time_hours
	time_slider.value_changed.connect(func(v: float):
		DataManager.game_time_hours = v
		time_lbl.text = "Time: " + DataManager.game_time_string())
	content.add_child(time_slider)

	dbg_slider.call("Night Max", 0.0, 1.0, 0.01, "night_max", 0.5, "%.2f",
		func(v: float): _evening_alpha = v)
	dbg_slider.call("Rain", 0.0, 0.5, 0.01, "rain_opacity", 0.13, "%.2f",
		func(v: float):
			if _rain_shader: _rain_shader.set_shader_parameter("rain_opacity", v)
			if _rain_player: _rain_player.volume_db = _opacity_to_db(v))
	content.add_child(HSeparator.new())
	dbg_slider.call("Sunset", 0.0, 0.3, 0.005, "sunset_alpha", 0.10, "%.3f",
		func(v: float): _sunset_max_alpha = v)

	# Zone vertex tuning — controlled by DEBUG_GRID flag
	if DEBUG_GRID:
		content.add_child(HSeparator.new())
		var _fz : Array = _room_data.get("zones", {}).get("floor", [[-2,84],[-287,241],[11,408],[292,242]])
		var _wz : Array = _room_data.get("zones", {}).get("wall",  [[-1,-164],[294,-20],[292,242],[-2,84],[-287,241],[-288,-14]])
		var _set_zone := func():
			_wz[2] = [_fz[3][0], _fz[3][1]]
			_wz[3] = [_fz[0][0], _fz[0][1]]
			_wz[4] = [_fz[1][0], _fz[1][1]]
			_room_data["zones"] = {"floor": _fz, "wall": _wz}
			_rebuild_grid()
			_save_room_data()
		_add_shader_slider(content, "F TopX",   -600.0, 600.0, 1.0, _fz[0][0], "%d", func(v:float): _fz[0][0]=v; _set_zone.call())
		_add_shader_slider(content, "F TopY",   -300.0, 800.0, 1.0, _fz[0][1], "%d", func(v:float): _fz[0][1]=v; _set_zone.call())
		_add_shader_slider(content, "F LeftX",  -600.0, 0.0,   1.0, _fz[1][0], "%d", func(v:float): _fz[1][0]=v; _set_zone.call())
		_add_shader_slider(content, "F LeftY",   0.0,   800.0, 1.0, _fz[1][1], "%d", func(v:float): _fz[1][1]=v; _set_zone.call())
		_add_shader_slider(content, "F FrontX", -600.0, 600.0, 1.0, _fz[2][0], "%d", func(v:float): _fz[2][0]=v; _set_zone.call())
		_add_shader_slider(content, "F FrontY",  0.0,   900.0, 1.0, _fz[2][1], "%d", func(v:float): _fz[2][1]=v; _set_zone.call())
		_add_shader_slider(content, "F RightX",  0.0,   600.0, 1.0, _fz[3][0], "%d", func(v:float): _fz[3][0]=v; _set_zone.call())
		_add_shader_slider(content, "F RightY",  0.0,   800.0, 1.0, _fz[3][1], "%d", func(v:float): _fz[3][1]=v; _set_zone.call())
		_add_shader_slider(content, "W TopX",   -600.0, 600.0, 1.0, _wz[0][0], "%d", func(v:float): _wz[0][0]=v; _set_zone.call())
		_add_shader_slider(content, "W TopY",   -600.0, 200.0, 1.0, _wz[0][1], "%d", func(v:float): _wz[0][1]=v; _set_zone.call())
		_add_shader_slider(content, "W RTopX",   0.0,   600.0, 1.0, _wz[1][0], "%d", func(v:float): _wz[1][0]=v; _set_zone.call())
		_add_shader_slider(content, "W RTopY",  -400.0, 200.0, 1.0, _wz[1][1], "%d", func(v:float): _wz[1][1]=v; _set_zone.call())
		_add_shader_slider(content, "W LTopX", -600.0,  0.0,   1.0, _wz[5][0], "%d", func(v:float): _wz[5][0]=v; _set_zone.call())
		_add_shader_slider(content, "W LTopY", -400.0,  200.0, 1.0, _wz[5][1], "%d", func(v:float): _wz[5][1]=v; _set_zone.call())

	# Player frame preview
	content.add_child(HSeparator.new())
	var _make_player_slider = func(label: String, max_f: int, tex_path: String, hf: int) -> void:
		var lbl := Label.new()
		lbl.text = label + ": 0"
		lbl.add_theme_font_size_override("font_size", 11)
		content.add_child(lbl)
		var sl := HSlider.new()
		sl.min_value = 0; sl.max_value = max_f; sl.step = 1; sl.value = 0
		sl.custom_minimum_size = Vector2(90, 20)
		sl.value_changed.connect(func(v: float):
			lbl.text = label + ": %d" % int(v)
			if not is_instance_valid(_player): return
			var spr := _player.get_node_or_null("Sprite")
			var shd := _player.get_node_or_null("ShadowSprite")
			if spr == null: return
			_player.set_process(false)
			_player.set_physics_process(false)
			var tex := load(tex_path)
			spr.texture = tex; shd.texture = tex
			spr.hframes = hf;  shd.hframes = hf
			spr.frame = int(v); shd.frame = int(v))
		sl.drag_ended.connect(func(_c: bool):
			if is_instance_valid(_player):
				_player.set_process(true)
				_player.set_physics_process(true))
		content.add_child(sl)
	_make_player_slider.call("Walk Frame", 5, "res://assets/player/player_walk_side_sheet.png", 6)

	var collision_btn := CheckButton.new()
	collision_btn.text = "Show Collisions"
	collision_btn.toggled.connect(func(on: bool):
		if on:
			if not is_instance_valid(_collision_overlay):
				_collision_overlay = load("res://scripts/debug/CollisionDebugOverlay.gd").new()
				if is_instance_valid(_room) and is_instance_valid(_room._world):
					_room._world.add_child(_collision_overlay)
		else:
			if is_instance_valid(_collision_overlay):
				_collision_overlay.queue_free()
				_collision_overlay = null)
	content.add_child(collision_btn)

	var reset_bag_btn := Button.new()
	reset_bag_btn.text = "Reset Bag"
	reset_bag_btn.pressed.connect(func():
		DataManager.reset_inventory()
		var perms : Array = _room_data.get("items", []).filter(func(e): return e.get("permanent", false))
		_room_data["items"] = perms
		_save_room_data()
		get_tree().reload_current_scene())
	content.add_child(reset_bag_btn)

	call_deferred("_build_stats_ui", content)

func _add_shader_slider(vbox: VBoxContainer, label: String,
		min_v: float, max_v: float, step_v: float, init_v: float,
		fmt: String, setter: Callable, shader_param: String = "") -> void:
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = label
	title.add_theme_font_size_override("font_size", 11)
	title.custom_minimum_size = Vector2(46, 0)
	row.add_child(title)
	var val_lbl := Label.new()
	val_lbl.text = fmt % init_v
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.custom_minimum_size = Vector2(32, 0)
	row.add_child(val_lbl)
	vbox.add_child(row)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step      = step_v
	slider.value     = init_v
	slider.custom_minimum_size = Vector2(90, 20)
	slider.value_changed.connect(func(v: float):
		val_lbl.text = fmt % v
		setter.call(v)
		if shader_param != "" and _night_shader:
			_night_shader.set_shader_parameter(shader_param, v))
	vbox.add_child(slider)

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
				if is_instance_valid(p) and p.has_method("on_eat_completed"):
					p.on_eat_completed())
		elif anim == "drink" and pet.has_method("drink"):
			pet.drink()
			var p := pet
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(p) and p.has_method("on_drink_completed"):
					p.on_drink_completed())
		elif pet.has_method("force_anim"):
			pet.force_anim(anim)

func _apply_room_brightness() -> void:
	if not is_instance_valid(_room): return
	var b   := _room_brightness
	var inv := 1.0 / b if b > 0.0 else 1.0
	_room.modulate = Color(b, b, b, 1.0)
	# Compensate img2 (Layer_room) back to original brightness
	var layer_room := _room.get_node_or_null("Layer_room")
	if layer_room:
		(layer_room as CanvasItem).modulate = Color(inv, inv, inv, 1.0)
	# Compensate pets back to original brightness
	for pet in _pet_nodes:
		if is_instance_valid(pet):
			(pet as CanvasItem).modulate = Color(inv, inv, inv, 1.0)

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

func _rebuild_grid() -> void:
	if not is_instance_valid(_room): return
	if _room.grid_system:
		_room.grid_system.setup(_room_data)
	if _room._grid_overlay:
		_room._grid_overlay.call("setup", _room_data)

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out
