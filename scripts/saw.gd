extends Area2D

# travel = where it slides to (relative), leave at zero for a saw that just sits there
@export var travel := Vector2.ZERO
@export var move_time := 2.0
# orbit_radius > 0 makes it go round in a circle instead
@export var orbit_radius := 0.0
@export var orbit_speed := 1.6
@export var phase := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var rail: Node2D = $Rail

var _start := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	_start = position
	rail.top_level = true
	rail.global_position = global_position
	rail.draw.connect(_draw_rail)
	rail.queue_redraw()
	sprite.play("spin")
	_move(0.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_move(_t)


func _move(t: float) -> void:
	if orbit_radius > 0.0:
		var a := t * orbit_speed + phase * TAU
		position = _start + Vector2(cos(a), sin(a)) * orbit_radius
	elif travel != Vector2.ZERO:
		var k := pingpong(t / move_time + phase * 2.0, 1.0)
		position = _start + travel * smoothstep(0.0, 1.0, k)


func _draw_rail() -> void:
	var ink := Color("1b0f1e", 0.7)
	var dot := Color("9775a6", 0.7)
	if orbit_radius > 0.0:
		var steps := int(TAU * orbit_radius / 30.0)
		for i in steps:
			var p := (Vector2.from_angle(TAU * i / steps) * orbit_radius / 3.0).round() * 3.0
			rail.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), ink)
			rail.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), dot)
	elif travel != Vector2.ZERO:
		var steps := int(travel.length() / 30.0)
		for i in steps + 1:
			var p := (travel * float(i) / maxf(steps, 1) / 3.0).round() * 3.0
			rail.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), ink)
			rail.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), dot)
