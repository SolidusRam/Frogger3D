class_name Airplane
extends AnimatableBody3D
## Un aereo di linea in rullaggio: enorme e lento, non diventa mai rottame.
## Sotto le ali si passa; fusoliera, motori e carrelli travolgono rana e
## veicoli; sulle ali e sulla fusoliera si sta sicuri. Dietro ogni motore c'è
## un getto che spinge via la rana e i rottami: col deltaplano aperto la
## solleva e la lancia lontano. Corre lungo l'asse X locale del raccordo.

const MODEL := preload("res://assets/models/airplane.glb")
const LENGTH := 24.0
## Getto dietro i motori: lunghezza, velocità del vento che spinge la rana,
## spinta verso l'alto per il deltaplano e accelerazione data ai rottami.
const BLAST_LENGTH := 22.0
const BLAST_WIND := 16.0
const BLAST_LIFT := 30.0
const BLAST_STRENGTH := 55.0
const ENGINE_X := 6.0

var direction := 1.0
var speed := 7.0
var damage := 35
var smash_speed := 14.0

var _hazards: Array[Area3D] = []
var _blasts: Array[Area3D] = []
var _last_hit := {}


## Crea un aereo già orientato. Rotazione e sync_to_physics vanno impostati
## prima che il corpo entri nella scena: attivare sync_to_physics dopo
## riporterebbe il nodo all'orientamento con cui il corpo era stato registrato.
static func create(travel_direction: float, travel_speed: float) -> Airplane:
	var plane := Airplane.new()
	plane.direction = travel_direction
	plane.speed = travel_speed
	plane.sync_to_physics = true
	# Il muso del modello guarda verso -Z: lo si gira nel verso di marcia.
	plane.rotation.y = -PI / 2.0 * travel_direction
	return plane


func _ready() -> void:
	collision_layer = 8 # piattaforme: ci si sale sopra
	collision_mask = 0
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	Style.apply_palette(model)
	# Collisione: fusoliera, ali, motori, deriva (il muso guarda verso -Z).
	_solid(Vector3(3.6, 3.6, LENGTH), Vector3(0.0, 2.7, 0.0))
	_solid(Vector3(26.0, 0.4, 5.0), Vector3(0.0, 2.6, 0.5))
	for side in [-1.0, 1.0]:
		_solid(Vector3(1.7, 1.7, 3.4), Vector3(side * ENGINE_X, 1.75, -1.2))
	_solid(Vector3(0.4, 5.0, 3.0), Vector3(0.0, 7.0, 10.5))
	# Zone che travolgono: più basse delle superfici su cui si sta in piedi.
	_hazard(Vector3(4.0, 3.2, LENGTH + 0.5), Vector3(0.0, 2.3, 0.0))
	for side in [-1.0, 1.0]:
		_hazard(Vector3(2.0, 1.9, 3.8), Vector3(side * ENGINE_X, 1.75, -1.2))
		_hazard(Vector3(0.8, 2.5, 1.6), Vector3(side * 2.4, 1.25, 0.5))
		_blast(Vector3(side * ENGINE_X, 1.8, 0.5 + BLAST_LENGTH / 2.0))


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	_smash()
	_push()


## Coda dell'aereo lungo il raccordo (l'origine è al centro).
func tail_x() -> float:
	return position.x - direction * LENGTH / 2.0


func _smash() -> void:
	var forward := -global_basis.z
	var side := forward.cross(Vector3.UP)
	var frame := Engine.get_physics_frames()
	for area in _hazards:
		for body in area.get_overlapping_bodies():
			var id := body.get_instance_id()
			if frame - _last_hit.get(id, -1000) < 30:
				continue
			_last_hit[id] = frame
			var side_sign := 1.0 if (body.global_position - global_position).dot(side) >= 0.0 else -1.0
			var push := (forward * 0.6 + side * side_sign + Vector3.UP * 0.5).normalized()
			if body is Car:
				body.become_wreck()
				body.apply_central_impulse(push * body.mass * smash_speed)
			elif body is Frog:
				body.take_hit(damage, push * 13.0)


## Il getto: spinge all'indietro rispetto all'aereo, più forte vicino ai
## motori, con un po' di spinta verso l'alto.
func _push() -> void:
	var backward := global_basis.z
	for area in _blasts:
		for body in area.get_overlapping_bodies():
			var distance: float = (body.global_position - area.global_position).dot(backward) + BLAST_LENGTH / 2.0
			var strength := 1.0 - 0.6 * clampf(distance / BLAST_LENGTH, 0.0, 1.0)
			if body is Frog:
				body.apply_wind(backward * BLAST_WIND * strength, BLAST_LIFT * strength)
			elif body is RigidBody3D and not body.freeze:
				var acceleration := (backward * BLAST_STRENGTH + Vector3.UP * 9.0) * strength
				body.apply_central_force(acceleration * body.mass * 0.5)


func _solid(size: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	add_child(collision)


func _hazard(size: Vector3, at: Vector3) -> void:
	_hazards.append(_area(size, at))


func _blast(at: Vector3) -> void:
	_blasts.append(_area(Vector3(3.2, 3.6, BLAST_LENGTH), at))


func _area(size: Vector3, at: Vector3) -> Area3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 | 4 # rana, veicoli e container
	area.position = at
	area.add_child(collision)
	add_child(area)
	return area
