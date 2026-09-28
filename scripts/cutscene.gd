class_name Cutscene
extends Node2D

# shared bits for the intro/ending. hold esc/space to skip

const BAR_HEIGHT := 132.0
const SKIP_TIME := 0.8

@onready var bar_top: ColorRect = $UI/BarTop
@onready var bar_bottom: ColorRect = $UI/BarBottom
@onready var caption: Label = $UI/Caption
@onready var flash_rect: ColorRect = $UI/Flash
@onready var skip_box: Control = $UI/Skip
@onready var skip_fill: ColorRect = $UI/Skip/Bar/Fill

var skipped := false
var _hold := 0.0
var _done := false


func _process(delta: float) -> void:
	var holding := Input.is_action_pressed("pause") or Input.is_action_pressed("jump") or Input.is_action_pressed("ui_accept")
	if holding:
		_hold += delta
	else:
		_hold = maxf(_hold - delta * 2.0, 0.0)
	skip_box.modulate.a = move_toward(skip_box.modulate.a, 1.0 if _hold > 0.0 else 0.4, delta * 4.0)
	skip_fill.size.x = floorf((skip_fill.get_parent().size.x - 6.0) * clampf(_hold / SKIP_TIME, 0.0, 1.0) / 3.0) * 3.0
	if _hold >= SKIP_TIME and not skipped:
		skipped = true
		_on_skip()


# override in the actual cutscene
func _on_skip() -> void:
	pass


func bars(show: bool, time := 0.6) -> void:
	var h := BAR_HEIGHT if show else 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar_top, "size:y", h, time)
	tween.tween_property(bar_bottom, "size:y", h, time)
	tween.tween_property(bar_bottom, "position:y", 1080.0 - h, time)
	await tween.finished


func say(text: String, hold := 1.4) -> void:
	if skipped:
		return
	caption.text = text
	caption.visible_characters = 0
	caption.modulate.a = 1.0
	for i in text.length():
		if skipped:
			return
		caption.visible_characters = i + 1
		if text[i] != " " and i % 2 == 0:
			Fx.play_var("blip", 0.12, -3.0)
		await get_tree().create_timer(0.04).timeout
	await wait(hold)
	var tween := create_tween()
	tween.tween_property(caption, "modulate:a", 0.0, 0.3)
	await tween.finished


func wait(t: float) -> void:
	if skipped:
		return
	await get_tree().create_timer(t).timeout


func flash(strength := 0.85, time := 0.4) -> void:
	flash_rect.color.a = strength
	create_tween().tween_property(flash_rect, "color:a", 0.0, time)


# W1 or W4 tiles along the bottom so the scene sits on the same ground as the levels
func lay_ground(layer: TileMapLayer, source: int, top_row: int, from_x := 0, to_x := 40) -> void:
	for x in range(from_x, to_x):
		for y in range(top_row, 23):
			var ax := 1
			if x == from_x and from_x > 0:
				ax = 0
			elif x == to_x - 1 and to_x < 40:
				ax = 2
			var ay := 0 if y == top_row else 1
			var atlas := Vector2i(ax, ay) if source == 1 else Vector2i(6 + ax, ay)
			layer.set_cell(Vector2i(x, y), source, atlas)
