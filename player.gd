extends Area2D

# 玩家状态枚举
enum State { IDLE, PARRY, HURT }

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var parry_sfx_list = [
	$ParrySFX1,
	$ParrySFX2,
	$ParrySFX3
]
@onready var parry_effect_sparks: GPUParticles2D = $ParryEffect/Sparks
@onready var parry_effect_shockwave: GPUParticles2D = $ParryEffect/Shockwave

@export var shield_scene: PackedScene   # 光罩预制体
@export var parry_duration := 0.5       # parry 动画持续时长（秒）
@export var parry_timing := 0.5         # parry 有效判定窗口时长（秒）

var state: State = State.IDLE
var facing_right := true
# 判定窗口控制
var parry_window_open := false
var is_dead := false
var parry_animations = ["attack1", "attack2"]

func _ready():
	anim.play("idle")
	# 动画播放完毕的信号连接
	anim.connect("animation_finished", _on_animation_finished)


func _process(delta: float):
	if Input.is_action_just_pressed("ui_left"):
		set_facing_right(false)
	elif Input.is_action_just_pressed("ui_right"):
		set_facing_right(true)
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("parry"):
				start_parry()
		State.PARRY:
			# parry 窗口计时
			if anim.frame * (1.0 / anim.speed_scale / anim.get_sprite_frames().get_animation_speed("attack1")) > parry_timing:
				parry_window_open = false
		State.HURT:
			pass # 在受伤状态，等待动画结束


func is_facing_nearest_enemy() -> bool:
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.size() == 0:
		return true
	
	var nearest = enemies[0]
	var min_dist = global_position.distance_to(nearest.global_position)
	
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < min_dist:
			nearest = e
			min_dist = d
	
	if (facing_right and (nearest.global_position.x > global_position.x))  or (not facing_right and (nearest.global_position.x < global_position.x)):
		return true
	else:
		return false
		

func set_facing_right(facing: bool):
	facing_right = facing
	anim.flip_h = not facing  # 向右时 flip_h = false, 向左时 flip_h = true
	if not facing:
		$Shadow.position.x = 15
	else:
		$Shadow.position.x = 0


func play_parry_effect(is_facing_right: bool):
	if is_facing_right:
		parry_effect_sparks.rotation = 0
		parry_effect_shockwave.rotation = 0
		parry_effect_sparks.position.x = 10
		parry_effect_shockwave.position.x = 10
	else:
		parry_effect_sparks.position.x = 3
		parry_effect_shockwave.position.x = 3
		parry_effect_sparks.rotation = PI
		parry_effect_shockwave.rotation = PI

	
	parry_effect_sparks.restart()
	parry_effect_sparks.emitting = true
	parry_effect_shockwave.restart()
	parry_effect_shockwave.emitting = true

# 开始弹反
func start_parry():
	state = State.PARRY
	parry_window_open = true
	var anim_name = parry_animations[randi() % parry_animations.size()]
	anim.play(anim_name)


# 敌人攻击检测时调用：返回是否被成功弹反
func try_parry(attacker: Node = null) -> bool:
	if state == State.PARRY and parry_window_open and is_facing_nearest_enemy():
		# 成功弹反
		var sfx = parry_sfx_list[randi() % parry_sfx_list.size()]
		sfx.play()
		print("Parry success!")
		# 播放特效
		
		play_parry_effect(facing_right)
		# 通知 UI 增加计数
		var ui = get_tree().root.get_node_or_null("Main/UI")
		if ui:
			ui.add_parry()
			
		if attacker:
			if attacker.is_in_group("enemy"):
				# 普通敌人 → 调用 on_parried()
				if attacker.has_method("on_parried"):
					attacker.on_parried()
			elif attacker.is_in_group("firewizard") or attacker.is_in_group("firejet"):
				# FireWizard 的火焰攻击 → 生成光罩
				spawn_shield()
				attacker.on_parried()
		return true
	else:
		# 失败，进入受伤状态
		die()
		return false

func spawn_shield():
	if not shield_scene: return
	var shield = shield_scene.instantiate()
	shield.global_position = global_position
	get_parent().add_child(shield)



# 进入受伤状态
func start_hurt():
	state = State.HURT
	anim.play("hurt")

func die():
	if is_dead:
		return
	is_dead = true
	$DeathSFX.play()
	anim.play("death")
	# 通知 Main 执行 game_over
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		main.game_over()


# 动画播放完毕的回调
func _on_animation_finished():
	if anim.animation == "death":
		await $DeathSFX.finished
		queue_free()
	elif anim.animation in ["attack1", "attack2"]:
		if not is_dead:
			state = State.IDLE
			anim.play("idle")
		else:
			anim.play("death")
	elif anim.animation == "hurt":
		# 受伤动画结束 → 回到 idle（除非死了）
		if not is_dead:
			state = State.IDLE
			anim.play("idle")
