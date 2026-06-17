extends CanvasLayer

signal closed
signal item_purchased(item_data: Dictionary)
signal room_purchased(texture_path: String)

const SHOP_DATA_PATH := "res://data/shop.json"

const _C_LEFT_BG       := Color(0.83, 0.56, 0.43, 1.0)
const _C_TAB_ACTIVE    := Color(0.96, 0.87, 0.78, 1.0)
const _C_TAB_TEXT      := Color(0.29, 0.16, 0.08, 1.0)
const _C_SUBTAB_ACTIVE := Color(0.78, 0.58, 0.42, 1.0)
const _C_CARD_BG       := Color(0.90, 0.76, 0.64, 1.0)
const _C_ICON_BG       := Color(0.84, 0.68, 0.55, 1.0)
const _C_BUY_BTN       := Color(0.68, 0.45, 0.28, 1.0)
const _C_OWNED_BTN     := Color(0.55, 0.55, 0.55, 1.0)

const _FONT = preload("res://assets/fonts/Jersey_25/Jersey25-Regular.ttf")
const _COIN = preload("res://assets/UI/icons/coin_icon.png")
const _GEM  = preload("res://assets/UI/icons/gem_icon.png")

var _shop_data    : Dictionary = {}
var _active_main  : int = 0
var _active_sub   : int = 0
var _sub_btn_list : Array[Button] = []
var _sort_asc     : bool = true

@onready var _sort_btn   : Button        = $BgPanel/MainHBox/RightMargin/RightVBox/TopBar/SortBtn
@onready var _coin_label : Label         = $BgPanel/MainHBox/RightMargin/RightVBox/TopBar/CoinRow/CoinLabel
@onready var _gem_label  : Label         = $BgPanel/MainHBox/RightMargin/RightVBox/TopBar/GemRow/GemLabel
@onready var _sub_bar    : HBoxContainer = $BgPanel/MainHBox/RightMargin/RightVBox/SubTabScroll/SubTabBar
@onready var _item_grid  : GridContainer = $BgPanel/MainHBox/RightMargin/RightVBox/Scroll/GridMargin/ItemGrid
@onready var _main_btns  : Array[Button] = [
	$BgPanel/MainHBox/LeftCol/LeftVBox/ItemsBtn  as Button,
	$BgPanel/MainHBox/LeftCol/LeftVBox/OffersBtn as Button,
	$BgPanel/MainHBox/LeftCol/LeftVBox/TopupBtn  as Button,
]

func _ready() -> void:
	_load_shop_data()
	_sort_btn.pressed.connect(_on_sort_pressed)
	_style_sort_btn()
	$Overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_close())
	for i in _main_btns.size():
		var idx := i
		_main_btns[i].pressed.connect(func(): _set_main_tab(idx))
	_build_sub_tabs()
	_set_main_tab(0)
	visible = false

func _on_sort_pressed() -> void:
	_sort_asc = not _sort_asc
	_sort_btn.text = "↑ Price" if _sort_asc else "↓ Price"
	_refresh_grid()

func _style_sort_btn() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = _C_BUY_BTN
	s.set_corner_radius_all(6)
	s.border_width_top = 2; s.border_width_right = 2
	s.border_width_bottom = 2; s.border_width_left = 2
	s.border_color = Color(0.52, 0.30, 0.14, 1.0)
	s.content_margin_left = 8.0; s.content_margin_right = 8.0
	s.content_margin_top = 3.0; s.content_margin_bottom = 3.0
	_sort_btn.add_theme_stylebox_override("normal",  s)
	_sort_btn.add_theme_stylebox_override("hover",   s)
	_sort_btn.add_theme_stylebox_override("pressed", s)
	_sort_btn.add_theme_font_override("font", _FONT)
	_sort_btn.add_theme_font_size_override("font_size", 13)
	_sort_btn.add_theme_color_override("font_color",         Color.WHITE)
	_sort_btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	_sort_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_sort_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _load_shop_data() -> void:
	var file := FileAccess.open(SHOP_DATA_PATH, FileAccess.READ)
	if not file: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		_shop_data = data

func open() -> void:
	_coin_label.text = str(DataManager.coins)
	_gem_label.text  = str(DataManager.gems)
	_refresh_grid()
	visible = true

func _on_close() -> void:
	visible = false
	closed.emit()

# ── Sub-tab building ──────────────────────────────────────────────────────────

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

# ── Tab logic ─────────────────────────────────────────────────────────────────

func _set_main_tab(idx: int) -> void:
	_active_main = idx
	_refresh_main_tabs()
	_sub_bar.get_parent().visible = (idx == 0)
	_clear_grid()
	if idx == 0:
		_set_sub_tab(_active_sub)

func _set_sub_tab(idx: int) -> void:
	_active_sub = idx
	_refresh_sub_tabs()
	_refresh_grid()

func _refresh_main_tabs() -> void:
	for i in _main_btns.size():
		var btn    := _main_btns[i]
		var active := i == _active_main
		var s := StyleBoxFlat.new()
		s.bg_color = _C_TAB_ACTIVE if active else _C_LEFT_BG
		s.set_corner_radius_all(8)
		s.border_width_top = 2; s.border_width_bottom = 2
		s.border_width_left = 2; s.border_width_right = 2
		s.border_color = Color(0.62, 0.37, 0.24, 1.0)
		s.content_margin_left = 0.0; s.content_margin_right = 0.0
		s.content_margin_top = 0.0; s.content_margin_bottom = 0.0
		btn.add_theme_stylebox_override("normal",  s)
		btn.add_theme_stylebox_override("hover",   s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_color_override("font_color",         _C_TAB_TEXT)
		btn.add_theme_color_override("font_hover_color",   _C_TAB_TEXT)
		btn.add_theme_color_override("font_pressed_color", _C_TAB_TEXT)
		btn.add_theme_font_override("font", _FONT)
		btn.add_theme_font_size_override("font_size", 15)

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
	var items : Array = cat.get("items", []).filter(func(item) -> bool:
		var stock : int = item.get("stock", -1)
		return not (stock != -1 and DataManager.owned_items.count(item.get("id", "")) >= stock))
	items.sort_custom(func(a, b) -> bool:
		return a.get("price", 0) < b.get("price", 0) if _sort_asc \
			else a.get("price", 0) > b.get("price", 0))
	for item in items:
		_item_grid.add_child(_make_card(item, cat))

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
	card.custom_minimum_size = Vector2(85, 155)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Image root — wrapper để overlay badge số lượng
	var img_root := Control.new()
	img_root.custom_minimum_size = Vector2(0, 80)
	img_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(img_root)

	var tex_wrap := PanelContainer.new()
	tex_wrap.anchor_right  = 1.0
	tex_wrap.anchor_bottom = 1.0
	var ts := StyleBoxFlat.new()
	ts.bg_color = _C_ICON_BG
	ts.set_corner_radius_all(6)
	tex_wrap.add_theme_stylebox_override("panel", ts)
	img_root.add_child(tex_wrap)

	if item.has("texture") and ResourceLoader.exists(item["texture"]):
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(item["texture"])
		tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex_rect.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		tex_wrap.add_child(tex_rect)

	# Badge số lượng còn lại (chỉ với item có giới hạn)
	var stock : int = item.get("stock", -1)
	if stock != -1:
		var owned_cnt : int = DataManager.owned_items.count(item.get("id", ""))
		var remaining : int = stock - owned_cnt
		if remaining >= 1:
			var cnt_lbl := Label.new()
			cnt_lbl.text = "x%d" % remaining
			cnt_lbl.anchor_left   = 1.0
			cnt_lbl.anchor_top    = 1.0
			cnt_lbl.anchor_right  = 1.0
			cnt_lbl.anchor_bottom = 1.0
			cnt_lbl.offset_left   = -26.0
			cnt_lbl.offset_top    = -16.0
			cnt_lbl.offset_right  = -2.0
			cnt_lbl.offset_bottom = -2.0
			cnt_lbl.add_theme_font_override("font", _FONT)
			cnt_lbl.add_theme_font_size_override("font_size", 11)
			cnt_lbl.add_theme_color_override("font_color", Color.WHITE)
			cnt_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
			cnt_lbl.add_theme_constant_override("shadow_offset_x", 1)
			cnt_lbl.add_theme_constant_override("shadow_offset_y", 1)
			img_root.add_child(cnt_lbl)

	# Name label
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", _FONT)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", _C_TAB_TEXT)
	vbox.add_child(name_lbl)

	# Buy button
	vbox.add_child(_make_buy_btn(item, cat))
	return card

func _make_buy_btn(item: Dictionary, cat: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = _C_BUY_BTN
	s.set_corner_radius_all(6)
	s.border_width_top = 2; s.border_width_right = 2
	s.border_width_bottom = 2; s.border_width_left = 2
	s.border_color = Color(0.52, 0.30, 0.14, 1.0)
	s.content_margin_left = 8.0; s.content_margin_right = 8.0
	s.content_margin_top = 3.0; s.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", s)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	panel.add_child(hbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(14, 14)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _COIN if item.get("currency", "coin") == "coin" else _GEM
	hbox.add_child(icon)

	var price_lbl := Label.new()
	price_lbl.text = str(item.get("price", 0))
	price_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_lbl.add_theme_font_override("font", _FONT)
	price_lbl.add_theme_font_size_override("font_size", 13)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	hbox.add_child(price_lbl)

	var buy_lbl := Label.new()
	buy_lbl.text = "Buy"
	buy_lbl.add_theme_font_override("font", _FONT)
	buy_lbl.add_theme_font_size_override("font_size", 13)
	buy_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	hbox.add_child(buy_lbl)

	panel.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			return
		_on_buy(item, cat, panel))

	return panel

func _on_buy(item: Dictionary, cat: Dictionary, btn_panel: Control) -> void:
	var price    : int    = item.get("price", 0)
	var currency : String = item.get("currency", "coin")
	var ok := DataManager.spend_coins(price) if currency == "coin" else DataManager.spend_gems(price)
	if not ok: return

	DataManager.own_item(item["id"])
	_coin_label.text = str(DataManager.coins)
	_gem_label.text  = str(DataManager.gems)

	# Fade out → in toàn bộ card, rồi refresh
	var card := btn_panel.get_parent().get_parent() as Control
	if not card: _refresh_grid(); return
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 0.35, 0.25)
	tw.tween_property(card, "modulate:a", 1.0,  0.25)
	tw.tween_callback(func(): _refresh_grid())
