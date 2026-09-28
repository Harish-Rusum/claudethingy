extends CanvasLayer

const STAR := preload("res://assets/ui/icon_star_small.png")
const STAR_EMPTY := preload("res://assets/ui/icon_star_small_empty.png")

@onready var panel: PanelContainer = $Panel
@onready var tag: Label = $Panel/VBox/Tag
@onready var deaths_label: Label = $Panel/VBox/Stats/Deaths
@onready var best_label: Label = $Panel/VBox/Stats/Best
@onready var stars_box: HBoxContainer = $Panel/VBox/Stats/Stars
@onready var resume_button: Button = $Panel/VBox/Resume
@onready var restart_button: Button = $Panel/VBox/Restart
@onready var options_button: Button = $Panel/VBox/Options
@onready var levels_button: Button = $Panel/VBox/Levels
@onready var menu_button: Button = $Panel/VBox/Menu
@onready var options: PanelContainer = $Options


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(resume)
	restart_button.pressed.connect(func():
		_unpause()
		LevelManager.restart_level())
	options_button.pressed.connect(_open_options)
	levels_button.pressed.connect(func():
		_unpause()
		LevelManager.go_to_level_select())
	menu_button.pressed.connect(func():
		_unpause()
		LevelManager.go_to_menu())
	options.closed.connect(func():
		panel.visible = true
		options_button.grab_focus())
	for b in [resume_button, restart_button, options_button, levels_button, menu_button]:
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(func(): if visible: Fx.play("ui_move"))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		if options.visible:
			return # options handles its own back
		resume()
		get_viewport().set_input_as_handled()
	elif _can_pause():
		open()
		get_viewport().set_input_as_handled()


func _can_pause() -> bool:
	if LevelManager.ui_lock > 0 or LevelManager.is_changing or get_tree().paused:
		return false
	var player := get_tree().get_first_node_in_group("player")
	return player == null or not (player.is_dead or player.reached_goal)


func open() -> void:
	var i := LevelManager.current_level
	tag.text = "%s   %s" % [LevelManager.level_tag(i), LevelManager.level_data(i).name]
	deaths_label.text = str(LevelManager.level_deaths)
	if LevelManager.best_times.has(i):
		best_label.text = "best %.2fs" % LevelManager.best_times[i]
	else:
		best_label.text = "cleared" if LevelManager.level_stars.has(i) else "no clear yet"
	var got: int = LevelManager.level_stars.get(i, 0)
	for n in stars_box.get_child_count():
		stars_box.get_child(n).texture = STAR if n < got else STAR_EMPTY
	visible = true
	panel.visible = true
	options.visible = false
	get_tree().paused = true
	LevelManager.set_muffled(true)
	Fx.play("ui_select")
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	resume_button.grab_focus()


func resume() -> void:
	Fx.play("ui_back")
	_unpause()


func _unpause() -> void:
	visible = false
	get_tree().paused = false
	LevelManager.set_muffled(false)


func _open_options() -> void:
	panel.visible = false
	options.open()
