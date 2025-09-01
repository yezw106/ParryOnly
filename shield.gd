extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$FireEffect.play("default")
	$AnimationPlayer.play("apear")
	await get_tree().create_timer(1).timeout
	$AnimationPlayer.play("disapear")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var player = get_parent().get_node("Player")
	var is_player_facing_right = player.facing_right
	$FireEffect.rotation = -(180 + player.fw_attack_angle)/180 * PI
	if is_player_facing_right:
		$FireEffect.position.x = 75
		$Glow.position.x = 0
		$Circle.position.x = 0
	else:
		$FireEffect.position.x = -59
		$Glow.position.x = 15
		$Circle.position.x = 15
