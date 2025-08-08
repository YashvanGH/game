extends Area2D

# This is to model stuff that does not kill the player immediately.

@onready var death_timer: Timer = $DeathTimer

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("get_hit"):
		body.get_hit()
		
		if body.is_dead:
			# Slow game on death
			Engine.time_scale = 0.5
			body.get_node("AnimationPlayer").play("death")
			death_timer.start()

func _on_death_timer_timeout() -> void:
	# Set the game time back to normal
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
