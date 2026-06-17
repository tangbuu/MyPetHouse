extends CanvasLayer

signal closed
signal room_selected(texture_path: String)
signal place_item(item_data: Dictionary)

const SHOP_DATA_PATH := "res://data/shop.json"

const _C_TAB_TEXT      := Color(0.29, 0.16, 0.08, 1.0)
const _C_SUBTAB_ACTIVE := Color(0.78, 0.58, 0.42, 1.0)
const _C_CARD_BG       := Color(0.90, 0.76, 0.64, 1.0)
const _C_ICON_BG       := Color(0.84, 0.68, 0.55, 1.0)

const _FONT = preload("res://assets/fonts/Jersey_25/Jersey25-Regular.ttf")

var _shop_data          : Dictionary = {}
var _active_sub         : int        = 0
var _sub_btn_list       : Array[Button] = []
var _placed_names       : Array      = []
var _current_room_tex   : String     = ""

@onready var _backdrop   : Control         = $Backdrop
@onready var _sub_scroll : ScrollContainer = $BgPanel/ContentMargin/ContentVBox/SubTabScroll
@onready var _sub_bar    : HBoxContainer   = $BgPanel/ContentMargin/ContentVBox/SubTabScroll/SubTabBar
@onready var _item_grid  : GridContainer   = $BgPanel/ContentMargin/ContentVBox/Scroll/GridMargin/ItemGrid

var _sub_drag_active  := false
var _sub_drag_start_x := 0.0
var _sub_scroll_start := 0

func _ready() -> void:
	_load_shop_data()
	_backdrop.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_close())
	_sub_scroll.gui_input.connect(_on_sub_scroll_input)
	_build_sub_tabs()
	_set_sub_tab(0)
	visible = false

func _on_sub_scroll_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_sub_drag_active  = e.pressed
		_sub_drag_start_x = e.position.x
		_sub_scroll_start = _sub_scroll.scroll_horizontal
	elif e is InputEventMouseMotion and _sub_drag_active:
		_sub_scroll.scroll_horizontal = _sub_scroll_start + int(_sub_drag_start_x - e.position.x)

func _load_shop_data() -> void:
	var file := FileAccess.open(SHOP_DATA_PATH, FileAccess.READ)
	if not file: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		_shop_data = data

func open(placed_names: Array = [], room_texture: String = "") -> void:
	_placed_names     = placed_names
	_current_room_tex = room_texture
	_refresh_grid()
	visible = true

func _on_close() -> void:
	visible = false
	closed.emit()

# ── Sub-tabs ──────────────────────────────────────────────────────────────────

func _build_sub_tabs() -> void:
	for child in _sub_bar.get_children():
		child.queue_free()
	_sub_btn_list.clear()
	var categories : Array = _shop_data.get("categories", [])
	for i in categories.size():
		var cat : Dictionary = categories[i]
		var btn := Button.new()
		btn.text = cat.get("label", "")
		_sub_bar.add_child(btn)
		_sub_btn_list.append(btn)
		var idx := i
		btn.pressed.connect(func(): _set_sub_tab(idx))

func _set_sub_tab(idx: int) -> void:
	_active_sub = idx
	_refresh_sub_tabs()
	_refresh_grid()

func _refresh_sub_tabs() -> void:
	for i in _sub_btn_list.size():
		var btn    := _sub_btn_list[i]
		var active := i == _active_sub
		var s := StyleBoxFlat.new()
		s.bg_color = _C_SUBTAB_ACTIVE if active else Color(0.0, 0.0, 0.0, 0.0)
		s.set_corner_radius_all(6)
		s.border_width_top = 2; s.border_width_right = 2
		s.border_width_bottom = 2; s.border_width_left = 2
		s.border_color = Color(0.52, 0.30, 0.14, 1.0) if active else Color(0.0, 0.0, 0.0, 0.0)
		s.content_margin_left = 14.0; s.content_margin_right = 14.0
		s.content_margin_top = 4.0; s.content_margin_bottom = 4.0
		btn.add_theme_stylebox_override("normal",  s)
		btn.add_theme_stylebox_override("hover",   s)
		btn.add_theme_stylebox_override("pressed", s)
		var font_col := Color(1.0, 1.0, 1.0, 1.0) if active else _C_TAB_TEXT
		btn.add_theme_color_override("font_color",         font_col)
		btn.add_theme_color_override("font_hover_color",   font_col)
		btn.add_theme_color_override("font_pressed_color", font_col)
		btn.add_theme_font_override("font", _FONT)
		btn.add_theme_font_size_override("font_size", 14)

# ── Item grid ─────────────────────────────────────────────────────────────────

func _clear_grid() -> void:
	for child in _item_grid.get_children():
		child.queue_free()

func _refresh_grid() -> void:
	_clear_grid()
	var categories : Array = _shop_data.get("categories", [])
	if _active_sub >= categories.size(): return
	var cat : Dictionary = categories[_active_sub]
	for item in cat.get("items", []):
		if not DataManager.is_owned(item["id"]): continue
		_item_grid.add_child(_make_card(item, cat))

func _placed_count_for(item_id: String) -> int:
	return _placed_names.count(item_id)

func _make_card(item: Dictionary, cat: Dictionary) -> Control:
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = _C_CARD_BG
	cs.set_corner_radius_all(10)
	cs.border_width_top = 2; cs.border_width_right = 2
	cs.border_width_bottom = 2; cs.border_width_left = 2
	cs.border_color = Color(0.52, 0.30, 0.14, 1.0)
	cs.content_margin_left = 6.0; cs.content_margin_right = 6.0
	cs.content_margin_top = 6.0; cs.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size = Vector2(70, 80)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# Image area — plain Control wrapper so count label can be anchored freely
	var img_root := Control.new()
	img_root.custom_minimum_size = Vector2(0, 50)
	img_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img_root.mouse_filter        = Control.MOUSE_FILTER_PASS
	vbox.add_child(img_root)

	var tex_wrap := PanelContainer.new()
	tex_wrap.anchor_right  = 1.0
	tex_wrap.anchor_bottom = 1.0
	tex_wrap.mouse_filter  = Control.MOUSE_FILTER_PASS
	var ts := StyleBoxFlat.new()
	ts.bg_color = _C_ICON_BG
	ts.set_corner_radius_all(6)
	tex_wrap.add_theme_stylebox_override("panel", ts)
	img_root.add_child(tex_wrap)

	if item.has("texture") and ResourceLoader.exists(item["texture"]):
		var tr := TextureRect.new()
		tr.texture               = load(item["texture"])
		tr.expand_mode           = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		tr.mouse_filter          = Control.MOUSE_FILTER_PASS
		tex_wrap.add_child(tr)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", _FONT)
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", _C_TAB_TEXT)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(name_lbl)

	# Quantity logic
	var is_room    : bool = cat.get("type", "") == "room_skin"
	var item_id    : String = item.get("id", "")
	var total      : int = DataManager.owned_items.count(item_id)
	var placed_cnt : int = _placed_count_for(item_id)
	var available  : int = total - placed_cnt
	var is_placed  : bool = (is_room and item.get("texture", "") == _current_room_tex) \
						 or (not is_room and available <= 0)

	# Count badge (x2, x3...) at bottom-right of image
	if not is_room and available >= 2:
		var cnt_lbl := Label.new()
		cnt_lbl.text = "x%d" % available
		cnt_lbl.anchor_left   = 1.0
		cnt_lbl.anchor_top    = 1.0
		cnt_lbl.anchor_right  = 1.0
		cnt_lbl.anchor_bottom = 1.0
		cnt_lbl.offset_left   = -26.0
		cnt_lbl.offset_top    = -16.0
		cnt_lbl.offset_right  = -2.0
		cnt_lbl.offset_bottom = -2.0
		cnt_lbl.mouse_filter  = Control.MOUSE_FILTER_PASS
		cnt_lbl.add_theme_font_override("font", _FONT)
		cnt_lbl.add_theme_font_size_override("font_size", 11)
		cnt_lbl.add_theme_color_override("font_color", Color.WHITE)
		cnt_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
		cnt_lbl.add_theme_constant_override("shadow_offset_x", 1)
		cnt_lbl.add_theme_constant_override("shadow_offset_y", 1)
		img_root.add_child(cnt_lbl)

	if is_placed:
		card.modulate     = Color(1.0, 1.0, 1.0, 0.45)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var merged := item.duplicate()
		merged["scene"]             = item.get("scene",             cat.get("scene", ""))
		merged["sceneName"]         = item.get("sceneName",         cat.get("sceneName", ""))
		merged["preferred_surface"] = item.get("preferred_surface", cat.get("preferred_surface", "floor"))
		if cat.has("script"):
			merged["script"] = cat["script"]

		card.gui_input.connect(func(e: InputEvent) -> void:
			if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
				return
			if is_room:
				_current_room_tex = item.get("texture", "")
				room_selected.emit(_current_room_tex)
				_refresh_grid()
			else:
				place_item.emit(merged)
				_on_close())

	return card
