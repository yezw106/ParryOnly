extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimationPlayer.play("apear")
	await get_tree().create_timer(0.2).timeout
	$AnimationPlayer.play("disapear")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if get_parent().get_node("Player").facing_right:
		$Glow.position.x = 0
		$Circle.position.x = 0
	else:
		$Glow.position.x = 15
		$Circle.position.x = 15
