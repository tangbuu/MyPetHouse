extends Node2D

@export var room_data_path: String = "res://data/rooms/room_1.json"

@onready var _bg : ColorRect = $BG

var _room_data : Dictionary  = {}
var _room      : Room        = null
var _bg_rect   : TextureRect = null

var _dragging_item : Node2D  = null
var _drag_offset   : Vector2 = Vector2.ZERO

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
	_build_debug_ui()

func _process(_delta: float) -> void:
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

# ── Debug UI ──────────────────────────────────────────────────────────────────

func _build_debug_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.visible  = false
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = "DEBUG ANIM"
	label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(label)

	var anims := [
		"idle","idle2","idle3","idle4","idle5","idle6",
		"walk","tired","cry","sleeping","eat_loop","drink","sofull","— reset —"
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
	pet.set("_idle_timer",   0.0)

func _set_pet_thirst(idx: int, v: float) -> void:
	var pet := _pet_nodes[idx]
	if not is_instance_valid(pet): return
	pet.set("thirst", v)
	pet.set("_move_dir",     Vector2.ZERO)
	pet.set("_wander_timer", 0.0)
	pet.set("_idle_timer",   0.0)

func _set_pet_energy(idx: int, v: float) -> void:
	var pet := _pet_nodes[idx]
	if not is_instance_valid(pet): return
	pet.set("energy", v)
	pet.set("_move_dir",     Vector2.ZERO)
	pet.set("_wander_timer", 0.0)
	pet.set("_idle_timer",   0.0)

func _force_all_pets(anim: String) -> void:
	for pet in _pet_nodes:
		if not pet: continue
		if anim == "drink" and pet.has_method("drink"):
			pet.drink()
			var p := pet
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(p) and p.has_method("stop_drink"):
					p.stop_drink())
		elif pet.has_method("force_anim"):
			pet.force_anim(anim)

# ── Item drag & drop ──────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	var gpos: Vector2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		gpos = event.global_position
		if event.pressed:
			_try_start_drag(gpos)
		else:
			_end_drag()
	elif event is InputEventScreenTouch:
		gpos = event.position
		if event.pressed:
			_try_start_drag(gpos)
		else:
			_end_drag()
	elif event is InputEventMouseMotion and _dragging_item:
		_dragging_item.position = _room.to_local(event.global_position) + _drag_offset
	elif event is InputEventScreenDrag and _dragging_item:
		_dragging_item.position = _room.to_local(event.position) + _drag_offset

func _try_start_drag(global_pos: Vector2) -> void:
	if not _room: return
	var local_pos := _room.to_local(global_pos)
	var best : Node2D = null
	var best_dist := 50.0
	for item_name in _room.item_names():
		var node := _room.get_item(item_name) as Node2D
		if not node: continue
		if node.position.distance_to(local_pos) < best_dist:
			best_dist = node.position.distance_to(local_pos)
			best = node
	if best:
		_dragging_item = best
		_drag_offset   = best.position - local_pos

func _end_drag() -> void:
	if not _dragging_item: return
	_save_item_positions()
	_dragging_item = null

func _save_item_positions() -> void:
	var abs_path := ProjectSettings.globalize_path(room_data_path)
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if not file: return
	var data : Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	for i in data["items"].size():
		var entry : Dictionary = data["items"][i]
		var node := _room.get_item(entry["name"]) as Node2D
		if node:
			entry["position"] = [snappedf(node.position.x, 0.001), snappedf(node.position.y, 0.001)]
			data["items"][i] = entry
	file = FileAccess.open(abs_path, FileAccess.WRITE)
	if not file: return
	file.store_string(JSON.stringify(data, "  "))
	file.close()

# ── Util ──────────────────────────────────────────────────────────────────────

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out
