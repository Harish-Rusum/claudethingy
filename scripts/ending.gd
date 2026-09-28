extends Cutscene

const CREDITS := [
	["", "third space"],
	["a game by", "asphaltroads"],
	["tiles, fruit, spikes", "pixel adventure by pixel frog"],
	["fonts", "minecraft font, anak gedong"],
	["sound effects", "made with jsfxr"],
	["engine", "godot 4.7"],
	["", ""],
	["", "thanks for playing"],
]

@onready var guy: AnimatedSprite2D = $Guy
@onready var planet: Sprite2D = $Planet
@onready var island: TileMapLayer = $Island
@onready var beam: Line2D = $Beam
@onready var sparkles: CPUParticles2D = $Guy/Sparkles
@onready var burst: CPUParticles2D = $Burst
@onready var new_star: Sprite2D = $NewStar
@onready var dust: CPUParticles2D = $Dust
@onready var music: AudioStreamPlayer = $Music
@onready var stats: PanelContainer = $UI2/Stats
@onready var stat_stars: Label = $UI2/Stats/VBox/Grid/Stars
@onready var stat_deaths: Label = $UI2/Stats/VBox/Grid/Deaths
@onready var stat_time: Label = $UI2/Stats/VBox/Grid/Time
@onready var roll: VBoxContainer = $UI2/Roll
@onready var press: Label = $UI2/Press

const STAND := Vector2(552, 768)
var _ring_point := Vector2.ZERO
var _waiting_for_key := false


func _ready() -> void:
	# floating island: cols 9-13, rows 17-18
	for x in range(9, 14):
		var ax := 0 if x == 9 else (2 if x == 13 else 1)
		island.set_cell(Vector2i(x, 17), 1, Vector2i(ax, 0))
		island.set_cell(Vector2i(x, 18), 1, Vector2i(ax, 2))
	_ring_point = planet.position + Vector2(-190, 70)
	new_star.position = _ring_point
	new_star.visible = false
	guy.visible = false
	beam.width = 0.0
	stats.visible = false
	press.visible = false
	_build_roll()
	_run()


func _build_roll() -> void:
	for line in CREDITS:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		if line[0] != "":
			var a := Label.new()
			a.theme_type_variation = &"SmallLabel"
			a.text = line[0]
			a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(a)
		var b := Label.new()
		b.text = line[1]
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if line[0] == "":
			b.theme_type_variation = &"TitleLabel"
			b.add_theme_font_size_override("font_size", 72)
		box.add_child(b)
		roll.add_child(box)
	roll.modulate.a = 0.0


func _run() -> void:
	await bars(true)
	await _land()
	await wait(0.8)
	await say("okay. that's close enough.", 1.2)
	await _beam_down()
	await _float_up()
	await wait(0.8)
	await say("home.", 1.8)
	if skipped:
		return
	await bars(false)
	await _show_stats()


func _land() -> void:
	if skipped:
		return
	guy.visible = true
	guy.position = Vector2(STAND.x, -120)
	guy.play("jump2")
	var tween := create_tween()
	tween.tween_property(guy, "position:y", STAND.y, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	guy.play("idle2")
	guy.scale = Vector2(4.2, 1.8)
	create_tween().tween_property(guy, "scale", Vector2(3, 3), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	dust.restart()
	Fx.play("thud")
	Fx.shake(0.3)


func _beam_down() -> void:
	if skipped:
		return
	Fx.play("sparkle")
	var glow := create_tween().set_loops(3)
	glow.tween_property(planet, "modulate", Color(1.4, 1.2, 1.3), 0.25)
	glow.tween_property(planet, "modulate", Color.WHITE, 0.25)
	await wait(1.4)
	beam.points = PackedVector2Array([_ring_point, STAND + Vector2(0, 48)])
	Fx.play("shield_up", 0.7)
	var tween := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(beam, "width", 60.0, 0.5)
	await tween.finished
	await wait(0.6)


func _float_up() -> void:
	if skipped:
		return
	guy.play("jump2")
	sparkles.emitting = true
	var from := guy.position
	var tween := create_tween().set_parallel()
	tween.tween_method(func(t: float):
		var p := from.lerp(_ring_point, t)
		p.x += sin(t * PI * 3.0) * 40.0 * (1.0 - t)
		guy.position = p.round(), 0.0, 1.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(guy, "scale", Vector2(1.2, 1.2), 2.6)
	tween.tween_property(beam, "width", 0.0, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	guy.visible = false
	sparkles.emitting = false
	burst.position = _ring_point
	burst.restart()
	flash(0.6, 0.5)
	Fx.play("fanfare")
	new_star.visible = true
	var twinkle := new_star.create_tween().set_loops()
	twinkle.tween_property(new_star, "scale", Vector2(5, 5), 0.5).set_trans(Tween.TRANS_SINE)
	twinkle.tween_property(new_star, "scale", Vector2(3.5, 3.5), 0.5).set_trans(Tween.TRANS_SINE)


func _show_stats() -> void:
	var levels := LevelManager.levels.size()
	stat_stars.text = "%d / %d" % [LevelManager.total_stars(), levels * 3]
	stat_deaths.text = str(LevelManager.deaths)
	var total := 0.0
	for i in LevelManager.best_times:
		total += LevelManager.best_times[i]
	stat_time.text = "%d:%05.2f" % [int(total) / 60, fmod(total, 60.0)]
	stats.visible = true
	stats.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(stats, "modulate:a", 1.0, 0.6)
	await tween.finished
	await get_tree().create_timer(4.5).timeout
	tween = create_tween()
	tween.tween_property(stats, "modulate:a", 0.0, 0.6)
	await tween.finished
	stats.visible = false
	# credits roll up from the bottom and the last line parks in the middle
	roll.modulate.a = 1.0
	roll.position.y = 1100.0
	var end_y := 540.0 - roll.size.y + 60.0
	tween = create_tween()
	tween.tween_property(roll, "position:y", end_y, 12.0)
	await tween.finished
	press.visible = true
	var blink := press.create_tween().set_loops()
	blink.tween_property(press, "modulate:a", 0.3, 0.6)
	blink.tween_property(press, "modulate:a", 1.0, 0.6)
	_waiting_for_key = true


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_for_key and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		_end()


func _on_skip() -> void:
	_end()


func _end() -> void:
	if _done:
		return
	_done = true
	create_tween().tween_property(music, "volume_db", -40.0, 0.8)
	LevelManager.go_to_menu()
