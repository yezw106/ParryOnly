extends Node2D

@export var enemy_scene: PackedScene
@export var fire_wizard_scene: PackedScene   # ✅ 新增：FireWizard 场景
@onready var player = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var ui = $UI

var screen_size: Vector2
var normal_kill_count: int = 0        # ✅ 追踪普通敌人击杀数
var fire_wizard_unlocked: bool = false

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
	
	# 显示 UI 的 Game Over
	var ui = get_node_or_null("UI")
	if ui:
		ui.show_game_over()


func _on_spawn_timer_timeout():
	if not is_instance_valid(player) or player.is_dead:
		return  # 玩家死了就不再刷敌人


	# ✅ 判断是否解锁 FireWizard
	if not fire_wizard_unlocked and normal_kill_count >= 1:
		fire_wizard_unlocked = true

	# ✅ 刷新逻辑
	if fire_wizard_unlocked and randf() < 0.2:  
		spawn_fire_wizard()
		spawn_timer.wait_time = randf_range(3.0, 5.0)   # FireWizard 刷新间隔

	else:
		spawn_enemy()
		spawn_timer.wait_time = randf_range(0.5, 0.8)   # 普通敌人刷间隔

	spawn_timer.start()


	#spawn_enemy()

	# 逐渐缩短间隔
	#current_min_time = max(spawn_min_time, current_min_time * spawn_decay)
	#current_max_time = max(spawn_max_time, current_max_time * spawn_decay)

	#spawn_timer.wait_time = randf_range(current_min_time, current_max_time)
	#spawn_timer.start()


func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	place_enemy(enemy)
	enemy.add_to_group("enemy")

	# ✅ 敌人死亡时增加计数
	enemy.tree_exited.connect(func():
		normal_kill_count += 1
	)

func spawn_fire_wizard():
	var wiz = fire_wizard_scene.instantiate()
	add_child(wiz)
	place_enemy(wiz)
	wiz.add_to_group("firewizard")
	wiz.set_meta("is_normal", false)


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
