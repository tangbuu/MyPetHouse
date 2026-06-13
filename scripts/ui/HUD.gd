extends CanvasLayer

@onready var feed_btn: Button  = $Panel/Margin/VBox/Buttons/FeedBtn
@onready var pet_btn: Button   = $Panel/Margin/VBox/Buttons/PetBtn
@onready var sleep_btn: Button = $Panel/Margin/VBox/Buttons/SleepBtn

func _ready() -> void:
	feed_btn.pressed.connect(GameManager.feed)
	pet_btn.pressed.connect(GameManager.pet_action)
	sleep_btn.pressed.connect(_on_sleep_pressed)

func _on_sleep_pressed() -> void:
	GameManager.toggle_sleep()
	sleep_btn.text = "⏰ Wake" if GameManager.is_sleeping else "💤 Sleep"
