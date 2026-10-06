class_name Fireball
extends Node3D
## La palla di fuoco della lingua mangiafuoco: vola dritta, e la prima auto in
## marcia che tocca diventa rottame. Col drago esplode e fa rottami intorno.
## Contro il terreno o un ostacolo si spegne. Per la prova del drago resta in
## ascolto qualche secondo dopo l'impatto e conta la catena di rottami che ha
## fatto partire.

const SPEED := 30.0
const LIFETIME := 1.2
const RADIUS := 0.8
const DRAGON_RADIUS := 4.0
## La catena che conta per la prova del drago: rottami entro questo tempo e
## questa distanza dall'impatto.
const CHAIN_SECONDS := 1.5
const CHAIN_RADIUS := 15.0

var direction := Vector3.FORWARD
var dragon := false
var size := 1.0

var _left := LIFETIME
var _hit_at := Vector3.ZERO
var _listening := 0.0
var _chain := 0
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35 * size
	sphere.height = 0.7 * size
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = Style.material("fire_core")
	_mesh.mesh = sphere
	add_child(_mesh)
	Sfx.play_at(&"fire_ignite", global_position, 0.0, 1.3)


func _physics_process(delta: float) -> void:
	if _listening > 0.0:
		_listening -= delta
		if _listening <= 0.0:
			queue_free()
		return
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var step := direction * SPEED * delta
	var space := get_world_3d().direct_space_state
	# Il terreno o un muro lungo il tragitto: si spegne lì.
	var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1)
	if not space.intersect_ray(ray).is_empty():
		_fizzle()
		return
	global_position += step
	_mesh.rotation.y += 12.0 * delta
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = RADIUS * size
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 4 # veicoli
	for result in space.intersect_shape(query, 8):
		var car := result.collider as Car
		if car and car.state == Car.State.DRIVING:
			_impact(car)
			return


func _impact(car: Car) -> void:
	_hit_at = global_position
	Heat.wreck_created.connect(_on_wreck)
	car.become_wreck()
	car.apply_central_impulse((direction + Vector3.UP * 0.4) * car.mass * 6.0)
	if dragon:
		_explode()
	Sfx.play_at(&"car_explode", global_position, -4.0, 1.2)
	_mesh.visible = false
	_listening = CHAIN_SECONDS


## Il drago: le auto intorno diventano rottami e saltano.
func _explode() -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = DRAGON_RADIUS
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 4
	for result in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var car := result.collider as Car
		if car and car.state == Car.State.DRIVING:
			car.become_wreck()
			var away := car.global_position - global_position
			car.apply_central_impulse((Vector3(away.x, 0.0, away.z).normalized() + Vector3.UP).normalized() * car.mass * 8.0)


## I rottami della catena partita dall'impatto (la prova del drago).
func _on_wreck(car: Node3D) -> void:
	if car.global_position.distance_to(_hit_at) <= CHAIN_RADIUS:
		_chain += 1
		Progress.trial_best("fire_tongue", 1, _chain)


func _fizzle() -> void:
	Sfx.play_at(&"sizzle", global_position, -6.0)
	queue_free()
