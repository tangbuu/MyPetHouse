extends CanvasLayer

signal edit_mode_toggled(enabled: bool)
signal item_purchased(item_data: Dictionary)
signal room_purchased(texture_path: String)
signal bag_btn_pressed
signal place_item(item_data: Dictionary)

@onready var _player_name_label : Label  = $StatsWidget/Row/RightCol/PlayerName
@onready var _level_label       : Label  = $StatsWidget/Row/RightCol/LevelLabel
@onready var _datetime_label    : Label  = $StatsWidget/Row/RightCol/DateTimeLabel
@onready var _shop_btn          : Button = $BottomButtons/ShopBtn
@onready var _bag_btn           : Button = $BottomButtons/BagBtn
@onready var _shop_panel                 = $ShopPanel
@onready var _bag_panel                  = $BagPanel
@onready var _coin_label        : Label  = $CurrencyContainer/CoinWidget/CoinPanel/CoinContent/CoinAmount
@onready var _gem_label         : Label  = $CurrencyContainer/GemWidget/GemPanel/GemContent/GemAmount

var _edit_mode    : bool          = false
var _bag_drop_zone : PanelContainer = null

func _ready() -> void:
	_shop_btn.pressed.connect(_on_shop_btn)
	_bag_btn.pressed.connect(_on_bag_btn)
	DataManager.coins_changed.connect(_on_coins_changed)
	DataManager.gems_changed.connect(_on_gems_changed)
	_coin_label.text = str(DataManager.coins)
	_gem_label.text  = str(DataManager.gems)
	_shop_panel.room_purchased.connect(func(p): room_purchased.emit(p))
	_bag_panel.room_selected.connect(func(p): room_purchased.emit(p))
	_bag_panel.place_item.connect(func(d): place_item.emit(d))
	_player_name_label.text = DataManager.player_name
	_level_label.text       = "Lv.%d" % DataManager.player_level
	_build_bag_drop_zone()

func _process(_delta: float) -> void:
	_datetime_label.text = DataManager.game_time_string()

func _on_shop_btn() -> void:
	_shop_panel.open()

func _on_bag_btn() -> void:
	bag_btn_pressed.emit()

func open_bag(placed_names: Array, room_texture: String = "") -> void:
	_bag_panel.open(placed_names, room_texture)

func refresh_bag(placed_names: Array, room_texture: String = "") -> void:
	if _bag_panel.visible:
		_bag_panel.open(placed_names, room_texture)

func enter_edit_mode() -> void:
	if not _edit_mode:
		_set_edit_active(true)

func exit_edit_mode() -> void:
	if _edit_mode:
		_set_edit_active(false)

func show_shop() -> void:
	_shop_panel.open()

func _set_edit_active(enabled: bool) -> void:
	_edit_mode = enabled
	edit_mode_toggled.emit(_edit_mode)
	if _bag_drop_zone:
		_bag_drop_zone.visible = enabled

func is_bag_open() -> bool:
	return _bag_panel.visible

func close_bag() -> void:
	_bag_panel.visible = false

func is_bag_panel_hovered(vp_pos: Vector2) -> bool:
	if _bag_drop_zone and _bag_drop_zone.visible \
			and _bag_drop_zone.get_global_rect().has_point(vp_pos):
		return true
	if not _bag_panel.visible: return false
	var bg := _bag_panel.get_node_or_null("BgPanel") as Control
	if not bg: return false
	return bg.get_global_rect().has_point(vp_pos)

func set_bag_drop_highlight(on: bool) -> void:
	if not _bag_drop_zone: return
	var style := _bag_drop_zone.get_theme_stylebox("panel") as StyleBoxFlat
	if not style: return
	style.border_color = Color(1.0, 0.85, 0.2, 1.0) if on else Color(0.85, 0.65, 0.2, 1.0)
	style.bg_color     = Color(0.25, 0.18, 0.04, 0.95) if on else Color(0.12, 0.08, 0.04, 0.88)

func _build_bag_drop_zone() -> void:
	_bag_drop_zone = PanelContainer.new()
	_bag_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor to right edge, 75% down (= 1/4 from bottom)
	_bag_drop_zone.anchor_left   = 1.0
	_bag_drop_zone.anchor_right  = 1.0
	_bag_drop_zone.anchor_top    = 0.75
	_bag_drop_zone.anchor_bottom = 0.75
	_bag_drop_zone.offset_left   = -104.0
	_bag_drop_zone.offset_right  = -12.0
	_bag_drop_zone.offset_top    = -44.0
	_bag_drop_zone.offset_bottom = 44.0
	_bag_drop_zone.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color               = Color(0.12, 0.08, 0.04, 0.88)
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.65, 0.2, 1.0)
	_bag_drop_zone.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	var icon_lbl := Label.new()
	icon_lbl.text = "BAG"
	icon_lbl.add_theme_font_size_override("font_size", 14)
	icon_lbl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = "drop here"
	hint_lbl.add_theme_font_size_override("font_size", 9)
	hint_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5, 0.8))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_lbl)
	_bag_drop_zone.add_child(vbox)
	add_child(_bag_drop_zone)

func _on_coins_changed(amount: int) -> void:
	_coin_label.text = str(amount)

func _on_gems_changed(amount: int) -> void:
	_gem_label.text = str(amount)
