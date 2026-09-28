extends CanvasLayer

# the boost draft. shows up every attempt with 3 random boosts from Upgrades.LIST

const CARD_SIZE := Vector2(330, 450)
const GAP := 42.0
const HOURGLASS := preload("res://assets/ui/icon_hourglass.png")

@onready var dim: ColorRect = $Dim
@onready var header: VBoxContainer = $Header
@onready var sub: Label = $Header/Sub
@onready var cards_root: Control = $Cards
@onready var skip_button: Button = $Bottom/Skip
@onready var bottom: HBoxContainer = $Bottom

var _offer: Array[StringName] = []
var _cards: Array[Button] = []
var _home: Array[Vector2] = []
var _live := false
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	LevelManager.ui_lock += 1
	LevelManager.current_upgrade = &""
	_offer = Upgrades.roll(3)
	var time: float = LevelManager.level_data().time
	sub.text = "you get %ds. boosts eat some of it." % int(time)
	_build_cards()
	skip_button.pressed.connect(_skip)
	skip_button.mouse_entered.connect(skip_button.grab_focus)
	skip_button.focus_entered.connect(func(): if _live: Fx.play("ui_move"))
	dim.modulate.a = 0.0
	header.modulate.a = 0.0
	bottom.modulate.a = 0.0
	for c in _cards:
		c.modulate.a = 0.0
	_intro()


func _build_cards() -> void:
	var total := _offer.size() * CARD_SIZE.x + (_offer.size() - 1) * GAP
	var x := -total / 2.0
	for i in _offer.size():
		var card := _make_card(_offer[i], i)
		cards_root.add_child(card)
		card.position = Vector2(x, -CARD_SIZE.y / 2.0)
		_home.append(card.position)
		_cards.append(card)
		x += CARD_SIZE.x + GAP
	for i in _cards.size():
		var c := _cards[i]
		c.focus_neighbor_left = c.get_path_to(_cards[(i - 1 + _cards.size()) % _cards.size()])
		c.focus_neighbor_right = c.get_path_to(_cards[(i + 1) % _cards.size()])
		c.focus_neighbor_bottom = c.get_path_to(skip_button)
	skip_button.focus_neighbor_top = skip_button.get_path_to(_cards[_cards.size() / 2])


func _make_card(id: StringName, index: int) -> Button:
	var info := Upgrades.get_info(id)
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE / 2.0
	var box: StyleBox = ThemeDB.get_project_theme().get_stylebox("panel", Upgrades.RARITY_CARDS[info.rarity])
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		card.add_theme_stylebox_override(state, box)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 27
	v.offset_right = -27
	v.offset_top = 27
	v.offset_bottom = -30
	v.add_theme_constant_override("separation", 9)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	var rarity := _label(Upgrades.RARITY_NAMES[info.rarity], 16, Upgrades.RARITY_COLORS[info.rarity])
	v.add_child(rarity)

	# icon sits in a plain holder so it can bob without the VBox fighting it
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 124)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(holder)
	var icon := TextureRect.new()
	icon.texture = info.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -56
	icon.offset_right = 56
	icon.offset_top = -56
	icon.offset_bottom = 56
	var bob := icon.create_tween().set_loops()
	bob.tween_property(icon, "position:y", -6.0, 0.6 + index * 0.07).as_relative().set_trans(Tween.TRANS_SINE)
	bob.tween_property(icon, "position:y", 6.0, 0.6 + index * 0.07).as_relative().set_trans(Tween.TRANS_SINE)

	v.add_child(_label(info.name, 32))
	var desc := _label(info.desc, 24, Color("f3dbc6"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var flavor := _label('"%s"' % info.flavor, 16, Color("9775a6"))
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(flavor)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)

	var cost := HBoxContainer.new()
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	cost.add_theme_constant_override("separation", 12)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass := TextureRect.new()
	glass.texture = HOURGLASS
	glass.custom_minimum_size = Vector2(33, 42)
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.add_child(glass)
	cost.add_child(_label("-%ds" % int(info.cost), 32, Color("ff8e80")))
	v.add_child(cost)

	var key := Label.new()
	key.theme_type_variation = &"KeyLabel"
	key.text = str(index + 1)
	key.position = Vector2(21, 18)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(key)

	card.pressed.connect(_pick.bind(index))
	card.mouse_entered.connect(card.grab_focus)
	card.focus_entered.connect(_on_card_focus.bind(index, true))
	card.focus_exited.connect(_on_card_focus.bind(index, false))
	return card


func _label(text: String, font_size: int, color := Color("f3dbc6")) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _intro() -> void:
	# wait out the level transition / world card first
	while LevelManager.is_changing:
		await get_tree().process_frame
	var tween := create_tween().set_parallel()
	tween.tween_property(dim, "modulate:a", 1.0, 0.18)
	header.position.y -= 30
	tween.tween_property(header, "modulate:a", 1.0, 0.25)
	tween.tween_property(header, "position:y", header.position.y + 30, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in _cards.size():
		var c := _cards[i]
		c.position.y = _home[i].y + 160
		tween.tween_property(c, "position:y", _home[i].y, 0.45).set_delay(0.08 + i * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(0.08 + i * 0.07)
		tween.tween_callback(Fx.play.bind("card", 1.0 + i * 0.08)).set_delay(0.08 + i * 0.07)
	tween.tween_property(bottom, "modulate:a", 1.0, 0.3).set_delay(0.35)
	await tween.finished
	_live = true
	# retrying? put the cursor on whatever you picked last time
	var start := _offer.find(LevelManager.last_upgrade)
	_cards[start if start >= 0 else 0].grab_focus()


func _on_card_focus(index: int, focused: bool) -> void:
	if not _live or _done:
		return
	var c := _cards[index]
	var tween := c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(c, "position:y", _home[index].y - (18.0 if focused else 0.0), 0.2)
	tween.tween_property(c, "scale", Vector2.ONE * (1.04 if focused else 1.0), 0.2)
	if focused:
		Fx.play("ui_move")


func _unhandled_input(event: InputEvent) -> void:
	if not _live or _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_pick(0)
			KEY_2, KEY_KP_2:
				_pick(1)
			KEY_3, KEY_KP_3:
				_pick(2)
			KEY_4, KEY_KP_4, KEY_0:
				_skip()


func _pick(index: int) -> void:
	if not _live or _done or index >= _offer.size():
		return
	_done = true
	var id := _offer[index]
	var info := Upgrades.get_info(id)
	LevelManager.current_upgrade = id
	LevelManager.last_upgrade = id
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.apply_upgrade(id)
	Fx.play("boost_pick")

	var tween := create_tween().set_parallel()
	for i in _cards.size():
		var c := _cards[i]
		if i == index:
			tween.tween_property(c, "scale", Vector2.ONE * 1.14, 0.12).set_trans(Tween.TRANS_BACK)
			tween.tween_property(c, "position:y", _home[i].y - 40, 0.3)
			tween.tween_property(c, "modulate:a", 0.0, 0.2).set_delay(0.3)
		else:
			tween.tween_property(c, "position:y", _home[i].y + 220, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(c, "modulate:a", 0.0, 0.25)
	tween.tween_property(header, "modulate:a", 0.0, 0.25)
	tween.tween_property(bottom, "modulate:a", 0.0, 0.2)
	tween.tween_property(dim, "modulate:a", 0.0, 0.25).set_delay(0.3)
	await tween.finished
	_close()
	var timer := get_tree().get_first_node_in_group("level_timer")
	if timer:
		timer.reduce_time(info.cost)


func _skip() -> void:
	if not _live or _done:
		return
	_done = true
	Fx.play("skip")
	var tween := create_tween().set_parallel()
	for i in _cards.size():
		tween.tween_property(_cards[i], "position:y", _home[i].y + 220, 0.25).set_delay(i * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(_cards[i], "modulate:a", 0.0, 0.2).set_delay(i * 0.04)
	tween.tween_property(header, "modulate:a", 0.0, 0.2)
	tween.tween_property(bottom, "modulate:a", 0.0, 0.2)
	tween.tween_property(dim, "modulate:a", 0.0, 0.25).set_delay(0.15)
	await tween.finished
	_close()


func _close() -> void:
	LevelManager.ui_lock = maxi(LevelManager.ui_lock - 1, 0)
	get_tree().paused = false
	queue_free()
