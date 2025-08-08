extends Area2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Collectable Coin

func _on_body_entered(body: Node2D) -> void:
	animation_player.play("pickup")
