extends StaticBody2D

@export_multiline var info_text: String = "Default tip text"

@onready var hit_detector: Area2D = $HitDetector
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var popup: CanvasLayer = $CanvasLayer
@onready var panel: PanelContainer = $CanvasLayer/Panel
@onready var label: Label = $CanvasLayer/Panel/VBox/Label
@onready var hint: Label = $CanvasLayer/Panel/VBox/Hint
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

var is_hit: bool = false
var _typing := false

# tips you've already read this session just bonk instead of popping up again
static var _seen := {}
var _sprite_home := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	label.text = info_text
	popup.visible = false
	_sprite_home = sprite_2d.position
	hit_detector.body_entered.connect(_on_hit)
	# little idle bob so people notice it
	var bob := sprite_2d.create_tween().set_loops()
	bob.tween_property(sprite_2d, "position:y", _sprite_home.y - 3, 0.5).set_delay(1.2)
	bob.tween_property(sprite_2d, "position:y", _sprite_home.y, 0.5)


func _on_hit(body: Node2D) -> void:
	if is_hit or not body.is_in_group("player"):
		return
	is_hit = true
	sprite_2d.frame = 1
	var tween := create_tween()
	tween.tween_property(sprite_2d, "position:y", _sprite_home.y - 15, 0.07)
	tween.tween_property(sprite_2d, "position:y", _sprite_home.y, 0.12).set_trans(Tween.TRANS_BACK)
	Fx.play("bump")
	var key := "%s:%s" % [LevelManager.current_level, info_text]
	if _seen.has(key):
		get_tree().create_timer(0.5, false).timeout.connect(func():
			sprite_2d.frame = 0
			is_hit = false)
		return
	_seen[key] = true
	audio_stream_player_2d.play(0.0)
	_open()


func _open() -> void:
	popup.visible = true
	get_tree().paused = true
	LevelManager.ui_lock += 1
	hint.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.8, 0.8)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	label.visible_characters = 0
	_typing = true
	var total := label.get_total_character_count()
	while _typing and label.visible_characters < total:
		label.visible_characters += 1
		if label.visible_characters % 2 == 0:
			Fx.play_var("blip", 0.1)
		await get_tree().create_timer(0.025).timeout
	_typing = false
	label.visible_characters = -1
	create_tween().tween_property(hint, "modulate:a", 1.0, 0.2)


func _input(event: InputEvent) -> void:
	if not popup.visible:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false
		else:
			close_info()


func close_info() -> void:
	popup.visible = false
	LevelManager.ui_lock = maxi(LevelManager.ui_lock - 1, 0)
	get_tree().paused = false
	Fx.play("ui_back")
	# can be read again after a moment
	await get_tree().create_timer(1.0, false).timeout
	sprite_2d.frame = 0
	is_hit = false
