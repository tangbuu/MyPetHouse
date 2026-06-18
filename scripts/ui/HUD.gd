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

var _edit_mode : bool = false

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

func is_bag_panel_hovered(vp_pos: Vector2) -> bool:
	if not _bag_panel.visible: return false
	var bg := _bag_panel.get_node_or_null("BgPanel") as Control
	if not bg: return false
	return bg.get_global_rect().has_point(vp_pos)

func _on_coins_changed(amount: int) -> void:
	_coin_label.text = str(amount)

func _on_gems_changed(amount: int) -> void:
	_gem_label.text = str(amount)
