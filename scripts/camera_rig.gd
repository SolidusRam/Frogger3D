class_name CameraRig
extends Node3D
## Telecamera in terza persona: segue il nodo padre, ruota col mouse.
## Il nodo è top_level e si muove in _process sulla posizione interpolata del
## padre, così non scatta tra un passo di fisica e l'altro.

@export var mouse_sensitivity := 0.0025
@export var min_pitch_degrees := -70.0
@export var max_pitch_degrees := 15.0
## Altezza del punto guardato sopra i piedi della rana.
@export var target_height := 1.2
@export var follow_speed := 15.0

@onready var pitch: Node3D = $Pitch

var _target: Node3D


func _ready() -> void:
	_target = get_parent()
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	global_position = _target_point()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_target_point(), weight)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Il clic che recupera il mouse non deve diventare un pugno.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		pitch.rotation.x = clampf(
			pitch.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)


## Orientamento orizzontale della telecamera, per muovere la rana rispetto a
## dove si guarda.
func flat_basis() -> Basis:
	return Basis(Vector3.UP, rotation.y)


func _target_point() -> Vector3:
	return _target.get_global_transform_interpolated().origin + Vector3.UP * target_height
