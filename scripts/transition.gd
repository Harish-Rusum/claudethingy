extends CanvasLayer

@onready var wipe: ColorRect = $Wipe

var _mat: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = wipe.material
	_mat.set_shader_parameter("progress", 0.0)
	wipe.visible = false


func cover(quick := false) -> void:
	wipe.visible = true
	_mat.set_shader_parameter("flip", false)
	if not quick:
		Fx.play("whoosh", 1.1, -4.0)
	await _tween_to(1.0, 0.18 if quick else 0.38)


func reveal(quick := false) -> void:
	_mat.set_shader_parameter("flip", true)
	await _tween_to(0.0, 0.2 if quick else 0.38)
	wipe.visible = false


func _tween_to(value: float, time: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(v: float): _mat.set_shader_parameter("progress", v),
			_mat.get_shader_parameter("progress"), value, time)
	await tween.finished
