extends Node2D

@export var enemy_scene: PackedScene
@export var fire_wizard_scene: PackedScene   # ✅ 新增：FireWizard 场景
@export var eagle_man_scene: PackedScene   # ✅ 新增：EagleMan 场景
@onready var player = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var ui = $UI

var normal_win_count = 100
var eagleman_win_count = 30
var wiz_win_count = 20

var normal_spawn_rate = 0.2
var ea_spawn_rate = 0.2
var wiz_spawn_rate = 0.1

var screen_size: Vector2
var normal_kill_count: int = 0        # ✅ 追踪普通敌人击杀数
var fire_wizard_kill_count: int = 0        # ✅ 追踪普通敌人击杀数
var eagleman_kill_count: int = 0        # ✅ 追踪普通敌人击杀数
var fire_wizard_unlocked: bool = false
var eagle_man_unlocked: bool = false

var normal_spawn_count: int = 0        # ✅ 追踪普通敌人出生数
var fire_wizard_spawn_count: int = 0        # ✅ 追踪普通敌人出生数
var eagleman_spawn_count: int = 0        # ✅ 追踪普通敌人出生数

var spawn_min_time := 0.5      # 敌人生成的最短间隔
var spawn_max_time := 0.8      # 敌人生成的最长间隔
var spawn_decay := 0.95        # 每次刷怪间隔衰减系数（越小 → 越快）
var current_min_time := 0.5    # 当前最小间隔，初始较大
var current_max_time := 0.8    # 当前最大间隔，初始较大

func _ready():
	add_to_group("game")  # 让 UI 可以 call_group("game", "start_game")
	$BattleBGM.play()
	screen_size = get_viewport().get_visible_rect().size
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.stop() # 默认不开启，等玩家点击 Start



func start_game():
	# 从 UI 按钮调用
	if player and not player.is_dead:
		# 初始化计时区间
		spawn_timer.wait_time = randf_range(current_min_time, current_max_time)
		spawn_timer.start()
	if normal_kill_count == 0:
		ui.get_node("LevelUp").text = "按'空格'弹反！"
		ui.get_node("LevelUp/AnimationPlayer").play("appear")
	if ui.end_less_mode_on:
		var normal_win_count = 9999
		var eagleman_win_count = 9999
		var wiz_win_count = 9999


func game_over():
	spawn_timer.stop()
	
	# 停止 BGM
	if $BattleBGM.playing:
		$BattleBGM.stop()
		
	await get_tree().create_timer(0.8).timeout
	# 清理敌人
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	
	var wiz = get_tree().get_nodes_in_group("firewizard")
	for w in wiz:
		if is_instance_valid(w):
			w.queue_free()
	
	var eagle = get_tree().get_nodes_in_group("eagleman")
	for ea in eagle:
		if is_instance_valid(ea):
			ea.queue_free()
	# 显示 UI 的 Game Over
	if ui:
		ui.show_game_over()
	


func game_win():
	spawn_timer.stop()
	
	# 停止 BGM
	if $BattleBGM.playing:
		$BattleBGM.stop()

	$WinMusic.play()
	
	await get_tree().create_timer(0.8).timeout
	# 清理敌人
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	
	var wiz = get_tree().get_nodes_in_group("firewizard")
	for w in wiz:
		if is_instance_valid(w):
			w.queue_free()
	
	var eagle = get_tree().get_nodes_in_group("eagleman")
	for ea in eagle:
		if is_instance_valid(ea):
			ea.queue_free()
	# 显示 UI 的 Game Over
	if ui:
		ui.show_game_win()
	player.get_node("AnimatedSprite2D").play("celeb")
	
	



func _on_spawn_timer_timeout():
	if not is_instance_valid(player) or player.is_dead or (not ui.end_less_mode_on and eagleman_spawn_count >= eagleman_win_count and fire_wizard_spawn_count >= wiz_win_count and normal_spawn_count >= normal_win_count):
		return  # 玩家死了就不再刷敌人
		
	## ✅ 判断是否解锁 FireWizard
	if not eagle_man_unlocked and normal_kill_count >= 10:
		eagle_man_unlocked = true
		ui.get_node("LevelUp").text = "第 2 关!\n注意使用三连击！"
		ui.get_node("LevelUp/AnimationPlayer").play("appear")



	if not fire_wizard_unlocked and eagleman_kill_count >= 5:
		fire_wizard_unlocked = true
		ui.get_node("LevelUp").text = "第 3 关!!\n持续按键抵御巫师！"
		ui.get_node("LevelUp/AnimationPlayer").play("appear")




	var rand = randf()
	# ✅ 刷新逻辑
	if eagle_man_unlocked and rand < ea_spawn_rate: 
		if  not ui.end_less_mode_on and eagleman_spawn_count >= eagleman_win_count:
			_on_spawn_timer_timeout()
			return
		spawn_eagle_man()
		spawn_timer.wait_time = randf_range(1.9, 2.2)   # EagleMan 刷新间隔
	elif fire_wizard_unlocked and rand >= ea_spawn_rate and rand <= ea_spawn_rate + wiz_spawn_rate:
		if  not ui.end_less_mode_on and fire_wizard_spawn_count >= wiz_win_count:
			_on_spawn_timer_timeout()
			return
		spawn_fire_wizard()
		spawn_timer.wait_time = randf_range(2.0, 2.25) 
	else:
		if  not ui.end_less_mode_on and normal_spawn_count >= normal_win_count:
			_on_spawn_timer_timeout()
			return
		spawn_enemy()
		spawn_timer.wait_time = randf_range(0.55, 0.8)
	spawn_timer.start()


func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	place_enemy(enemy)
	normal_spawn_count+=1
	enemy.add_to_group("enemy")
	enemy.set_meta("is_normal", true)
	# ✅ 敌人死亡时增加计数
	enemy.tree_exited.connect(func():
		normal_kill_count += 1
	)

func spawn_fire_wizard():
	var wiz = fire_wizard_scene.instantiate()
	add_child(wiz)
	place_enemy(wiz)
	fire_wizard_spawn_count +=1
	wiz.add_to_group("firewizard")
	wiz.set_meta("is_normal", false)
	wiz.tree_exited.connect(func():
		fire_wizard_kill_count += 1
	)

func spawn_eagle_man():
	var eagle = eagle_man_scene.instantiate()
	add_child(eagle)
	place_enemy(eagle)
	eagleman_spawn_count += 1
	eagle.add_to_group("eagleman")
	eagle.set_meta("is_normal", true)
	eagle.tree_exited.connect(func():
		eagleman_kill_count += 1
	)

func place_enemy(enemy: Node2D):
	var side = randi() % 2
	var y = randf_range(100, screen_size.y - 100)
	if side == 0:
		enemy.global_position = Vector2(0, y)
		if "set_facing_right" in enemy:
			enemy.set_facing_right(true)
	else:
		enemy.global_position = Vector2(screen_size.x, y)
		if "set_facing_right" in enemy:
			enemy.set_facing_right(false)
