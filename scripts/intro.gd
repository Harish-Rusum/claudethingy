extends Cutscene

const IMPACT := Vector2(820, 816)

@onready var world: Node2D = $World
@onready var planet: Sprite2D = $World/Planet
@onready var falling: Sprite2D = $World/Falling
@onready var trail: Line2D = $World/Trail
@onready var guy: AnimatedSprite2D = $World/Guy
@onready var dust: CPUParticles2D = $World/Dust
@onready var ground: TileMapLayer = $World/Ground
@onready var music: AudioStreamPlayer = $Music


func _ready() -> void:
	lay_ground(ground, 0, 17)
	guy.visible = false
	falling.visible = false
	world.position.y = 1080.0
	_run()


func _physics_process(_delta: float) -> void:
	if falling.visible:
		trail.add_point(falling.position)
		if trail.get_point_count() > 14:
			trail.remove_point(0)
		falling.rotation += 0.35


func _run() -> void:
	await wait(0.4)
	await bars(true)
	await say("see that one? with the ring?", 1.1)
	await say("that's home.", 1.0)
	await _fall()
	await wait(0.9)
	await _look_around()
	await say("was home.", 1.0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(world, "position:y", 1080.0, 1.8)
	await tween.finished
	await say("long way back up.", 1.2)
	if skipped:
		return
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(world, "position:y", 0.0, 1.1)
	await tween.finished
	await _hop()
	await wait(0.5)
	_end()


func _fall() -> void:
	if skipped:
		return
	falling.position = planet.position + Vector2(-90, 60)
	falling.visible = true
	trail.clear_points()
	Fx.play("sparkle")
	var cam := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam.tween_property(world, "position:y", 0.0, 1.7)
	var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(falling, "position", IMPACT + Vector2(0, -24), 1.7)
	get_tree().create_timer(0.9).timeout.connect(Fx.play.bind("whoosh", 0.7))
	await fall.finished
	falling.visible = false
	trail.clear_points()
	flash(0.9)
	Fx.shake(0.9)
	Fx.play("impact")
	dust.restart()
	guy.position = IMPACT + Vector2(0, -48)
	guy.visible = true
	guy.play("idle1")
	guy.scale = Vector2(4.2, 1.8)
	create_tween().tween_property(guy, "scale", Vector2(3, 3), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _look_around() -> void:
	if skipped:
		return
	guy.flip_h = true
	Fx.play("pop", 0.8, -6.0)
	await wait(0.6)
	guy.flip_h = false
	Fx.play("pop", 0.9, -6.0)
	await wait(0.7)


func _hop() -> void:
	guy.play("jump1")
	guy.scale = Vector2(2.4, 3.6)
	Fx.play("pop", 1.2)
	var tween := create_tween()
	tween.tween_property(guy, "position:y", guy.position.y - 110, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(guy, "scale", Vector2(3, 3), 0.2)
	tween.tween_property(guy, "position:y", guy.position.y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	guy.play("idle1")
	guy.scale = Vector2(3.8, 2.3)
	create_tween().tween_property(guy, "scale", Vector2(3, 3), 0.15)


func _on_skip() -> void:
	_end()


func _end() -> void:
	if _done:
		return
	_done = true
	create_tween().tween_property(music, "volume_db", -40.0, 0.6)
	LevelManager.load_level(0, true)
