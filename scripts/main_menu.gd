extends Control

const TITLE := "Third Space"
const VERSION := "v0.4"
const CREDITS := [
	["a game by", "asphaltroads"],
	["tiles, fruit, spikes", "pixel adventure by pixel frog"],
	["fonts", "minecraft font, anak gedong"],
	["sound effects", "made with jsfxr"],
	["engine", "godot 4.7"],
]

# only show "press any key" the first time the menu opens
static var _splash_done := false

@onready var title_root: Control = $Title
@onready var tagline: Label = $Tagline
@onready var menu: VBoxContainer = $Menu
@onready var play_button: Button = $Menu/Play
@onready var levels_button: Button = $Menu/Levels
@onready var options_button: Button = $Menu/Options
@onready var credits_button: Button = $Menu/Credits
@onready var quit_button: Button = $Menu/Quit
@onready var cursor: TextureRect = $Cursor
@onready var press_key: Label = $PressKey
@onready var planet: Sprite2D = $Planet
@onready var player: AnimatedSprite2D = $Player
@onready var ground: TileMapLayer = $Ground
@onready var shooting_star: Line2D = $ShootingStar
@onready var options: PanelContainer = $Options
@onready var credits: PanelContainer = $Credits
@onready var credits_list: VBoxContainer = $Credits/VBox/List
@onready var credits_back: Button = $Credits/VBox/Back
@onready var version: Label = $Version

var _letters: Array[Label] = []
var _t := 0.0
var _player_home := Vector2.ZERO
var _busy_player := false


func _ready() -> void:
	get_tree().paused = false
	version.text = "%s   asphaltroads" % VERSION
	play_button.text = "continue" if LevelManager.highest_beaten() >= 0 else "start"
	quit_button.visible = not OS.has_feature("web")
	_build_title()
	_build_ground()
	_build_credits()
	_player_home = player.position

	play_button.pressed.connect(_on_play)
	levels_button.pressed.connect(_on_levels)
	options_button.pressed.connect(_on_options)
	credits_button.pressed.connect(_on_credits)
	quit_button.pressed.connect(func(): get_tree().quit())
	options.closed.connect(_back_to_menu.bind(options_button))
	credits_back.pressed.connect(_close_credits)
	for b in [play_button, levels_button, options_button, credits_button, quit_button, credits_back]:
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(_on_focus.bind(b))

	if _splash_done:
		press_key.visible = false
		_show_menu(true)
	else:
		menu.visible = false
		cursor.visible = false
		tagline.modulate.a = 0.0
		_title_drop()
	_idle_loop()
	_shooting_star_loop()


func _build_title() -> void:
	var font: Font = get_theme_font("font", &"TitleLabel")
	var size := 168
	var x := 0.0
	for i in TITLE.length():
		var ch := TITLE[i]
		var l := Label.new()
		l.theme_type_variation = &"TitleLabel"
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_constant_override("shadow_offset_x", 9)
		l.add_theme_constant_override("shadow_offset_y", 9)
		l.text = ch
		l.position.x = x
		title_root.add_child(l)
		_letters.append(l)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _title_drop() -> void:
	for i in _letters.size():
		var l := _letters[i]
		l.modulate.a = 0.0
		var tween := l.create_tween().set_parallel()
		tween.tween_property(l, "modulate:a", 1.0, 0.2).set_delay(0.2 + i * 0.05)
		tween.tween_method(func(v: float): l.set_meta("drop", v), -140.0, 0.0, 0.55).set_delay(0.2 + i * 0.05) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(tagline, "modulate:a", 1.0, 0.5).set_delay(1.0)
	var blink := press_key.create_tween().set_loops()
	blink.tween_property(press_key, "modulate:a", 0.25, 0.6).set_delay(0.3)
	blink.tween_property(press_key, "modulate:a", 1.0, 0.6)


func _build_ground() -> void:
	# W1 dirt, same tiles as the levels. a little mound for the guy to stand on
	for x in range(0, 40):
		var top := 19 if x >= 27 and x <= 32 else 20
		for y in range(top, 23):
			var atlas := Vector2i(7, 1)
			if y == top:
				atlas = Vector2i(7, 0)
				if x == 27:
					atlas = Vector2i(6, 0)
				elif x == 32:
					atlas = Vector2i(8, 0)
			elif y == 20 and top == 19 and (x == 27 or x == 32):
				atlas = Vector2i(6, 1) if x == 27 else Vector2i(8, 1)
			ground.set_cell(Vector2i(x, y), 0, atlas)


func _build_credits() -> void:
	for line in CREDITS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var a := Label.new()
		a.theme_type_variation = &"SmallLabel"
		a.text = line[0]
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b := Label.new()
		b.text = line[1]
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(a)
		row.add_child(b)
		credits_list.add_child(row)


func _process(delta: float) -> void:
	_t += delta
	for i in _letters.size():
		var l := _letters[i]
		var wave := roundf(sin(_t * 2.2 - i * 0.55) * 2.0) * 3.0
		l.position.y = wave + float(l.get_meta("drop", 0.0))
	planet.position.y = 250.0 + roundf(sin(_t * 0.8) * 3.0) * 3.0
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and focused.get_parent() == menu and menu.visible:
		cursor.visible = true
		var target := Vector2(focused.global_position.x - 42, focused.global_position.y + focused.size.y / 2.0 - 16)
		target.x += roundf(sin(_t * 6.0)) * 3.0
		cursor.global_position = cursor.global_position.lerp(target, minf(1.0, delta * 18.0))
	else:
		cursor.visible = false


func _input(event: InputEvent) -> void:
	if _splash_done:
		return
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed()
	if pressed:
		_splash_done = true
		get_viewport().set_input_as_handled()
		Fx.play("start")
		var tween := press_key.create_tween()
		tween.tween_property(press_key, "modulate:a", 0.0, 0.15)
		tween.tween_callback(press_key.hide)
		_show_menu()


func _show_menu(instant := false) -> void:
	menu.visible = true
	tagline.modulate.a = 1.0
	for l in _letters:
		l.modulate.a = 1.0
		l.set_meta("drop", 0.0)
	var i := 0
	for b in menu.get_children():
		if not b.visible:
			continue
		if instant:
			b.modulate.a = 1.0
			continue
		b.modulate.a = 0.0
		var tween := b.create_tween()
		tween.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(i * 0.06)
		i += 1
	cursor.global_position = Vector2(menu.global_position.x - 42, play_button.global_position.y + 8)
	play_button.grab_focus()


func _on_focus(b: Button) -> void:
	if menu.visible or credits.visible:
		Fx.play("ui_move")
	if b.get_parent() == menu:
		for other in menu.get_children():
			var tw := other.create_tween()
			tw.tween_property(other, "position:x", 18.0 if other == b else 0.0, 0.12)


func _on_play() -> void:
	Fx.play("ui_select")
	player.play("jump1")
	LevelManager.start_game()


func _on_levels() -> void:
	Fx.play("ui_select")
	LevelManager.change_scene(LevelManager.LEVEL_SELECT)


func _on_options() -> void:
	Fx.play("ui_select")
	menu.visible = false
	options.open()


func _on_credits() -> void:
	Fx.play("ui_select")
	menu.visible = false
	credits.visible = true
	credits_back.grab_focus()


func _close_credits() -> void:
	Fx.play("ui_back")
	credits.visible = false
	_back_to_menu(credits_button)


func _back_to_menu(focus: Button) -> void:
	menu.visible = true
	focus.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if credits.visible and event.is_action_pressed("ui_cancel"):
		_close_credits()
		get_viewport().set_input_as_handled()


# the little guy does stuff while you sit on the menu
func _idle_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.5, 5.0)).timeout
		if not is_inside_tree():
			return
		match randi() % 3:
			0:
				await _player_hop()
			1:
				player.flip_h = not player.flip_h
			2:
				await _player_hop()
				await _player_hop()


func _player_hop() -> void:
	player.play("jump1")
	player.scale = Vector2(2.4, 3.6)
	var tween := create_tween()
	tween.tween_property(player, "position:y", _player_home.y - 72, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(player, "scale", Vector2(3, 3), 0.15)
	tween.tween_property(player, "position:y", _player_home.y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	player.play("idle1")
	player.scale = Vector2(3.8, 2.3)
	create_tween().tween_property(player, "scale", Vector2(3, 3), 0.15)


func _shooting_star_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(4.0, 9.0)).timeout
		if not is_inside_tree():
			return
		var start := Vector2(randf_range(700, 1800), randf_range(40, 260))
		var dir := Vector2(-1, 0.45).normalized()
		shooting_star.visible = true
		var tween := create_tween()
		tween.tween_method(func(t: float):
			var head := start + dir * t * 700.0
			var tail := start + dir * maxf(0.0, t - 0.3) * 700.0
			shooting_star.points = PackedVector2Array([tail.round(), head.round()])
			shooting_star.modulate.a = 1.0 - maxf(0.0, t - 0.7) / 0.3, 0.0, 1.0, 0.7)
		await tween.finished
		shooting_star.visible = false
