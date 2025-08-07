extends Area2D

# Killzone
# Used to model falling, traps, enemies, etc.

@onready var death_timer: Timer = $DeathTimer

@export var player: CharacterBody2D

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		Engine.time_scale = 0.5
		death_timer.start()

func _on_death_timer_timeout() -> void:
	# Set the game time back to normal
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
	
