extends StaticBody2D

const CRUMBLE_TIME := 0.45
const RESPAWN_TIME := 2.5

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sensor: Area2D = $Sensor
@onready var debris: CPUParticles2D = $Debris

var _crumbling := false


func _ready() -> void:
	sensor.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _crumbling or not body.is_in_group("player"):
		return
	_crumble()


func _crumble() -> void:
	_crumbling = true
	var steps := 3
	for i in steps:
		sprite.frame = i + 1
		Fx.play_var("crack", 0.15, -4.0)
		var t := 0.0
		while t < CRUMBLE_TIME / steps:
			t += get_physics_process_delta_time()
			sprite.position = Vector2(randi_range(-1, 1), randi_range(-1, 1)) * 3.0
			await get_tree().physics_frame
	sprite.position = Vector2.ZERO
	sprite.visible = false
	shape.set_deferred("disabled", true)
	debris.restart()
	Fx.play_var("crumble", 0.1, -3.0)

	await get_tree().create_timer(RESPAWN_TIME, false).timeout
	# don't pop back in on top of the player
	while _player_inside():
		await get_tree().create_timer(0.2, false).timeout
	sprite.frame = 0
	sprite.visible = true
	sprite.modulate.a = 0.0
	shape.set_deferred("disabled", false)
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.2)
	_crumbling = false


func _player_inside() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var d := player.global_position - global_position
	return absf(d.x) < 50.0 and absf(d.y) < 70.0
