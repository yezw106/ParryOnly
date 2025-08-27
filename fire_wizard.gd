extends Area2D

enum State { IDLE, RUN, ATTACK, HURT, DEATH}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D      
var marked_for_deletion := false


var state: State = State.IDLE
var speed := 350.0
var attack_range := 50.0
var attack_cooldown := 2.0
var attack_timer := 0.0
var is_dead := false

func _ready():
	anim.play("idle")
	anim.connect("animation_finished", _on_animation_finished)

func _process(delta: float):
	match state:
		State.IDLE:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				state = State.RUN
				anim.play("run")
		State.RUN:
			move_to_player(delta)
		State.ATTACK:
			pass
		State.HURT:
			pass

	# 攻击冷却计时
	if attack_timer > 0:
		attack_timer -= delta


func move_to_player(delta: float):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var dir = (player.global_position - global_position).normalized()
	global_position += dir * speed * delta

	# 如果进入攻击范围并且冷却结束 → 攻击
	if global_position.distance_to(player.global_position) < attack_range and attack_timer <= 0:
		start_attack(player)


func start_attack(player):
	state = State.ATTACK
	attack_timer = attack_cooldown
	anim.play("attack1")

	# 在攻击帧检查是否被弹反（延迟调用更真实）
	await get_tree().create_timer(0.5).timeout
	if player and player.try_parry(self):
		# 被弹反 → 播放受伤动画
		on_parried()
	else:
		# 如果玩家没弹反，就可以在这里扣血或做别的事
		print("Enemy attack hit!")


func start_hurt():
	state = State.HURT
	anim.play("hurt")

func on_parried():
	if is_dead:
		return
	state = State.HURT
	anim.play("hurt")
	
func _on_animation_finished():
	if anim.animation == "hurt":
		state = State.DEATH
		anim.play("death")
	elif anim.animation == "death":
		is_dead = true
		queue_free()



# 敌人死亡（玩家 parry 成功时调用）
func die():
	if is_dead: 
		return
	is_dead = true
	anim.play("death")

func set_facing_right(facing: bool):
	if facing:
		anim.flip_h = false
	else:
		anim.flip_h = true
		$Shadow.position.x += 15
