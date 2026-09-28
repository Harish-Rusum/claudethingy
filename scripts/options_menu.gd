extends PanelContainer

signal closed

@export var show_reset := false

@onready var master_slider: HSlider = $VBox/Grid/Master
@onready var music_slider: HSlider = $VBox/Grid/Music
@onready var sfx_slider: HSlider = $VBox/Grid/Sfx
@onready var fullscreen: CheckButton = $VBox/Grid/Fullscreen
@onready var shake: CheckButton = $VBox/Grid/Shake
@onready var reset_button: Button = $VBox/Buttons/Reset
@onready var back_button: Button = $VBox/Buttons/Back

var _reset_armed := false
var _last_blip := 0


func _ready() -> void:
	visible = false
	reset_button.visible = show_reset
	master_slider.value = LevelManager.settings.master
	music_slider.value = LevelManager.settings.music
	sfx_slider.value = LevelManager.settings.sfx
	fullscreen.button_pressed = LevelManager.settings.fullscreen
	shake.button_pressed = LevelManager.settings.shake
	master_slider.value_changed.connect(_on_volume.bind("master"))
	music_slider.value_changed.connect(_on_volume.bind("music"))
	sfx_slider.value_changed.connect(_on_volume.bind("sfx"))
	fullscreen.toggled.connect(func(on: bool):
		LevelManager.set_fullscreen(on)
		Fx.play("ui_select"))
	shake.toggled.connect(func(on: bool):
		LevelManager.settings.shake = on
		Fx.shake_on = on
		Fx.play("ui_select")
		Fx.shake(0.35))
	reset_button.pressed.connect(_on_reset)
	back_button.pressed.connect(close)
	for c in [master_slider, music_slider, sfx_slider, fullscreen, shake, reset_button, back_button]:
		c.mouse_entered.connect(c.grab_focus)
		c.focus_entered.connect(func(): if visible: Fx.play("ui_move"))


func open() -> void:
	visible = true
	_reset_armed = false
	reset_button.text = "reset progress"
	fullscreen.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	pivot_offset = size / 2.0
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	master_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	LevelManager.save_game()
	Fx.play("ui_back")
	visible = false
	closed.emit()


func _on_volume(value: float, key: String) -> void:
	LevelManager.settings[key] = value
	LevelManager.apply_settings()
	# little blip so you can hear the new volume (not every single step though)
	var now := Time.get_ticks_msec()
	if key != "music" and now - _last_blip > 90:
		_last_blip = now
		Fx.play("ui_move", 1.0 + value * 0.3)


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		reset_button.text = "you sure? again to wipe"
		Fx.play("ui_back")
		return
	LevelManager.reset_progress()
	reset_button.text = "done. fresh start"
	Fx.play("crumble")
	Fx.shake(0.3)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()
