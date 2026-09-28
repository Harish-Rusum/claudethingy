extends CanvasLayer

const STAR := preload("res://assets/ui/icon_star.png")
const STAR_EMPTY := preload("res://assets/ui/icon_star_empty.png")

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var clear_label: Label = $Panel/VBox/Clear
@onready var tag: Label = $Panel/VBox/Tag
@onready var star_icons: Array[TextureRect] = [$Panel/VBox/Stars/S1/Icon, $Panel/VBox/Stars/S2/Icon, $Panel/VBox/Stars/S3/Icon]
@onready var par_labels: Array[Label] = [$Panel/VBox/Stars/S1/Par, $Panel/VBox/Stars/S2/Par, $Panel/VBox/Stars/S3/Par]
@onready var time_label: Label = $Panel/VBox/Time/Value
@onready var best_label: Label = $Panel/VBox/Best
@onready var deaths_label: Label = $Panel/VBox/Deaths/Value
@onready var extra_label: Label = $Panel/VBox/Extra
@onready var next_button: Button = $Panel/VBox/Buttons/Next
@onready var retry_button: Button = $Panel/VBox/Buttons/Retry
@onready var levels_button: Button = $Panel/VBox/Buttons/Levels

var _time := 0.0
var _stars := 1
var _new_best := false
var _live := false
var _skip := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	next_button.pressed.connect(_on_next)
	retry_button.pressed.connect(_on_retry)
	levels_button.pressed.connect(_on_levels)
	for b in [next_button, retry_button, levels_button]:
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(func(): if _live: Fx.play("ui_move"))


func setup(index: int, time: float, stars: int, old_best: float, new_best: bool, deaths: int, unlocked_world: bool) -> void:
	_time = time
	_stars = stars
	_new_best = new_best
	tag.text = "%s   %s" % [LevelManager.level_tag(index), LevelManager.level_data(index).name]
	var par: Array = LevelManager.level_data(index).stars
	par_labels[0].text = "finish"
	par_labels[1].text = "< %.1fs" % par[1]
	par_labels[2].text = "< %.1fs" % par[0]
	if new_best and old_best < INF:
		best_label.text = "new best! (was %.2fs)" % old_best
	elif new_best:
		best_label.text = "new best!"
	else:
		best_label.text = "best %.2fs" % old_best
	deaths_label.text = str(deaths)
	extra_label.visible = unlocked_world
	if unlocked_world:
		extra_label.text = "world %d unlocked" % (LevelManager.world_of(index + 1) + 1)
	if index == LevelManager.levels.size() - 1:
		next_button.text = "finish"
	_play()


func _play() -> void:
	LevelManager.ui_lock += 1
	# let the fruit pop before freezing everything
	await get_tree().create_timer(0.45, true, false, true).timeout
	get_tree().paused = true
	LevelManager.set_muffled(true)
	visible = true
	for i in 3:
		star_icons[i].texture = STAR_EMPTY
	time_label.text = "0.00s"
	best_label.modulate.a = 0.0
	extra_label.modulate.a = 0.0
	dim.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	clear_label.pivot_offset = clear_label.size / 2.0
	clear_label.scale = Vector2(2.2, 2.2)
	clear_label.rotation = -0.05

	var tween := create_tween().set_parallel()
	tween.tween_property(dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(clear_label, "scale", Vector2.ONE, 0.3).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.play("clear")
	await tween.finished

	# count the time up
	var t := 0.0
	while t < 0.55 and not _skip:
		t += get_process_delta_time()
		time_label.text = "%.2fs" % (_time * minf(t / 0.55, 1.0))
		await get_tree().process_frame
	time_label.text = "%.2fs" % _time

	for i in _stars:
		if not _skip:
			await get_tree().create_timer(0.22).timeout
		_pop_star(i)

	var tw := create_tween().set_parallel()
	tw.tween_property(best_label, "modulate:a", 1.0, 0.2)
	tw.tween_property(extra_label, "modulate:a", 1.0, 0.2)
	if _new_best:
		Fx.play("new_best")
		best_label.add_theme_color_override("font_color", Color("edb4a1"))
		var blink := best_label.create_tween().set_loops()
		blink.tween_property(best_label, "modulate", Color(1.3, 1.3, 1.3), 0.3)
		blink.tween_property(best_label, "modulate", Color.WHITE, 0.3)
	_live = true
	next_button.grab_focus()


func _pop_star(i: int) -> void:
	var icon := star_icons[i]
	icon.texture = STAR
	icon.pivot_offset = icon.size / 2.0
	icon.scale = Vector2(1.7, 1.7)
	icon.rotation = -0.3
	var tween := icon.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.3)
	tween.tween_property(icon, "rotation", 0.0, 0.3)
	Fx.play("star", 1.0 + i * 0.14)
	Fx.shake(0.12)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not _live:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
			_skip = true
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart"):
		_on_retry()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_levels()


func _leave() -> void:
	_live = false
	LevelManager.ui_lock = maxi(LevelManager.ui_lock - 1, 0)
	LevelManager.set_muffled(false)
	Fx.play("ui_select")


func _on_next() -> void:
	if not _live:
		return
	_leave()
	LevelManager.go_to_next_level()


func _on_retry() -> void:
	if not _live:
		return
	_leave()
	LevelManager.restart_level()


func _on_levels() -> void:
	if not _live:
		return
	_leave()
	LevelManager.go_to_level_select()
