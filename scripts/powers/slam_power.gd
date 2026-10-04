class_name SlamPower
extends Node
## Lo schianto sismico (si sblocca nella tana, slot molle): in aria, con Ctrl,
## la rana piomba giù; atterrando manda un'onda che ribalta le auto intorno e
## le fa volare via. Un pulsante a sé: non scatta da solo dopo il super salto.
## Le molle diventano pesanti e scure.

@export var dive_speed := 28.0
## Sopra il terreno serve almeno questa altezza.
@export var min_height := 1.2
@export var radius := 6.0
## Velocità data alle auto colpite dall'onda (in alto e verso l'esterno).
@export var launch_speed := 9.0
@export var cooldown := 2.0

var enabled := false
var cooldown_left := 0.0
## Vero mentre la rana piomba giù.
var diving := false

var _frog: Frog


func setup(frog: Frog) -> void:
	_frog = frog


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func is_ready() -> bool:
	return enabled and cooldown_left == 0.0 and not diving


## Da 0 (appena usato) a 1 (pronto).
func ready_ratio() -> float:
	return 1.0 - cooldown_left / cooldown


## Vero se la rana è abbastanza in alto per schiantarsi.
func can_start() -> bool:
	if _frog.is_on_floor() or _frog.is_swimming():
		return false
	var from := _frog.global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * min_height, 1 | 4 | 8)
	query.exclude = [_frog.get_rid()]
	return _frog.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func use() -> void:
	diving = true
	cooldown_left = cooldown
	_frog.squash(Vector3(0.8, 1.3, 0.8), 0.2)


## Giù dritta; all'atterraggio, l'onda.
func apply(_delta: float) -> void:
	if _frog.is_on_floor():
		diving = false
		_shock()
		return
	if _frog.is_swimming():
		diving = false
		return
	_frog.velocity = Vector3(_frog.velocity.x * 0.2, -dive_speed, _frog.velocity.z * 0.2)


func stop() -> void:
	diving = false


func _shock() -> void:
	_frog.power_used.emit(&"slam")
	_frog.squash(Vector3(1.5, 0.6, 1.5), 0.35)
	_frog.camera_rig.shake(0.35, 0.3)
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), _frog.global_position)
	query.collision_mask = 4 # veicoli, bagagli, container
	var hit: Array[Car] = []
	for result in _frog.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body := result.collider as RigidBody3D
		if body == null:
			continue
		var out := body.global_position - _frog.global_position
		out.y = 0.0
		var launch := (out.normalized() + Vector3.UP * 1.6).normalized() * launch_speed
		if body is Car:
			if body.state == Car.State.DRIVING:
				body.become_wreck()
			hit.append(body)
		elif body.freeze:
			continue
		body.linear_velocity = launch
		body.angular_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0), randf_range(-3.0, 3.0))
	_ring()
	if not hit.is_empty():
		_frog.punched.emit(hit)


## Un anello che si allarga a terra: l'onda si vede.
func _ring() -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.rings = 12
	mesh.ring_segments = 4
	mesh.material = Style.material("spark")
	ring.mesh = mesh
	_frog.get_parent().add_child(ring)
	ring.global_position = _frog.global_position + Vector3.UP * 0.1
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ring.queue_free)
