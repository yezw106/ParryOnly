extends CanvasLayer

@onready var parry_label: Label = $ParryLabel
@onready var start_screen: Control = $StartScreen
@onready var Challenge_screen: Control = $ChallengeMode
@onready var game_over_screen: Control = $GameOverScreen
@onready var start_button: Button = $StartScreen/StartButton
@onready var challenge_button: Button = $ChallengeMode/ChallengeButton
@onready var retry_button: Button = $GameOverScreen/RetryButton

var parry_count := 0
var parry_count_wiz := 0
var parry_count_ea := 0

var normal_win_count = 100
var eagleman_win_count = 30
var wiz_win_count = 20
var end_less_mode_on = true

func _ready():
	# 默认显示开始界面
	$Title.visible = true
	start_screen.visible = true
	game_over_screen.visible = false
	parry_label.visible = false
	$NormalHead.visible = false
	$EaglemanHead.visible = false
	$FireWizardHead.visible = false
	challenge_button.grab_focus()
	start_button.pressed.connect(_on_start_pressed)
	challenge_button.pressed.connect(_on_challenge_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	
func _on_start_pressed():
	$Title.visible = false
	start_screen.visible = false
	Challenge_screen.visible = false
	parry_label.visible = true
	$NormalHead.visible = true
	$EaglemanHead.visible = true
	$FireWizardHead.visible = true
	parry_count = 0
	parry_count_wiz = 0
	parry_count_ea = 0
	end_less_mode_on = true
	update_parry_label()
	get_tree().call_group("game", "start_game")

func _on_challenge_pressed():
	$Title.visible = false
	start_screen.visible = false
	Challenge_screen.visible = false
	parry_label.visible = true
	$NormalHead.visible = true
	$EaglemanHead.visible = true
	$FireWizardHead.visible = true
	parry_count = 0
	parry_count_wiz = 0
	parry_count_ea = 0
	end_less_mode_on = false
	update_parry_label()
	get_tree().call_group("game", "start_game")

func _on_retry_pressed():
	get_tree().reload_current_scene()

func update_parry_label():
	if end_less_mode_on:
		parry_label.text = "        %d               %d                 %d" % [parry_count, parry_count_ea,parry_count_wiz]
	else:
		parry_label.text = "        %d               %d                 %d" % [normal_win_count - parry_count, eagleman_win_count - parry_count_ea,wiz_win_count - parry_count_wiz]
		if normal_win_count - parry_count <= 0 and eagleman_win_count - parry_count_ea <= 0 and wiz_win_count - parry_count_wiz <= 0:
			get_parent().game_win()

func add_parry():
	parry_count += 1
	update_parry_label()

func add_parry_wiz():
	parry_count_wiz += 1
	update_parry_label()

func add_parry_ea():
	parry_count_ea += 1
	update_parry_label()

func show_game_over():
	game_over_screen.get_node("Label").text = "Game Over!"
	game_over_screen.visible = true
	retry_button.grab_focus()

func show_game_win():
	game_over_screen.get_node("Label").text = "通  关!"
	game_over_screen.visible = true
	retry_button.grab_focus()
