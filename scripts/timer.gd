extends CanvasLayer

const STAR := preload("res://assets/ui/icon_star_small.png")
const STAR_EMPTY := preload("res://assets/ui/icon_star_small_empty.png")
const COL_TEXT := Color("f3dbc6")
const COL_LOW := Color("ff8e80")
const COL_BAR := Color("edb4a1")
const COL_BAR_LOW := Color("c53a9d")

@onready var tag: Label = $Panel/VBox/Top/Tag
@onready var level_name: Label = $Panel/VBox/Top/Name
@onready var label: Label = $Panel/VBox/Row/Time
@onready var bar: Control = $Panel/VBox/Bar
@onready var rank: HBoxContainer = $Panel/VBox/Row/Rank
@onready var boost_panel: PanelContainer = $Boost
@onready var boost_icon: TextureRect = $Boost/HBox/Icon
@onready var boost_name: Label = $Boost/HBox/VBox/Name
@onready var boost_key: Label = $Boost/HBox/VBox/Status/Key
@onready var boost_status: Label = $Boost/HBox/VBox/Status/Text

var timeLimit := 60.0
var timeLeft := 60.0
var running := false
var time_elapse := 0.0

var _shown_stars := 3
var _last_tick := -1
var _bar_value := 1.0
var _player: Node = null


func _ready() -> void:
	bar.draw.connect(_draw_bar)
	boost_panel.visible = false


func start(seconds: float) -> void:
	tag.text = LevelManager.level_tag()
	level_name.text = LevelManager.level_data().name
	timeLimit = seconds
	timeLeft = seconds
	time_elapse = 0.0
	running = true
	_shown_stars = 3
	_update_label()


func reduce_time(amount: float) -> void:
	timeLeft = maxf(0.0, timeLeft - amount)
	_update_label()
	_float_text("-%ds" % int(amount))
	if timeLeft <= 0.0:
		running = false
		_on_time_up()


func _process(delta: float) -> void:
	_bar_value = lerpf(_bar_value, timeLeft / maxf(timeLimit, 0.01), minf(1.0, delta * 12.0))
	bar.queue_redraw()
	_update_boost()
	_fade_if_covering(delta)
	if not running:
		return
	time_elapse += delta
	timeLeft -= delta
	if timeLeft <= 0.0:
		timeLeft = 0.0
		running = false
		_on_time_up()
	_update_label()
	_update_rank()


func _update_label() -> void:
	var seconds := int(ceil(timeLeft))
	label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	var low := timeLeft <= 5.0 and running
	label.add_theme_color_override("font_color", COL_LOW if low else COL_TEXT)
	if low and seconds != _last_tick:
		_last_tick = seconds
		Fx.play("tick", 1.0 + (5 - seconds) * 0.06)
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _update_rank() -> void:
	var stars := LevelManager.stars_calc(time_elapse)
	while _shown_stars > stars:
		var icon: TextureRect = rank.get_child(_shown_stars - 1)
		_shown_stars -= 1
		icon.texture = STAR_EMPTY
		icon.pivot_offset = icon.size / 2.0
		icon.scale = Vector2(1.6, 1.6)
		create_tween().tween_property(icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		Fx.play("pop", 0.7)


func _update_boost() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var id: StringName = LevelManager.current_upgrade
	if id == &"":
		boost_panel.visible = false
		return
	var info := Upgrades.get_info(id)
	if not boost_panel.visible:
		boost_panel.visible = true
		boost_icon.texture = info.icon
		boost_name.text = info.name
		boost_name.add_theme_color_override("font_color", Upgrades.RARITY_COLORS[info.rarity])
		boost_key.visible = info.has("key")
		boost_key.text = info.get("key", "")
		boost_panel.pivot_offset = Vector2(boost_panel.size.x, 0)
		boost_panel.scale = Vector2(1.2, 1.2)
		create_tween().tween_property(boost_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	boost_status.text = _player.boost_status()


# don't hide the player behind the hud
func _fade_if_covering(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p: Vector2 = _player.get_global_transform_with_canvas().origin
	var body := Rect2(p - Vector2(40, 60), Vector2(80, 110))
	for panel in [$Panel, boost_panel]:
		var covering: bool = panel.visible and panel.get_global_rect().grow(12).intersects(body)
		panel.modulate.a = move_toward(panel.modulate.a, 0.3 if covering else 1.0, delta * 5.0)


func _float_text(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", COL_LOW)
	l.add_theme_font_size_override("font_size", 32)
	add_child(l)
	l.global_position = label.global_position + Vector2(label.size.x + 24, 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(l, "position:y", l.position.y + 48, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(l.queue_free)


func _draw_bar() -> void:
	var s := bar.size
	var ink := Color("1b0f1e")
	bar.draw_rect(Rect2(Vector2.ZERO, s), ink)
	bar.draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), Color("2c2137"))
	var w := floorf((s.x - 6) * clampf(_bar_value, 0.0, 1.0) / 3.0) * 3.0
	var low := timeLeft <= 5.0
	var col := COL_BAR_LOW if low and int(time_elapse * 6.0) % 2 == 0 else COL_BAR
	if w > 0:
		bar.draw_rect(Rect2(Vector2(3, 3), Vector2(w, s.y - 6)), col)
		bar.draw_rect(Rect2(Vector2(3, 3), Vector2(w, 3)), Color(1, 1, 1, 0.35))


func _on_time_up() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("die"):
		player.die(true)
	else:
		LevelManager.restart_level()
