extends Node2D

# rotate the node to aim it. 0 = shoots right, 90 = down, etc.
@export var always_on := false
@export var on_time := 1.2
@export var off_time := 1.4
# shifts the timing so a row of lasers can take turns
@export var delay := 0.0
@export var max_length := 2400.0

const WARN_TIME := 0.5
const BEAM_START := 21.0

@onready var emitter: Sprite2D = $Emitter
@onready var ray: RayCast2D = $RayCast2D
@onready var beam: Line2D = $Beam
@onready var glow: Line2D = $Glow
@onready var warn: Line2D = $Warn
@onready var shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var sparks: CPUParticles2D = $Sparks
@onready var sound: AudioStreamPlayer2D = $Sound

var _t := 0.0
var _state := -1
var _flicker := 0.0


func _ready() -> void:
	shape.shape = shape.shape.duplicate()
	ray.target_position = Vector2(max_length, 0)
	_update_length()
	_set_state(2 if always_on else _state_at(0.0), true)


func _physics_process(delta: float) -> void:
	_t += delta
	_update_length()
	_set_state(2 if always_on else _state_at(_t))


func _process(delta: float) -> void:
	_flicker -= delta
	if _flicker <= 0.0:
		_flicker = 0.05
		beam.width = [18.0, 21.0, 21.0, 24.0][randi() % 4]
		glow.width = beam.width * 2.5
	if _state == 1:
		warn.visible = int(_t * 16.0) % 2 == 0


func _state_at(t: float) -> int:
	var period := on_time + off_time
	var phase := fposmod(t + delay, period)
	if phase < on_time:
		return 2
	if phase > period - WARN_TIME:
		return 1
	return 0


func _update_length() -> void:
	ray.force_raycast_update()
	var length := max_length
	if ray.is_colliding():
		length = to_local(ray.get_collision_point()).length()
	var pts := PackedVector2Array([Vector2(BEAM_START, 0), Vector2(length, 0)])
	beam.points = pts
	glow.points = pts
	warn.points = pts
	var rect: RectangleShape2D = shape.shape
	rect.size = Vector2(maxf(length - BEAM_START, 1.0), 12.0)
	shape.position = Vector2((BEAM_START + length) / 2.0, 0)
	sparks.position = Vector2(length, 0)


func _set_state(s: int, force := false) -> void:
	if s == _state and not force:
		return
	var was := _state
	_state = s
	emitter.frame = s
	beam.visible = s == 2
	glow.visible = s == 2
	warn.visible = s == 1
	sparks.emitting = s == 2
	shape.set_deferred("disabled", s != 2)
	if force:
		return
	if s == 1:
		sound.stream = Fx.SOUNDS["laser_charge"]
		sound.play()
	elif s == 2 and was != 2:
		sound.stream = Fx.SOUNDS["laser_fire"]
		sound.play()
