extends AnimatableBody2D

@export var travel := Vector2(0, -192)
@export var move_time := 2.0
@export var pause_time := 0.5
@export var phase := 0.0
@export_enum("cave", "space", "wood") var skin := "cave"

const SKINS := {
	"cave": preload("res://assets/traps/platform/platform_cave.png"),
	"space": preload("res://assets/traps/platform/platform_space.png"),
	"wood": preload("res://assets/traps/platform/platform_wood.png"),
}

@onready var sprite: Sprite2D = $Sprite2D
@onready var rail: Node2D = $Rail

var _start := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	sprite.texture = SKINS[skin]
	_start = position
	rail.top_level = true
	rail.global_position = global_position
	rail.draw.connect(_draw_rail)
	rail.queue_redraw()
	position = _start + travel * _offset(0.0)


func _physics_process(delta: float) -> void:
	_t += delta
	position = _start + travel * _offset(_t)


# 0..1 along the path, with a little rest at each end
func _offset(t: float) -> float:
	var leg := move_time + pause_time
	var cycle := fposmod(t + phase * leg * 2.0, leg * 2.0)
	if cycle < pause_time:
		return 0.0
	if cycle < leg:
		return smoothstep(0.0, 1.0, (cycle - pause_time) / move_time)
	if cycle < leg + pause_time:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (cycle - leg - pause_time) / move_time)


func _draw_rail() -> void:
	var steps := int(travel.length() / 30.0)
	for i in steps + 1:
		var p := (travel * float(i) / maxf(steps, 1) / 3.0).round() * 3.0 + Vector2(0, 12)
		rail.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), Color("1b0f1e", 0.6))
		rail.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color("9775a6", 0.6))
