extends CharacterBody2D

# References
@onready var player_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_duration_timer: Timer = $Dash/DashDurationTimer
@onready var dash_effect_timer: Timer = $Dash/DashEffectTimer
@onready var dash_cooldown_timer: Timer = $Dash/DashCooldownTimer
@onready var roll_duration_timer: Timer = $Roll/RollDurationTimer
@onready var roll_cooldown_timer: Timer = $Roll/RollCooldownTimer
@onready var hit_invulnerability_timer: Timer = $HitInvulnerabilityTimer

# Custom Signals
signal health_changed

# Player Velocity
const RUN_SPEED = 130.0
const JUMP_VELOCITY = -300.0
const KNOCK_SPEED = 100.0
const KNOCK_VELOCITY = -150.0
const FRICTION = 80.0

var direction: int = 0

# Health
var max_health: int = 4
var current_health: int = max_health
var is_hit: bool = false
var is_dead: bool = false

# Dash
var is_dashing: bool = false
var can_dash: bool = true
const DASH_SPEED = 1.5

# Roll
var is_rolling: bool = false
var can_roll: bool = true
const ROLL_SPEED = 1.2

# Double Jump
var double_jumps: int = 0

# Invulnerability

# parry
# attack

# Might need to change this sometime => Only using it for low health for now
func _process(delta):
	if current_health == 1:
		var time_ms = Time.get_ticks_msec()
		# blink = 100, 500, 1000
		var blink = int(time_ms / 1000) % 2 == 0 # Once every 2 seconds
		if blink:
			player_sprite.modulate = Color(1, 0.6, 0.6)
		else:
			player_sprite.modulate = Color(1, 1, 1)
	else:
		player_sprite.modulate = Color(1, 1, 1)

func _physics_process(delta: float) -> void:
	if is_dead:
		animate()
		return
	
	add_gravity(delta)
	change_direction()
	animate()
	
	if not is_hit:
		run()
		jump()
		double_jump()
		dash()
		roll()
	
	move_and_slide()

func animate() -> void:
	# Play respective animations
	if is_dead:
		if player_sprite.animation != "death":
			player_sprite.play("death")
		return
	
	if is_dashing:
		if player_sprite.animation != "dash":
			player_sprite.play("dash")
		return
	
	if is_rolling:
		if player_sprite.animation != "roll":
			player_sprite.play("roll")
		return
	
	if is_hit:
		if player_sprite.animation != "hit":
			player_sprite.play("hit")
		return
	
	if is_on_floor():
		if direction == 0:
			player_sprite.play("idle")
		else:
			player_sprite.play("run")
	
	if not is_on_floor():
		if double_jumps < 1:
			if player_sprite.animation != "jump":
				player_sprite.play("jump")
		else:
			if player_sprite.animation != "double_jump":
				player_sprite.play("double_jump")
	 
func add_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta	

func run():	
	if direction:
		velocity.x = direction * RUN_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, RUN_SPEED)

func change_direction() -> void:
	# direction = { -1 for left, 0 for no movement, 1 for right }
	direction = Input.get_axis("move_left", "move_right")
	
	# Flip sprite based on direction
	if direction > 0:
		player_sprite.flip_h = false
	elif direction < 0:
		player_sprite.flip_h = true

func jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func double_jump() -> void:
	if (not is_on_floor() and Input.is_action_just_pressed("jump") and double_jumps < 1):
		velocity.y = JUMP_VELOCITY
		double_jumps += 1
	
	if is_on_floor():
		double_jumps = 0

func dash() -> void:	
	if (Input.is_action_just_pressed("dash") and can_dash):
		is_dashing = true
		can_dash = false
		
		dash_cooldown_timer.start()
		dash_duration_timer.start()
		dash_effect_timer.start()
		
	if is_dashing:
		if direction == 0:
			# Dash in the direction player is facing if no directional input
			var dash_direction = 1 if not player_sprite.flip_h else -1
			velocity.x = dash_direction * RUN_SPEED * DASH_SPEED
			velocity.y = 0
		else:
			velocity.x = direction * RUN_SPEED * DASH_SPEED
			velocity.y = 0

func dash_effect() -> void:
	var ghost: AnimatedSprite2D = $AnimatedSprite2D.duplicate()
	var fade_steps = 3
	var fade_time = 0.06
	var fade_amount = ghost.modulate.a / float(fade_steps)
	ghost.modulate.a = 0.8 
	get_parent().add_child(ghost)
	
	# Match position in local space to create trailing effect
	ghost.global_position = player_sprite.global_position
	
	for i in range(fade_steps):
		await get_tree().create_timer(fade_time).timeout
		ghost.modulate.a -= fade_amount
	
	ghost.queue_free()

func roll() -> void:
	if Input.is_action_just_pressed("roll") and can_roll and is_on_floor():
		is_rolling = true
		can_roll = false
		
		roll_duration_timer.start()
		roll_cooldown_timer.start()
	
	if is_rolling:
		if direction == 0:
			# Roll in the direction player is facing if no directional input
			var roll_direction = 1 if not player_sprite.flip_h else -1
			velocity.x = roll_direction * RUN_SPEED * ROLL_SPEED
			velocity.y = 0
		else:
			velocity.x = direction * RUN_SPEED * ROLL_SPEED
			velocity.y = 0
		
func get_hit() -> void:
	if is_invulnerable():
		return
	
	# Lose health and gain hit invulnerability
	current_health -= 1
	is_hit = true
	health_changed.emit()
	hit_invulnerability_timer.start()
	
	#hit_stop(0.8, 0.5)
	knockback()
	
	if current_health <= 0:
		death()

func knockback() -> void:
	# Bounce away upon hit
	velocity.y = KNOCK_VELOCITY
	velocity.x = -1 * direction * KNOCK_SPEED

func hit_stop(time_scale, duration) -> void:
	Engine.time_scale = time_scale
	await get_tree().create_timer(time_scale * duration).timeout
	Engine.time_scale = 1.0

func death() -> void:
	is_dead = true
	
func is_invulnerable() -> bool:
	# May have more stuff later on besides dashing
	return is_dashing or is_hit or is_rolling

func _on_dash_duration_timer_timeout() -> void:
	is_dashing = false
	dash_effect_timer.stop()

func _on_dash_cooldown_timer_timeout() -> void:
	can_dash = true
		
func _on_dash_effect_timer_timeout() -> void:
	dash_effect()

func _on_roll_duration_timer_timeout() -> void:
	is_rolling = false
	
func _on_roll_cooldown_timer_timeout() -> void:
	can_roll = true

func _on_hit_invulnerability_timer_timeout() -> void:
	is_hit = false
