extends CanvasLayer

# world title cards. LevelManager shows one when you walk into a new world

@onready var card: Control = $Card
@onready var bg: TextureRect = $Card/Bg
@onready var box: VBoxContainer = $Card/Box
@onready var world_num: Label = $Card/Box/WorldNum
@onready var title: Label = $Card/Box/Name
@onready var blurb: Label = $Card/Box/Blurb
@onready var hint: Label = $Card/Hint

var _skip := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	card.visible = false


# called while the screen is still covered by the transition
func show_card(world: int) -> void:
	var w: Dictionary = LevelManager.WORLDS[world]
	bg.texture = w.bg
	world_num.text = "world %d" % (world + 1)
	title.text = w.name
	blurb.text = w.blurb
	blurb.visible_ratio = 0.0
	card.modulate.a = 1.0
	box.modulate.a = 0.0
	hint.modulate.a = 0.0
	card.visible = true
	_skip = false


func finish_card() -> void:
	Fx.play("world")
	var home_x := box.position.x
	box.position.x = home_x - 90.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "position:x", home_x, 0.6)
	tween.tween_property(box, "modulate:a", 1.0, 0.35)
	tween.tween_property(blurb, "visible_ratio", 1.0, 0.8).set_delay(0.35).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(hint, "modulate:a", 1.0, 0.3).set_delay(0.8)
	var t := 0.0
	while t < 2.6 and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
	tween.kill()
	box.position.x = home_x
	var out := create_tween().set_parallel()
	out.tween_property(card, "modulate:a", 0.0, 0.35)
	out.tween_property(box, "position:x", home_x + 60.0, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	await out.finished
	card.visible = false
	box.position.x = home_x


func _input(event: InputEvent) -> void:
	if not card.visible:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or event.is_action_pressed("pause"):
		_skip = true
		get_viewport().set_input_as_handled()
