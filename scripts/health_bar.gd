extends TextureProgressBar

@export var player: CharacterBody2D

func _ready() -> void:
	player.connect("health_changed", Callable(self, "update"))
	self.scale = Vector2(3, 4)
	update()

func update():
	# Done this way to counter int division and dropping of fraction
	value = (player.current_health * 100 / player.max_health) 
	
