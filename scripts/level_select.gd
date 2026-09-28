extends Control

const NODE_OPEN := preload("res://assets/ui/node_open.png")
const NODE_DONE := preload("res://assets/ui/node_done.png")
const NODE_LOCKED := preload("res://assets/ui/node_locked.png")
const STAR := preload("res://assets/ui/icon_star_small.png")
const STAR_EMPTY := preload("res://assets/ui/icon_star_small_empty.png")
const LOCK := preload("res://assets/ui/icon_lock.png")
const NODE_SIZE := 72.0

# where the 5 level stops sit on each world's map (screen coords)
const SPOTS := [
	[Vector2(330, 650), Vector2(640, 520), Vector2(960, 610), Vector2(1280, 480), Vector2(1590, 570)],
	[Vector2(330, 520), Vector2(640, 640), Vector2(960, 500), Vector2(1280, 630), Vector2(1590, 480)],
	[Vector2(330, 560), Vector2(640, 680), Vector2(960, 560), Vector2(1280, 690), Vector2(1590, 580)],
	[Vector2(330, 690), Vector2(640, 610), Vector2(960, 520), Vector2(1280, 440), Vector2(1590, 350)],
]

@onready var bg: TextureRect = $Bg
@onready var bg_old: TextureRect = $BgOld
@onready var map: Control = $Map
@onready var walker: AnimatedSprite2D = $Walker
@onready var world_num: Label = $Header/WorldNum
@onready var world_name: Label = $Header/WorldName
@onready var arrow_l: TextureButton = $ArrowL
@onready var arrow_r: TextureButton = $ArrowR
@onready var total_label: Label = $Total/Count
@onready var info_tag: Label = $Info/HBox/Left/Tag
@onready var info_name: Label = $Info/HBox/Left/Name
@onready var info_best: Label = $Info/HBox/Mid/Best
@onready var info_par: Label = $Info/HBox/Mid/Par
@onready var info_stars: HBoxContainer = $Info/HBox/Stars
@onready var play_hint: Label = $Info/HBox/Play
@onready var back_button: Button = $Back

var _sel := 0
var _world := 0
var _nodes: Array[Control] = []
var _busy := false


func _ready() -> void:
	_sel = LevelManager.current_level if LevelManager.is_unlocked(LevelManager.current_level) else LevelManager.first_unfinished()
	_world = LevelManager.world_of(_sel)
	total_label.text = "%d / %d" % [LevelManager.total_stars(), LevelManager.levels.size() * 3]
	map.draw.connect(_draw_path)
	back_button.pressed.connect(_back)
	back_button.mouse_entered.connect(back_button.grab_focus)
	arrow_l.pressed.connect(_switch_world.bind(-1))
	arrow_r.pressed.connect(_switch_world.bind(1))
	_build_world()
	_place_walker(true)
	_update_info()


func _build_world() -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	var w: Dictionary = LevelManager.WORLDS[_world]
	bg.texture = w.bg
	world_num.text = "world %d" % (_world + 1)
	world_name.text = w.name
	arrow_l.visible = _world > 0
	arrow_r.visible = _world < LevelManager.WORLDS.size() - 1
	for i in LevelManager.LEVELS_PER_WORLD:
		var index := _world * LevelManager.LEVELS_PER_WORLD + i
		var node := _make_node(index)
		map.add_child(node)
		node.position = SPOTS[_world][i] - Vector2(NODE_SIZE, NODE_SIZE) / 2.0
		_nodes.append(node)
	map.queue_redraw()


func _make_node(index: int) -> Control:
	var unlocked := LevelManager.is_unlocked(index)
	var stars: int = LevelManager.level_stars.get(index, 0)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	b.size = Vector2(NODE_SIZE, NODE_SIZE)
	b.pivot_offset = b.size / 2.0
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(s, empty)
	var tex := TextureRect.new()
	tex.texture = NODE_LOCKED if not unlocked else (NODE_DONE if stars > 0 else NODE_OPEN)
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tex)
	if unlocked:
		var num := Label.new()
		num.text = str(index % LevelManager.LEVELS_PER_WORLD + 1)
		num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.add_theme_font_size_override("font_size", 32)
		num.add_theme_color_override("font_color", Color("1b0f1e") if stars > 0 else Color("f3dbc6"))
		num.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(num)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for s in 3:
			var st := TextureRect.new()
			st.texture = STAR if s < stars else STAR_EMPTY
			st.custom_minimum_size = Vector2(24, 21)
			st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			st.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(st)
		b.add_child(row)
		row.position = Vector2(0, NODE_SIZE + 6)
	else:
		var lock := TextureRect.new()
		lock.texture = LOCK
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock.offset_left = -18
		lock.offset_right = 18
		lock.offset_top = -21
		lock.offset_bottom = 18
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lock)
	b.pressed.connect(_on_node_pressed.bind(index))
	return b


func _draw_path() -> void:
	var spots: Array = SPOTS[_world]
	for i in spots.size() - 1:
		var a: Vector2 = spots[i]
		var b: Vector2 = spots[i + 1]
		var open := LevelManager.is_unlocked(_world * LevelManager.LEVELS_PER_WORLD + i + 1)
		var col := Color("f3dbc6", 0.75) if open else Color("683a68", 0.8)
		var dist := a.distance_to(b)
		var steps := int(dist / 27.0)
		for s in range(2, steps - 1):
			var p := a.lerp(b, float(s) / steps)
			# little arc so the path isn't dead straight
			p.y -= sin(float(s) / steps * PI) * 24.0
			p = (p / 3.0).round() * 3.0
			map.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), Color("1b0f1e"))
			map.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), col)


func _place_walker(instant: bool, from := Vector2.ZERO) -> void:
	var local := _sel - _world * LevelManager.LEVELS_PER_WORLD
	var target: Vector2 = SPOTS[_world][local] + Vector2(0, -NODE_SIZE / 2.0 - 36)
	var suffix := "1" if _world == 0 else "2"
	if instant:
		walker.position = target
		walker.play("idle" + suffix)
		return
	_busy = true
	walker.flip_h = target.x < from.x
	walker.play("jump" + suffix)
	Fx.play_var("pop", 0.1)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		walker.position = from.lerp(target, t) + Vector2(0, -sin(t * PI) * 60.0), 0.0, 1.0, 0.28)
	await tween.finished
	walker.play("idle" + suffix)
	walker.scale = Vector2(3.9, 2.1)
	create_tween().tween_property(walker, "scale", Vector2(3, 3), 0.15)
	_busy = false


func _update_info() -> void:
	var i := _sel
	var data := LevelManager.level_data(i)
	info_tag.text = LevelManager.level_tag(i)
	var unlocked := LevelManager.is_unlocked(i)
	info_name.text = data.name if unlocked else "locked"
	if LevelManager.best_times.has(i):
		info_best.text = "best %.2fs" % LevelManager.best_times[i]
	else:
		info_best.text = "cleared" if LevelManager.level_stars.has(i) else "no clear yet"
	info_par.text = "3 stars under %.1fs" % data.stars[0]
	var got: int = LevelManager.level_stars.get(i, 0)
	for s in 3:
		info_stars.get_child(s).texture = STAR if s < got else STAR_EMPTY
	play_hint.text = "space to play" if unlocked else "beat %s first" % LevelManager.level_tag(i - 1)
	for n in _nodes.size():
		var node := _nodes[n]
		var selected := n == _sel - _world * LevelManager.LEVELS_PER_WORLD
		node.scale = Vector2.ONE * (1.15 if selected else 1.0)


func _move(dir: int) -> void:
	if _busy:
		return
	var next := clampi(_sel + dir, 0, LevelManager.levels.size() - 1)
	if next == _sel:
		return
	var from := walker.position
	_sel = next
	if LevelManager.world_of(_sel) != _world:
		await _change_page(LevelManager.world_of(_sel), dir)
		return
	_update_info()
	_place_walker(false, from)


func _switch_world(dir: int) -> void:
	if _busy:
		return
	var w := clampi(_world + dir, 0, LevelManager.WORLDS.size() - 1)
	if w == _world:
		return
	_sel = w * LevelManager.LEVELS_PER_WORLD
	# jump to the furthest unlocked level in that world
	for i in LevelManager.LEVELS_PER_WORLD:
		if LevelManager.is_unlocked(w * LevelManager.LEVELS_PER_WORLD + i):
			_sel = w * LevelManager.LEVELS_PER_WORLD + i
	await _change_page(w, dir)


func _change_page(w: int, dir: int) -> void:
	_busy = true
	Fx.play("whoosh", 1.2, -6.0)
	bg_old.texture = bg.texture
	bg_old.modulate.a = 1.0
	var out := create_tween().set_parallel()
	out.tween_property(map, "position:x", -dir * 200.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(map, "modulate:a", 0.0, 0.18)
	out.tween_property(walker, "modulate:a", 0.0, 0.12)
	await out.finished
	_world = w
	_build_world()
	_update_info()
	_place_walker(true)
	map.position.x = dir * 200.0
	var back := create_tween().set_parallel()
	back.tween_property(map, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	back.tween_property(map, "modulate:a", 1.0, 0.25)
	back.tween_property(walker, "modulate:a", 1.0, 0.25)
	back.tween_property(bg_old, "modulate:a", 0.0, 0.4)
	await back.finished
	_busy = false


func _on_node_pressed(index: int) -> void:
	if index == _sel:
		_play()
		return
	var from := walker.position
	_sel = index
	_update_info()
	_place_walker(false, from)


func _play() -> void:
	if _busy or LevelManager.is_changing:
		return
	if not LevelManager.is_unlocked(_sel):
		Fx.play("ui_back")
		var node := _nodes[_sel - _world * LevelManager.LEVELS_PER_WORLD]
		var tween := create_tween()
		for x in [12.0, -12.0, 8.0, -8.0, 0.0]:
			tween.tween_property(node, "rotation", deg_to_rad(x), 0.04)
		return
	Fx.play("ui_select")
	walker.play("jump" + ("1" if _world == 0 else "2"))
	create_tween().tween_property(walker, "position:y", walker.position.y - 40, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	LevelManager.load_level(_sel, _sel % LevelManager.LEVELS_PER_WORLD == 0)


func _back() -> void:
	Fx.play("ui_back")
	LevelManager.change_scene(LevelManager.MENU)


func _unhandled_input(event: InputEvent) -> void:
	if LevelManager.is_changing:
		return
	if event.is_action_pressed("ui_right"):
		_move(1)
	elif event.is_action_pressed("ui_left"):
		_move(-1)
	elif event.is_action_pressed("ui_accept"):
		_play()
	elif event.is_action_pressed("ui_cancel"):
		_back()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_switch_world(-1)
		elif event.keycode == KEY_E:
			_switch_world(1)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_switch_world(-1)
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_switch_world(1)
