extends Node2D

@onready var slime_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_collision_radius: CollisionShape2D = $HurtZone/CollisionShape2D
@onready var chase_collision_radius: CollisionShape2D = $ChaseRadius/CollisionShape2D
@onready var detection_collision_radius: CollisionShape2D = $DetectionRadius/CollisionShape2D
@onready var wander_timer: Timer = $WanderTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var player: CharacterBody2D

var direction: int = 0

# Chase boundaries
var left_bound: Vector2
var right_bound: Vector2 

# Health
var health: int = 2
var is_hit: bool = false
var is_dead: bool = false

# Speed
const WANDER_SPEED = 40
const CHASE_SPEED = 40
const CHASE_RADIUS = 70

enum States {
	SLEEP,
	AWAKE,
	IDLE,
	WANDER,
	CHASE,
}

var current_state = States.SLEEP

func _ready() -> void:
	# Set the wander bounds
	left_bound = self.position + Vector2(-120, 0)
	right_bound = self.position + Vector2(120, 0)
	
	# Initially turn off chase radius
	chase_collision_radius.disabled = true

func _physics_process(delta: float) -> void:
	if is_dead:
		animate()
		return
		
	animate()
	change_direction()
	move(delta)

func animate() -> void:
	if is_dead:
		if slime_sprite.animation != "death":
			animation_player.play("death")
			slime_sprite.play("death")
		return
	
	if is_hit:
		if slime_sprite.animation != "hurt":
			animation_player.play("hurt")
			slime_sprite.play("hurt")
		return
	
	if current_state == States.SLEEP:
		if slime_sprite.animation != "sleep":
			slime_sprite.play("sleep")
	elif current_state == States.IDLE:
		if slime_sprite.animation != "idle":
			slime_sprite.play("idle")
	elif current_state == States.AWAKE:
		if slime_sprite.animation != "wake_up":
			slime_sprite.play("wake_up")
	elif current_state == States.WANDER or current_state == States.CHASE:
		if slime_sprite.animation != "move":
			slime_sprite.play("move")
	
func change_direction() -> void:
	# Wander around
	if current_state == States.WANDER:
		if slime_sprite.flip_h:
			# Moving left
			if self.position.x >= left_bound.x:
				direction = -1
			else:
				# Moving right
				slime_sprite.flip_h = false
				direction = 1
		else:
			# Moving right
			if self.position.x <= right_bound.x:
				direction = 1
			else:
				# Moving left
				slime_sprite.flip_h = true
				direction = -1
				
	elif current_state == States.CHASE:
		# Check position relative to player
		if player.position.x >= self.position.x:
			slime_sprite.flip_h = false
			direction = 1
		else:
			slime_sprite.flip_h = true
			direction = -1

func get_hit() -> void:
	health -= 1
	is_hit = true
	
	if health <= 0:
		death()
	
	slime_sprite.connect("animation_finished", Callable(self, "_on_hit_animation_finished"))
	
func death() -> void:
	is_dead = true
	
func start_chase() -> void:
	if current_state != States.CHASE:
		current_state = States.CHASE
	
	if not wander_timer.is_stopped():
		wander_timer.stop()

func stop_chase() -> void:
	current_state = States.WANDER
	
	if wander_timer.is_stopped():
		wander_timer.start()

func move(delta: float) -> void:
	if current_state == States.WANDER:
		position.x += direction * WANDER_SPEED * delta
		position.y = 0
	elif current_state == States.CHASE:
		# Move towards the player
		var direction_to_player = (player.position - position).normalized()
		position += direction_to_player * CHASE_SPEED * delta
		position.y = 0

func _on_detection_radius_body_entered(body: Node2D) -> void:
	print("Detected by slime.")
	if current_state == States.SLEEP or current_state == States.IDLE:
		current_state = States.AWAKE
		
		slime_sprite.connect("animation_finished", 
			Callable(self, "_on_wake_up_animation_finished"))

func _on_wake_up_animation_finished() -> void:
	current_state = States.WANDER
	slime_sprite.disconnect("animation_finished", Callable(self, "_on_wake_up_animation_finished"))
	
	# Start the wander timer
	wander_timer.start()
	
	# Enable chase radius
	call_deferred("_enable_chase_radius")

func _on_hit_animation_finished() -> void:
	is_hit = false

func _on_chase_radius_body_entered(body: Node2D) -> void:
	print("Entered chase radius")
	start_chase()

func _on_chase_radius_body_exited(body: Node2D) -> void:
	print("Exited chase radius")
	stop_chase()

func _enable_chase_radius():
	# Enable chase radius after the current frame
	print("Enabling chase radius")
	chase_collision_radius.disabled = false

func _disable_chase_radius():
	# Disable chase radius after the current frame
	print("Disabling chase radius")
	chase_collision_radius.disabled = true

func _disable_hurt_collision_radius():
	hurt_collision_radius.disabled = true
	
func _on_wander_timer_timeout() -> void:
	if current_state != States.IDLE:
		print("Time to go sleep.")
		current_state = States.IDLE
		
		# Disable chase radius
		call_deferred("_disable_chase_radius")

func _on_damage_zone_body_entered(body: Node2D) -> void:
	# Might need to start using has_method as more stuff gets added
	if body.has_method("is_falling") and body.is_falling():
		print("Player bounced on the slime!")
		body.bounce()
		get_hit()
