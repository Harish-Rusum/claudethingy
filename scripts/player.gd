extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $"Jump sound"
@onready var death_sound: AudioStreamPlayer2D = $"Death sound"
@onready var goal_reach_sound: AudioStreamPlayer2D = $"Goal reach sound"
@onready var goal_detector: Area2D = $GoalDetector
@onready var dust_particles: CPUParticles2D = $DustParticles
@onready var jump_dust: CPUParticles2D = $JumpDust
@onready var burst: CPUParticles2D = $Burst
@onready var feathers: CPUParticles2D = $Feathers
@onready var bubble: AnimatedSprite2D = $Bubble
@onready var shield_indi: Label = $ShieldIndi

# --- Movement ---
const BASE_SPEED := 50.0
const MAX_SPEED := 300.0
const ACCELERATION := 600.0
const FRICTION := 1400.0
const MAX_FALL_SPEED := 1200.0

# --- Jumping ---
const JUMP_HEIGHT := -850.0
const MIN_JUMP_HEIGHT := -300.0
const CUT_MULTIPLIER := 1.0
const COYOTE_TIME := 0.15
const JUMP_BUFFER_TIME := 0.15
const BOOST_HEIGHT := -1000.0

# --- Shield ---
const SHIELD_DURATION := 2.0
const SHIELD_TICK := 0.1

# --- Other boosts ---
const DOUBLE_JUMP_HEIGHT := -760.0
const DASH_SPEED := 950.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.3
const GLIDE_FALL_SPEED := 140.0
const SPIN_TIME := 0.32

# Changed by power-ups from other scripts
var speed_multiplier := 1.0
var jump_multiplier := 1.0
var can_double_jump := false
var can_dash := false
var can_glide := false

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var was_on_floor := true
var fall_speed := 0.0
var facing := 1.0

var air_jumps := 0
var dash_ready := false
var dash_timer := 0.0
var dash_cooldown := 0.0
var gliding := false
var _ghost_timer := 0.0
var _spin := 0.0

var has_shield := false
var shield_active := false
var shield_left := 0.0
var is_invincible := false
var is_dead := false
var reached_goal := false


func _ready() -> void:
	shield_indi.visible = false
	bubble.visible = false
	goal_detector.area_entered.connect(_on_area_entered)
	animated_sprite_2d.play("idle" + _anim_suffix())
	burst.color = Color("683a68") if _anim_suffix() == "1" else Color("a96868")


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if reached_goal:
		# coast to a stop while the results screen comes in
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if not is_on_floor():
			velocity.y = minf(velocity.y + get_gravity().y * delta, MAX_FALL_SPEED)
		move_and_slide()
		return

	_handle_level_input()
	_handle_shield_input()

	var direction := Input.get_axis("left", "right")
	if direction != 0.0:
		facing = signf(direction)
	dash_cooldown -= delta

	if dash_timer > 0.0:
		_process_dash(delta)
	else:
		_apply_gravity(delta)
		_handle_jump(delta)
		_handle_glide()
		_handle_horizontal(direction, delta)
		_try_dash()
	_update_animation(direction)

	fall_speed = velocity.y
	move_and_slide()

	_handle_landing()
	animated_sprite_2d.scale = animated_sprite_2d.scale.lerp(Vector2.ONE, 12.0 * delta)
	_update_rotation(delta)
	_check_enemy_collision()


# ---------- Input ----------

func _handle_level_input() -> void:
	if Input.is_action_just_pressed("restart"):
		LevelManager.restart_level()
	if Input.is_action_just_pressed("next"):
		LevelManager.go_to_next_level()


func _handle_shield_input() -> void:
	if Input.is_action_just_pressed("ability") and has_shield and not shield_active:
		use_shield()

 
# ---------- Movement ----------

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		air_jumps = 1 if can_double_jump else 0
		if can_dash:
			dash_ready = true
	else:
		velocity += get_gravity() * delta
		velocity.y = minf(velocity.y, MAX_FALL_SPEED)
		coyote_timer -= delta


func _handle_jump(delta: float) -> void:
	var pressed := Input.is_action_just_pressed("jump")
	if pressed:
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_HEIGHT * jump_multiplier
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		jump_sound.play()
		animated_sprite_2d.scale = Vector2(0.75, 1.3)
		jump_dust.restart()
	elif pressed and air_jumps > 0 and coyote_timer <= 0.0:
		_double_jump()

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y = maxf(velocity.y * CUT_MULTIPLIER, MIN_JUMP_HEIGHT)


func _double_jump() -> void:
	air_jumps -= 1
	jump_buffer_timer = 0.0
	velocity.y = DOUBLE_JUMP_HEIGHT * jump_multiplier
	animated_sprite_2d.scale = Vector2(0.7, 1.35)
	_spin = SPIN_TIME
	jump_dust.restart()
	Fx.play("double_jump")


func _handle_glide() -> void:
	var was := gliding
	gliding = can_glide and not is_on_floor() and velocity.y > 0.0 and Input.is_action_pressed("jump")
	if gliding:
		velocity.y = minf(velocity.y, GLIDE_FALL_SPEED)
		if not was:
			Fx.play_var("glide")
	feathers.emitting = gliding


func _handle_horizontal(direction: float, delta: float) -> void:
	if direction != 0.0:
		if absf(velocity.x) < BASE_SPEED:
			velocity.x = direction * BASE_SPEED
		var target_speed := direction * MAX_SPEED * speed_multiplier
		velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)


func _try_dash() -> void:
	if not can_dash or not dash_ready or dash_cooldown > 0.0:
		return
	if Input.is_action_just_pressed("dash"):
		dash_ready = false
		dash_timer = DASH_TIME
		dash_cooldown = DASH_COOLDOWN
		_ghost_timer = 0.0
		velocity = Vector2(facing * DASH_SPEED, 0.0)
		animated_sprite_2d.scale = Vector2(1.35, 0.75)
		Fx.play("dash")
		Fx.shake(0.12)


func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = Vector2(facing * DASH_SPEED, 0.0)
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = 0.03
		_spawn_ghost()
	if dash_timer <= 0.0:
		velocity.x = facing * MAX_SPEED * speed_multiplier


func _handle_landing() -> void:
	if not was_on_floor and is_on_floor():
		animated_sprite_2d.scale = Vector2(1.3, 0.7)
		dust_particles.restart()
		if fall_speed > MAX_FALL_SPEED * 0.8:
			Fx.shake(0.16)
			Fx.play_var("land")
	was_on_floor = is_on_floor()


func _update_rotation(delta: float) -> void:
	if _spin > 0.0:
		_spin = maxf(_spin - delta, 0.0)
		animated_sprite_2d.rotation = (1.0 - _spin / SPIN_TIME) * TAU * facing
	elif gliding:
		animated_sprite_2d.rotation = sin(Time.get_ticks_msec() * 0.012) * 0.14
	else:
		animated_sprite_2d.rotation = lerp_angle(animated_sprite_2d.rotation, 0.0, 16.0 * delta)


func _spawn_ghost() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = animated_sprite_2d.sprite_frames.get_frame_texture(animated_sprite_2d.animation, animated_sprite_2d.frame)
	ghost.flip_h = animated_sprite_2d.flip_h
	ghost.global_position = animated_sprite_2d.global_position
	ghost.scale = animated_sprite_2d.global_scale
	ghost.modulate = Color(1.0, 0.56, 0.5, 0.55)
	get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)


# ---------- Boosts ----------

func apply_upgrade(id: StringName) -> void:
	match id:
		&"haste":
			speed_multiplier = 1.25
		&"spring":
			jump_multiplier = 1.3
		&"bubble":
			grant_shield()
		&"double_jump":
			can_double_jump = true
			air_jumps = 1
		&"dash":
			can_dash = true
			dash_ready = true
		&"glide":
			can_glide = true


# what the HUD shows under the boost name
func boost_status() -> String:
	match LevelManager.current_upgrade:
		&"bubble":
			if shield_active:
				return "%.1fs" % shield_left
			return "ready" if has_shield else "popped"
		&"dash":
			return "ready" if dash_ready and dash_cooldown <= 0.0 else "recharging"
		&"double_jump":
			return "ready" if air_jumps > 0 or is_on_floor() else "used"
		&"glide":
			return "floating" if gliding else "hold jump"
		&"haste":
			return "+25% speed"
		&"spring":
			return "+30% jump"
	return ""


func grant_shield() -> void:
	has_shield = true
	_set_shield_indicator("E", true)


func use_shield() -> void:
	if not has_shield or shield_active or is_dead:
		return
	has_shield = false
	shield_active = true
	is_invincible = true
	bubble.visible = true
	bubble.play("default")
	Fx.play("shield_up")

	shield_left = SHIELD_DURATION
	while shield_left > 0.0 and is_invincible and not is_dead:
		shield_indi.text = "%.1f" % shield_left
		# blink when it's about to pop
		bubble.modulate.a = 0.3 if shield_left < 0.6 and int(shield_left * 10.0) % 2 == 0 else 1.0
		await get_tree().create_timer(SHIELD_TICK, false).timeout
		shield_left -= SHIELD_TICK

	is_invincible = false
	shield_active = false
	bubble.visible = false
	_set_shield_indicator("", false)
	if not is_dead:
		Fx.play("shield_down")

	# Still standing in a trap when the shield runs out? Die now.
	for area in goal_detector.get_overlapping_areas():
		if area.is_in_group("trap"):
			die()
			return


func _set_shield_indicator(text: String, show: bool) -> void:
	shield_indi.text = text
	shield_indi.visible = show


# ---------- Collisions ----------

func _check_enemy_collision() -> void:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("enemies"):
			die()
			return


func _on_area_entered(area: Area2D) -> void:
	if is_dead or reached_goal:
		return
	if area.is_in_group("endGoal"):
		_reach_goal()
	elif area.is_in_group("trap"):
		die()
	elif area.is_in_group("boost"):
		_boost()


func _reach_goal() -> void:
	reached_goal = true
	dash_timer = 0.0
	feathers.emitting = false
	goal_reach_sound.play()
	var time := 0.0
	var timer := get_tree().current_scene.get_node_or_null("Timer")
	if timer:
		timer.running = false
		time = timer.time_elapse
	LevelManager.time_taken = time
	Fx.hitstop(0.06)
	LevelManager.complete_level(time)


func _boost() -> void:
	velocity.y = BOOST_HEIGHT
	dash_timer = 0.0
	# orbs refill your boost, like the crystals in celeste
	if can_double_jump:
		air_jumps = 1
	if can_dash:
		dash_ready = true
	animated_sprite_2d.scale = Vector2(0.55, 1.5)
	jump_sound.pitch_scale = 1.4
	jump_sound.play()
	get_tree().create_timer(0.2).timeout.connect(func(): jump_sound.pitch_scale = 1.0)


# ---------- Death ----------

func die(forced := false) -> void:
	if is_dead or reached_goal:
		return
	if is_invincible and not forced:
		return
	is_dead = true
	velocity = Vector2.ZERO
	dash_timer = 0.0
	bubble.visible = false
	feathers.emitting = false
	shield_indi.visible = false
	LevelManager.register_death()
	death_sound.play(0.3)
	animated_sprite_2d.rotation = 0.0
	animated_sprite_2d.play("hit" + _anim_suffix())
	burst.restart()
	Fx.shake(0.5)
	Fx.hitstop(0.09)

	await animated_sprite_2d.animation_finished
	LevelManager.restart_level()


# ---------- Animation ----------

func _anim_suffix() -> String:
	return "1" if LevelManager.world_of(LevelManager.current_level) == 0 else "2"


func _update_animation(direction: float) -> void:
	var suffix := _anim_suffix()

	if not is_on_floor():
		animated_sprite_2d.animation = "jump" + suffix
		dust_particles.emitting = false
	elif absf(velocity.x) > 1.0:
		animated_sprite_2d.animation = "run" + suffix
		dust_particles.emitting = true
	else:
		animated_sprite_2d.animation = "idle" + suffix
		dust_particles.emitting = false

	if direction != 0.0:
		animated_sprite_2d.flip_h = direction < 0.0
		dust_particles.scale.x = -1.0 if direction < 0.0 else 1.0
