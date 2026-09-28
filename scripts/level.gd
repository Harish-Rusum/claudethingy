extends Node2D

# every level uses this now. the clock time + name live in LevelManager.levels

@onready var timer: CanvasLayer = $Timer


func _enter_tree() -> void:
	LevelManager.enter_level(scene_file_path)


func _ready() -> void:
	timer.start(LevelManager.level_data().time)
	_add_ambience(LevelManager.world_of(LevelManager.current_level))


func _add_ambience(world: int) -> void:
	var p := CPUParticles2D.new()
	p.name = "Ambience"
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.local_coords = false
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	var tints := Gradient.new()
	match world:
		0: # fireflies
			p.position = Vector2(960, 560)
			p.emission_rect_extents = Vector2(960, 420)
			p.amount = 22
			p.lifetime = 5.0
			p.gravity = Vector2.ZERO
			p.direction = Vector2(1, -0.3)
			p.spread = 180.0
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 22.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 3.0
			tints.colors = PackedColorArray([Color("f4d2b4"), Color("c596da")])
		1: # dust blowing across the ridge
			p.position = Vector2(-40, 480)
			p.emission_rect_extents = Vector2(10, 480)
			p.amount = 26
			p.lifetime = 11.0
			p.gravity = Vector2(0, 6)
			p.direction = Vector2(1, 0.15)
			p.spread = 12.0
			p.initial_velocity_min = 120.0
			p.initial_velocity_max = 220.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 6.0
			tints.colors = PackedColorArray([Color("edb4a1"), Color("a96868")])
		2: # drips from the cave roof
			p.position = Vector2(960, -10)
			p.emission_rect_extents = Vector2(960, 4)
			p.amount = 14
			p.lifetime = 2.2
			p.gravity = Vector2(0, 700)
			p.direction = Vector2(0, 1)
			p.spread = 0.0
			p.initial_velocity_min = 0.0
			p.initial_velocity_max = 20.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 3.0
			tints.colors = PackedColorArray([Color("99c9b3"), Color("579c9a")])
		_: # space motes drifting up
			p.position = Vector2(960, 1100)
			p.emission_rect_extents = Vector2(960, 20)
			p.amount = 30
			p.lifetime = 9.0
			p.gravity = Vector2(0, -10)
			p.direction = Vector2(0, -1)
			p.spread = 25.0
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 70.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 6.0
			tints.colors = PackedColorArray([Color("ff8e80"), Color("c53a9d"), Color("fffefe")])
			tints.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_initial_ramp = tints
	p.preprocess = p.lifetime
	add_child(p)
	# sit just in front of the background, behind the tiles
	var bg := get_node_or_null("TextureRect")
	if bg:
		move_child(p, bg.get_index() + 1)
