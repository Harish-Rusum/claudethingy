extends Node

const SAVE := "user://savegame.cfg"
const MENU := "res://scenes/main_menu.tscn"
const LEVEL_SELECT := "res://scenes/level_select.tscn"
const INTRO := "res://scenes/intro.tscn"
const ENDING := "res://scenes/ending.tscn"
const RESULTS := preload("res://scenes/results.tscn")
const LEVELS_PER_WORLD := 5

const WORLDS := [
	{"name": "the woods", "blurb": "you landed somewhere soft. lucky.", "bg": preload("res://assets/background/Green.png")},
	{"name": "sunset ridge", "blurb": "the mountains don't care how small you are.", "bg": preload("res://assets/background/Gray.png")},
	{"name": "the hollow", "blurb": "down is the only way up, apparently.", "bg": preload("res://assets/background/Brown.png")},
	{"name": "third space", "blurb": "almost home.", "bg": preload("res://assets/background/Space.png")},
]

# time = seconds on the clock, stars = [3 star time, 2 star time]
var levels: Array[Dictionary] = [
	{"scene": "res://scenes/levels/level_1.tscn", "name": "you've been warned", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_2.tscn", "name": "meet the ladybug", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_3.tscn", "name": "pick a fruit", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_4.tscn", "name": "up and over", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_5.tscn", "name": "canopy", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_6.tscn", "name": "mind the gap", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_7.tscn", "name": "the pits", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_8.tscn", "name": "floor is spikes", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_9.tscn", "name": "turtle traffic", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_10.tscn", "name": "last light", "time": 20.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_11.tscn", "name": "into the hollow", "time": 10.0, "stars": [5.0, 10.0]},
	{"scene": "res://scenes/levels/level_12.tscn", "name": "don't stand still", "time": 20.0, "stars": [8.0, 13.0]},
	{"scene": "res://scenes/levels/level_13.tscn", "name": "going up", "time": 25.0, "stars": [10.0, 16.0]},
	{"scene": "res://scenes/levels/level_14.tscn", "name": "saw that coming", "time": 25.0, "stars": [9.0, 15.0]},
	{"scene": "res://scenes/levels/level_15.tscn", "name": "deep end", "time": 30.0, "stars": [13.0, 20.0]},
	{"scene": "res://scenes/levels/level_16.tscn", "name": "pink lines", "time": 20.0, "stars": [8.0, 13.0]},
	{"scene": "res://scenes/levels/level_17.tscn", "name": "on beat", "time": 25.0, "stars": [10.0, 16.0]},
	{"scene": "res://scenes/levels/level_18.tscn", "name": "rush hour", "time": 25.0, "stars": [11.0, 17.0]},
	{"scene": "res://scenes/levels/level_19.tscn", "name": "crossfire", "time": 30.0, "stars": [12.0, 19.0]},
	{"scene": "res://scenes/levels/level_20.tscn", "name": "home stretch", "time": 40.0, "stars": [17.0, 26.0]},
]

var level_stars := {}
var best_times := {}
var deaths := 0
var seen_intro := false
var settings := {"master": 1.0, "music": 0.8, "sfx": 0.8, "fullscreen": false, "shake": true}

var current_level := 0
var time_taken := 0.0
var level_deaths := 0
var current_upgrade: StringName = &""
var last_upgrade: StringName = &""
var is_changing := false
# anything that pauses the game on its own (boost menu, results, info popups) bumps this
# so the pause menu doesn't fight it
var ui_lock := 0

var music_player := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	music_player.stream = preload("res://assets/sounds/music.ogg")
	music_player.bus = &"Music"
	music_player.volume_db = -3.0
	add_child(music_player)
	apply_settings.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			set_fullscreen(not settings.fullscreen)
			get_viewport().set_input_as_handled()


# ---------- level data ----------

func world_of(index: int) -> int:
	return index / LEVELS_PER_WORLD


func level_tag(index := current_level) -> String:
	return "%d-%d" % [world_of(index) + 1, index % LEVELS_PER_WORLD + 1]


func level_data(index := current_level) -> Dictionary:
	return levels[clampi(index, 0, levels.size() - 1)]


func stars_calc(time: float, index := current_level) -> int:
	var par: Array = level_data(index).stars
	if time <= par[0]:
		return 3
	elif time <= par[1]:
		return 2
	return 1


func total_stars() -> int:
	var n := 0
	for i in level_stars:
		n += level_stars[i]
	return n


func highest_beaten() -> int:
	var best := -1
	for i in level_stars:
		best = maxi(best, int(i))
	return best


func is_unlocked(index: int) -> bool:
	return index <= highest_beaten() + 1


func first_unfinished() -> int:
	for i in levels.size():
		if not level_stars.has(i):
			return i
	return 0


# ---------- saving ----------

func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("data", "stars", level_stars)
	config.set_value("data", "best", best_times)
	config.set_value("data", "deaths", deaths)
	config.set_value("data", "seen_intro", seen_intro)
	for key in settings:
		config.set_value("settings", key, settings[key])
	config.save(SAVE)


func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE) != OK:
		return
	level_stars = config.get_value("data", "stars", {})
	best_times = config.get_value("data", "best", {})
	deaths = config.get_value("data", "deaths", 0)
	seen_intro = config.get_value("data", "seen_intro", false)
	for key in settings:
		settings[key] = config.get_value("settings", key, settings[key])


func reset_progress() -> void:
	level_stars = {}
	best_times = {}
	deaths = 0
	seen_intro = false
	save_game()


func apply_settings() -> void:
	_set_bus(&"Master", settings.master)
	_set_bus(&"Music", settings.music)
	_set_bus(&"SFX", settings.sfx)
	Fx.shake_on = settings.shake
	# browsers only allow fullscreen from a click, so don't try it on boot
	if not OS.has_feature("web") and settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func set_fullscreen(on: bool) -> void:
	settings.fullscreen = on
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	save_game()


func _set_bus(bus_name: StringName, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)


# ---------- flow ----------

func start_game() -> void:
	if not seen_intro:
		seen_intro = true
		save_game()
		stop_music()
		change_scene(INTRO)
		return
	load_level(first_unfinished(), true)


func load_level(index: int, with_card := false) -> void:
	if is_changing:
		return
	current_level = clampi(index, 0, levels.size() - 1)
	level_deaths = 0
	play_music()
	change_scene(level_data().scene, false, world_of(current_level) if with_card else -1)


func restart_level() -> void:
	change_scene(level_data().scene, true)


func register_death() -> void:
	deaths += 1
	level_deaths += 1


func complete_level(time: float) -> void:
	time_taken = time
	var stars := stars_calc(time)
	var old_best: float = best_times.get(current_level, INF)
	var new_best := time < old_best
	var unlocked_world := not is_unlocked(current_level + 1) and current_level + 1 < levels.size() \
			and world_of(current_level + 1) != world_of(current_level)
	if stars > level_stars.get(current_level, 0):
		level_stars[current_level] = stars
	if new_best:
		best_times[current_level] = time
	save_game()
	var results := RESULTS.instantiate()
	get_tree().current_scene.add_child(results)
	results.setup(current_level, time, stars, old_best, new_best, level_deaths, unlocked_world)


func go_to_next_level() -> void:
	if is_changing:
		return
	var next := current_level + 1
	if next >= levels.size():
		stop_music()
		change_scene(ENDING)
		return
	var card := world_of(next) if world_of(next) != world_of(current_level) else -1
	current_level = next
	level_deaths = 0
	play_music()
	change_scene(level_data().scene, false, card)


func go_to_menu() -> void:
	stop_music()
	save_game()
	change_scene(MENU)


func go_to_level_select() -> void:
	stop_music()
	save_game()
	change_scene(LEVEL_SELECT)


# lets you F6 a level straight from the editor and still get the right name/time
func enter_level(path: String) -> void:
	for i in levels.size():
		if levels[i].scene == path:
			if i != current_level:
				current_level = i
				level_deaths = 0
			return


func change_scene(path: String, quick := false, card_world := -1) -> void:
	if is_changing:
		return
	is_changing = true
	await Transition.cover(quick)
	ui_lock = 0
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_muffled(false)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if card_world >= 0:
		Showtime.show_card(card_world)
	await Transition.reveal(quick)
	if card_world >= 0:
		await Showtime.finish_card()
	is_changing = false


# ---------- music ----------

func play_music() -> void:
	if not music_player.playing:
		music_player.play()


func stop_music() -> void:
	music_player.stop()


func set_muffled(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	if AudioServer.get_bus_effect_count(bus) > 0:
		AudioServer.set_bus_effect_enabled(bus, 0, on)
