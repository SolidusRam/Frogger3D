class_name SuperJumpPower
extends Node
## Il super salto: un balzo alto con slancio in avanti, nella direzione dei
## tasti o, da fermi, in quella della telecamera. Funziona anche dall'acqua.
## L'attrezzo sono le molle sotto le zampe. I potenziamenti cambiano questi
## valori.

@export var height := 5.0
## Velocità orizzontale data dal salto.
@export var boost := 9.0
@export var cooldown := 2.5
## Controllo in aria: si sterza senza perdere slancio.
@export var air_acceleration := 6.0

var cooldown_left := 0.0
## La rana ha le molle (vedi Upgrades). Senza, niente super salto e niente
## molle sotto i talloni.
var enabled := true:
	set(value):
		enabled = value
		for spring in _springs:
			spring.visible = value
## Vero dal salto fino all'atterraggio.
var active := false
## Molle a razzo (carta): in aria, il super salto si ripete air_jumps volte
## prima di toccare terra, senza aspettare la ricarica. Miglioramenti: un
## terzo salto (air_jumps 2) e la scia di fuoco, che fa rottami sotto.
var rocket := false
var air_jumps := 1
var fire_trail := false
@export var fire_trail_radius := 3.5
var _air_left := 0
var _takeoff_y := 0.0

var _frog: Frog
var _springs: Array[Node3D] = []


func setup(frog: Frog) -> void:
	_frog = frog
	# Le molle sono nel modello della rana, sotto i talloni.
	for side in ["L", "R"]:
		_springs.append(frog.model.get_node("Torso/Leg%s/Spring%s" % [side, side]))


## Il colore delle molle dice cosa portano: "" per quelle normali.
func set_spring_color(palette_key: String) -> void:
	_frog.set_palette("metal", palette_key)


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if _frog.is_on_floor() or _frog.is_swimming():
		_air_left = air_jumps
	if _frog.is_on_floor() and _frog.velocity.y <= 0.0:
		active = false
	elif active and rocket:
		# Maestria delle molle a razzo: quanto in alto si arriva.
		Progress.trial_best("rocket_springs", 1, _frog.global_position.y - _takeoff_y)


func is_ready() -> bool:
	return enabled and cooldown_left == 0.0


## Da 0 (appena usato) a 1 (pronto).
func ready_ratio() -> float:
	return 1.0 - cooldown_left / cooldown


## Le molle a razzo: un altro super salto in aria, senza ricarica.
func can_air_jump() -> bool:
	return enabled and rocket and _air_left > 0 and active and not _frog.is_on_floor() and not _frog.is_swimming()


func air_jump(direction: Vector3) -> void:
	_air_left -= 1
	var keep := cooldown_left
	use(direction, false)
	cooldown_left = keep
	Progress.trial_add("rocket_springs", 0, 1)
	_burst()
	if fire_trail:
		_scorch()


func use(direction: Vector3, from_ground := true) -> void:
	cooldown_left = cooldown
	if from_ground:
		_takeoff_y = _frog.global_position.y
	if direction.length_squared() < 0.01:
		direction = -_frog.camera_rig.flat_basis().z
	var push := direction.normalized() * boost
	_frog.launch(Vector3(push.x, sqrt(2.0 * _frog.gravity_up * height), push.z))
	active = true
	# Si accuccia sulle molle e poi si allunga verso l'alto.
	var tween := _frog.new_squash_tween()
	_frog.visual.scale = Vector3(1.4, 0.55, 1.4)
	tween.tween_property(_frog.visual, "scale", Vector3(0.75, 1.4, 0.75), 0.08)
	tween.tween_property(_frog.visual, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for spring in _springs:
		var spring_tween := create_tween()
		spring.scale = Vector3(1.0, 0.3, 1.0)
		spring_tween.tween_property(spring, "scale", Vector3(1.0, 2.2, 1.0), 0.08)
		spring_tween.tween_property(spring, "scale", Vector3.ONE, 0.4)
	_frog.power_used.emit(&"super_jump")
	Sfx.play(&"super_jump")


## Lo scoppio del razzo sotto le zampe: una fiammata che cade e svanisce.
func _burst() -> void:
	var flames := CPUParticles3D.new()
	flames.one_shot = true
	flames.emitting = true
	flames.amount = 24
	flames.lifetime = 0.5
	flames.explosiveness = 0.9
	flames.direction = Vector3.DOWN
	flames.spread = 35.0
	flames.initial_velocity_min = 4.0
	flames.initial_velocity_max = 8.0
	flames.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = Style.material("fire")
	flames.mesh = mesh
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.4
	_frog.get_parent().add_child(flames)
	flames.global_position = _frog.global_position
	flames.finished.connect(flames.queue_free)
	Sfx.play(&"car_explode", -10.0, 1.6)


## La scia di fuoco: le auto sotto la rana diventano rottami.
func _scorch() -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = fire_trail_radius
	shape.height = 30.0
	query.shape = shape
	query.transform = Transform3D(Basis(), _frog.global_position + Vector3.DOWN * 14.0)
	query.collision_mask = 4 # veicoli
	for result in _frog.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var car := result.collider as Car
		if car and car.state == Car.State.DRIVING:
			car.become_wreck()
