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
@export var parry_timing_fw := 0.3         # parry 有效判定窗口时长（秒）

@export var fw_parry_required := 0.7  # FireWizard 攻击持续时间，必须撑满
var fw_parry_mode := false      # 是否处于 FireWizard 弹反监控模式
var fw_parry_timer := 0.0       # 记录已经坚持了多久
var fw_parry_attacker_current: Node = null   # 当前正在防御的 firewizard
var fw_attack_angle:float = 0.0

# Eagleman 弹反逻辑相关
var eagle_parry_count := 0         # 当前已成功输入次数
var eagle_parry_timer := 0.0       # 距离上次输入的时间
var eagle_parry_max_interval := 0.6 # 最大间隔
var eagle_parry_required := 3      # 需要输入次数
var eagle_parry_attacker_current: Node = null   # 当前正在防御的 firewizard

var state: State = State.IDLE
var facing_right := true
# 判定窗口控制
var parry_window_open := false
var is_dead := false
var parry_animations = ["attack1", "attack2"]

enum Enemy_Type { NOENEMY, ENEMY, FIREWIZARD , EAGLEMAN }

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
			# 🔥 FireWizard 特殊监控
			if fw_parry_mode:
				if not Input.is_action_pressed("parry"):
					# 松开就失败
					die()
					fw_parry_mode = false
					fw_parry_timer = 0
				else:
					fw_parry_timer += delta
					if fw_parry_timer >= fw_parry_required:
						# 成功弹反 FireWizard
						fw_parry_success(fw_parry_attacker_current)
		State.HURT:
			pass # 在受伤状态，等待动画结束
	# 追踪 eagleman 连击输入的间隔
	if eagle_parry_count > 0:
		eagle_parry_timer += delta
		if eagle_parry_timer > eagle_parry_max_interval:
			# 超时 → 失败
			eagle_parry_count = 0
			die()

func get_neareast_ememy_type() -> Enemy_Type:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var wiz = get_tree().get_nodes_in_group("firewizard")
	var eagle = get_tree().get_nodes_in_group("eagleman")

	# 如果三类敌人都没有
	if enemies.is_empty() and wiz.is_empty() and eagle.is_empty():
		return Enemy_Type.NOENEMY

	# 定义“最近敌人”存储
	var nearest : Node = null
	var nearest_type : Enemy_Type = Enemy_Type.NOENEMY
	var min_dist := INF

	# 🔹 检查 enemy
	for e in enemies:
		var d = global_position.distance_to(e.global_position) - e.attack_range
		if d < min_dist:
			min_dist = d
			nearest = e
			nearest_type = Enemy_Type.ENEMY

	# 🔹 检查 firewizard
	for w in wiz:
		var d = global_position.distance_to(w.global_position) - w.attack_range - 50
		if d < min_dist:
			min_dist = d
			nearest = w
			nearest_type = Enemy_Type.FIREWIZARD

	# 🔹 检查 eagleman
	for ea in eagle:
		var d = global_position.distance_to(ea.global_position) - ea.attack_range -10
		if d < min_dist:
			min_dist = d
			nearest = ea
			nearest_type = Enemy_Type.EAGLEMAN
	return nearest_type

func is_facing_nearest_enemy() -> bool:
	var enemies = []
	enemies.append_array(get_tree().get_nodes_in_group("enemy"))
	enemies.append_array(get_tree().get_nodes_in_group("firewizard"))
	enemies.append_array(get_tree().get_nodes_in_group("eagleman"))

	if enemies.is_empty():
		return false
	
	# 找到最近的敌人
	var nearest = enemies[0]
	var min_dist = global_position.distance_to(nearest.global_position)
	for e in enemies:
		var attack_range = nearest.attack_range if nearest.has_method("attack_range") else 0
		# Firewizard 有特殊额外距离（例如 -20）
		if e.is_in_group("firewizard"):
			attack_range += 50
		if e.is_in_group("eagleman"):
			attack_range += 10
		var d = global_position.distance_to(e.global_position) - attack_range
		if d < min_dist:
			min_dist = d
			nearest = e
	
	# 判断是否朝向最近的敌人
	if (facing_right and nearest.global_position.x > global_position.x) \
	or (not facing_right and nearest.global_position.x < global_position.x):
		return true
	else:
		return false
		

		

func get_angle_between(p1: Vector2, p2: Vector2) -> float:
	var dx = p2.x - p1.x
	var dy = p2.y - p1.y
	var angle = atan2(dy, dx)   # 弧度
	return rad_to_deg(angle)       # 转换为角度

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
		parry_effect_sparks.position.x = 15
		parry_effect_shockwave.position.x = 15
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
	if is_dead == true:
		return
	state = State.PARRY
	parry_window_open = true
	if get_neareast_ememy_type() == Enemy_Type.FIREWIZARD:
		fw_parry_mode = true
		anim.play("fw_parry")
	elif get_neareast_ememy_type() == Enemy_Type.EAGLEMAN:
		if eagle_parry_count == 0:
			anim.play("eagle_parry1")
		elif eagle_parry_count == 1:
			anim.play("eagle_parry2")
		else:
			anim.play("eagle_parry3")
		if eagle_parry_count > 0:
			eagleman_parry_progress(eagle_parry_attacker_current)

	else:
		var anim_name = parry_animations[randi() % parry_animations.size()]
		anim.play(anim_name)


# 敌人攻击检测时调用：返回是否被成功弹反
func try_parry(attacker: Node = null) -> bool:
	parry_effect_sparks.position.y = 0
	parry_effect_shockwave.position.y = 0
	if state == State.PARRY and parry_window_open and (is_facing_nearest_enemy()):
		if attacker:
			if attacker.is_in_group("firewizard"):
				# FireWizard → 进入持续检测模式
				if Input.is_action_pressed("parry"):

					fw_parry_timer = 0.0
					fw_parry_attacker_current = attacker
					fw_attack_angle = get_angle_between(self.position,attacker.position)
					spawn_shield()
					return true   # 先返回 true，表示开始防御（不立即结算）
				else:
					die()
					return false
			elif attacker.is_in_group("eagleman"):
				eagle_parry_count = 1
				eagle_parry_timer = 0.0
				eagle_parry_attacker_current = attacker
				parry_effect_sparks.position.y = attacker.global_position.y - global_position.y
				parry_effect_shockwave.position.y = attacker.global_position.y - global_position.y
				play_parry_effect(facing_right)
				parry_sfx_list[2].play()
				return true  # 尚未完成
			# 普通敌人立即结算
			return normal_parry_success(attacker)
	
	# 失败 → 受伤
	die()
	return false

func normal_parry_success(attacker: Node) -> bool:
	var sfx = parry_sfx_list[randi() % parry_sfx_list.size()]
	sfx.play()
	print("Parry success!")
	play_parry_effect(facing_right)
	
	var ui = get_tree().root.get_node_or_null("Main/UI")
	if ui:
		ui.add_parry()
	
	if attacker.is_in_group("enemy"):
		if attacker.has_method("on_parried"):
			attacker.on_parried()

	return true

func eagleman_parry_progress(attacker: Node) -> bool:
	# 后续按键 → 检查间隔
	if eagle_parry_timer <= eagle_parry_max_interval:
		eagle_parry_count += 1
		play_parry_effect(facing_right)
		if eagle_parry_count >= eagle_parry_required:
			# 成功
			parry_sfx_list[0].play()
			return eagleman_parry_success(attacker)
		else:
			parry_sfx_list[1].play()
			eagle_parry_timer = 0.0
			return false
	else:
		# 超时 → 失败
		die()
		eagle_parry_count = 0
		
		return false

func play_eagleman_parry_anim(step: int):
	var anim_names = ["eagle_parry1", "eagle_parry2", "eagle_parry3"]
	if step < anim_names.size():
		anim.play(anim_names[step])
		anim.speed_scale = anim.get_sprite_frames().get_animation_speed(anim_names[step]) * (parry_duration / 0.3)

func eagleman_parry_success(attacker: Node) -> bool:
	eagle_parry_count = 0
	eagle_parry_timer = 0.0
	print("Eagleman Parry success!")
	play_parry_effect(facing_right)
	var ui = get_tree().root.get_node_or_null("Main/UI")
	if ui:
		ui.add_parry()

	if attacker.is_in_group("eagleman") and attacker.has_method("on_parried"):
		attacker.on_parried()
	return true

func fw_parry_success(attacker: Node):
	fw_parry_mode = false
	fw_parry_timer = 0
	var sfx = parry_sfx_list[randi() % parry_sfx_list.size()]
	sfx.play()
	$ParrySFX4.play()
	print("FireWizard Parry success (hold 1s)!")
	play_parry_effect(facing_right)
	
	var ui = get_tree().root.get_node_or_null("Main/UI")
	if ui:
		ui.add_parry()
	
 
	if attacker.is_in_group("firewizard") : 
		if attacker.has_method("on_parried"):
			attacker.on_parried()
	# FireWizard 攻击 → 生成光罩

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
	elif anim.animation in ["attack1", "attack2", "eagle_parry1", "eagle_parry2", "eagle_parry3"]:
		if not is_dead:
			if fw_parry_mode and Input.is_action_pressed("parry"):
				state = State.PARRY
				anim.play("fw_parry")
			else:
				state = State.IDLE
				anim.play("idle")
		else:
			anim.play("death")
	elif anim.animation in ["fw_parry"]:
		if not is_dead: 
			if Input.is_action_pressed("fw_parry"):
				state = State.PARRY
				anim.play("fw_parry")
			else:
				state = State.IDLE
				anim.play("idle")
		else:
			anim.play("death")
	elif anim.animation == "hurt":
		# 受伤动画结束 → 回到 idle（除非死了）
		if not is_dead:
			state = State.IDLE
			anim.play("idle")
