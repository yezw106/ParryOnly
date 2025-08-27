extends CanvasLayer

@onready var parry_label: Label = $ParryLabel
@onready var start_screen: Control = $StartScreen
@onready var game_over_screen: Control = $GameOverScreen
@onready var start_button: Button = $StartScreen/StartButton
@onready var retry_button: Button = $GameOverScreen/RetryButton

var parry_count := 0

func _ready():
	# 默认显示开始界面
	start_screen.visible = true
	game_over_screen.visible = false
	parry_label.visible = false
	
	start_button.pressed.connect(_on_start_pressed)
	retry_button.pressed.connect(_on_retry_pressed)

func _on_start_pressed():
	start_screen.visible = false
	parry_label.visible = true
	parry_count = 0
	update_parry_label()
	get_tree().call_group("game", "start_game")

func _on_retry_pressed():
	get_tree().reload_current_scene()

func update_parry_label():
	parry_label.text = "Parry: %d" % parry_count

func add_parry():
	parry_count += 1
	update_parry_label()

func show_game_over():
	game_over_screen.visible = true
