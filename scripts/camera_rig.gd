class_name CameraRig
extends Node3D
## Telecamera in terza persona: segue il nodo padre, ruota col mouse o con la
## levetta destra del controller.
## Il nodo è top_level e si muove in _process sulla posizione interpolata del
## padre, così non scatta tra un passo di fisica e l'altro.

@export var mouse_sensitivity := 0.0025
@export var min_pitch_degrees := -70.0
@export var max_pitch_degrees := 15.0
## Altezza del punto guardato sopra i piedi della rana.
@export var target_height := 1.2
@export var follow_speed := 15.0
## Con la levetta tutta piegata: radianti al secondo, in orizzontale e in
## verticale.
@export var stick_yaw_speed := 3.2
@export var stick_pitch_speed := 2.0

@export_group("Menu")
## Nel menu la telecamera gira piano attorno alla rana, un po' più larga e
## più bassa, con la rana spostata a destra (il menu sta a sinistra).
@export var orbit_speed := 0.12
@export var orbit_pitch_degrees := -10.0
@export var orbit_length := 7.5
@export var orbit_offset := -2.6
## Nella scelta delle rane: più vicina, la rana più a destra.
@export var preview_length := 4.2
@export var preview_offset := -2.2

@onready var pitch: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D

var _target: Node3D
var _shake_strength := 0.0
var _shake_left := 0.0
var _shake_duration := 1.0
var _orbiting := false
var _play_pitch := 0.0


func _ready() -> void:
	_target = get_parent()
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	global_position = _target_point()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if _orbiting:
		rotation.y += orbit_speed * delta
	elif is_processing_unhandled_input() and not _target_is_dead():
		_look_with_stick(delta)
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_target_point(), weight)
	# La scossa usa il tempo reale: deve vedersi anche nel fermo-immagine.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_shake_left = maxf(_shake_left - real_delta, 0.0)
	var amount := _shake_strength * _shake_left / _shake_duration
	spring_arm.position = Vector3(randf_range(-amount, amount), randf_range(-amount, amount), 0.0)


func _unhandled_input(event: InputEvent) -> void:
	# Esc (la pausa) lo gestisce l'HUD.
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _target_is_dead():
		# Il clic che recupera il mouse non deve diventare un pugno.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Sensibilità e asse verticale invertito dalle opzioni.
		var sensitivity := mouse_sensitivity * Settings.mouse_sensitivity
		var vertical := -1.0 if Settings.invert_y else 1.0
		rotation.y -= event.relative.x * sensitivity
		pitch.rotation.x = clampf(
			pitch.rotation.x - event.relative.y * sensitivity * vertical,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)


## La levetta destra: la curva al quadrato dà precisione con la levetta
## appena piegata e velocità a fondo corsa. Il tempo è quello vero: il
## rallentatore non rallenta lo sguardo.
func _look_with_stick(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick == Vector2.ZERO:
		return
	stick *= stick.length()
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var sensitivity := Settings.stick_sensitivity * real_delta
	var vertical := -1.0 if Settings.invert_y else 1.0
	rotation.y -= stick.x * stick_yaw_speed * sensitivity
	pitch.rotation.x = clampf(
		pitch.rotation.x - stick.y * stick_pitch_speed * sensitivity * vertical,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)


## Il menu sopra il gioco: la telecamera gira attorno alla rana e non
## risponde al mouse (che resta libero per i pulsanti).
func start_orbit() -> void:
	_orbiting = true
	_play_pitch = pitch.rotation.x
	set_process_unhandled_input(false)
	pitch.rotation.x = deg_to_rad(orbit_pitch_degrees)
	spring_arm.spring_length = orbit_length
	camera.h_offset = orbit_offset
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## La scelta delle rane, nel menu: la telecamera si avvicina e porta la rana
## nella parte destra dello schermo, libera dal pannello. false torna com'era.
func frame_preview(on: bool) -> void:
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(spring_arm, "spring_length", preview_length if on else orbit_length, 0.4)
	tween.tween_property(camera, "h_offset", preview_offset if on else orbit_offset, 0.4)


## Dal menu al gioco: la telecamera torna dietro la rana in duration secondi.
func end_orbit(duration: float) -> void:
	_orbiting = false
	set_process_unhandled_input(true)
	var from := rotation.y
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(func(t: float) -> void: rotation.y = lerp_angle(from, 0.0, t), 0.0, 1.0, duration)
	tween.tween_property(pitch, "rotation:x", _play_pitch, duration)
	tween.tween_property(spring_arm, "spring_length", 6.0, duration)
	tween.tween_property(camera, "h_offset", 0.0, duration)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Scossa: sposta la telecamera a caso per un attimo, in tempo reale. Le
## opzioni la attenuano o la tolgono. Col controller vibra anche quello (la
## vibrazione ha la sua opzione).
func shake(strength: float, duration: float) -> void:
	Settings.rumble(strength * 1.5, strength * 2.5, duration)
	_shake_strength = strength * Settings.shake
	_shake_left = duration
	_shake_duration = duration


## Allarga la telecamera e la riporta indietro, in tempo reale anche durante
## il rallentatore.
func pull_back(extra: float, duration: float) -> void:
	var base := 6.0
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(spring_arm, "spring_length", base + extra, duration * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(spring_arm, "spring_length", base, duration * 0.7).set_ease(Tween.EASE_IN_OUT)


## Orientamento orizzontale della telecamera, per muovere la rana rispetto a
## dove si guarda.
func flat_basis() -> Basis:
	return Basis(Vector3.UP, rotation.y)


func _target_point() -> Vector3:
	return _target.get_global_transform_interpolated().origin + Vector3.UP * target_height


## A run finita il mouse resta libero per la schermata di fine.
func _target_is_dead() -> bool:
	return _target is Frog and _target.is_dead
