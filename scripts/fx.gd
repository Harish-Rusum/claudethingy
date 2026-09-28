extends Node

const SOUNDS := {
	"ui_move": preload("res://assets/sounds/sfx/ui_move.wav"),
	"ui_select": preload("res://assets/sounds/sfx/ui_select.wav"),
	"ui_back": preload("res://assets/sounds/sfx/ui_back.wav"),
	"card": preload("res://assets/sounds/sfx/card_deal.wav"),
	"boost_pick": preload("res://assets/sounds/sfx/boost_pick.wav"),
	"skip": preload("res://assets/sounds/sfx/skip.wav"),
	"dash": preload("res://assets/sounds/sfx/dash.wav"),
	"double_jump": preload("res://assets/sounds/sfx/double_jump.wav"),
	"glide": preload("res://assets/sounds/sfx/glide.wav"),
	"shield_up": preload("res://assets/sounds/sfx/shield_up.wav"),
	"shield_down": preload("res://assets/sounds/sfx/shield_down.wav"),
	"laser_charge": preload("res://assets/sounds/sfx/laser_charge.wav"),
	"laser_fire": preload("res://assets/sounds/sfx/laser_fire.wav"),
	"crumble": preload("res://assets/sounds/sfx/crumble.wav"),
	"crack": preload("res://assets/sounds/sfx/crack.wav"),
	"star": preload("res://assets/sounds/sfx/star.wav"),
	"tick": preload("res://assets/sounds/sfx/tick.wav"),
	"blip": preload("res://assets/sounds/sfx/blip.wav"),
	"impact": preload("res://assets/sounds/sfx/impact.wav"),
	"whoosh": preload("res://assets/sounds/sfx/whoosh.wav"),
	"bump": preload("res://assets/sounds/sfx/bump.wav"),
	"land": preload("res://assets/sounds/sfx/land.wav"),
	"pop": preload("res://assets/sounds/sfx/pop.wav"),
	"thud": preload("res://assets/sounds/sfx/thud.wav"),
	"sparkle": preload("res://assets/sounds/sfx/sparkle.wav"),
	"clear": preload("res://assets/sounds/sfx/clear.wav"),
	"world": preload("res://assets/sounds/sfx/world.wav"),
	"fanfare": preload("res://assets/sounds/sfx/fanfare.wav"),
	"new_best": preload("res://assets/sounds/sfx/new_best.wav"),
	"start": preload("res://assets/sounds/sfx/start.wav"),
}

var shake_on := true

var _trauma := 0.0
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not SOUNDS.has(sound):
		push_warning("no sound called " + sound)
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = SOUNDS[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


# same as play() but a little random so repeated sounds don't get annoying
func play_var(sound: String, spread := 0.08, volume_db := 0.0) -> void:
	play(sound, randf_range(1.0 - spread, 1.0 + spread), volume_db)


func shake(amount: float) -> void:
	if shake_on:
		_trauma = minf(_trauma + amount, 1.0)


# tiny freeze frame, sells hits way more than it should
func hitstop(duration := 0.07) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	var vp := get_viewport()
	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 2.4, 0.0)
		var s := _trauma * _trauma * 21.0
		# snap to the 3px art grid so the pixels don't smear
		var off := (Vector2(randf_range(-s, s), randf_range(-s, s)) / 3.0).round() * 3.0
		vp.canvas_transform = Transform2D(0.0, off)
	elif vp.canvas_transform.origin != Vector2.ZERO:
		vp.canvas_transform = Transform2D.IDENTITY
