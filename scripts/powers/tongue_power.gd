class_name TonguePower
extends Node
## La lingua-rampino (si sblocca nella tana): con E la lingua scatta verso la
## cosa più vicina nella direzione della telecamera, entro reach metri, e la
## aggancia da sola, senza mirare. Ciò che si muove (un'auto, un tronco, una
## nave, un treno, un aereo) tira a sé la rana, che ci atterra sopra: è il
## modo di spostarsi di lato usando il traffico. Un rottame, invece, è la
## lingua a tirarlo verso la rana. Funziona anche dall'acqua.

@export var reach := 12.0
## Quanto può essere lontano dalla direzione della telecamera, in gradi.
@export var max_angle := 40.0
@export var pull_speed := 22.0
@export var max_pull_time := 0.8
@export var cooldown := 1.2
## Velocità data al rottame tirato verso la rana.
@export var wreck_pull := 14.0

## Equipaggiata nella tana.
var enabled := false
var cooldown_left := 0.0
## Vero mentre la lingua tira la rana verso il bersaglio.
var pulling := false

var _frog: Frog
var _target: Node3D
var _anchor_local := Vector3.ZERO
var _last_anchor := Vector3.ZERO
var _pull_time := 0.0
var _tongue: MeshInstance3D
## La lingua resta visibile per un istante anche quando tira un rottame.
var _flick_to := Vector3.ZERO
var _flick_left := 0.0


func setup(frog: Frog) -> void:
	_frog = frog
	_tongue = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.06, 1.0)
	mesh.material = Style.material("tongue")
	_tongue.mesh = mesh
	_tongue.top_level = true
	_tongue.visible = false
	frog.add_child(_tongue)


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_flick_left = maxf(_flick_left - delta, 0.0)
	var mouth := _frog.global_position + Vector3.UP * 0.55
	var to := Vector3.ZERO
	if pulling and is_instance_valid(_target):
		to = _target.to_global(_anchor_local)
	elif _flick_left > 0.0:
		to = _flick_to
	_tongue.visible = to != Vector3.ZERO and mouth.distance_to(to) > 0.3
	if _tongue.visible:
		_tongue.global_position = (mouth + to) / 2.0
		_tongue.look_at(to, Vector3.UP if absf((to - mouth).normalized().y) < 0.99 else Vector3.FORWARD)
		_tongue.scale = Vector3(1.0, 1.0, mouth.distance_to(to))


func is_ready() -> bool:
	return enabled and cooldown_left == 0.0


## Da 0 (appena usata) a 1 (pronta).
func ready_ratio() -> float:
	return 1.0 - cooldown_left / cooldown


## Lancia la lingua. Falso se non c'è niente da agganciare (la lingua scatta
## a vuoto e si ricarica in fretta).
func use() -> bool:
	var target := _find_target()
	if target == null:
		cooldown_left = 0.3
		_flick_to = _frog.global_position + Vector3.UP * 0.55 - _frog.camera_rig.flat_basis().z * 3.0
		_flick_left = 0.12
		return false
	cooldown_left = cooldown
	_frog.power_used.emit(&"tongue")
	var body := target as RigidBody3D
	if body and not body.freeze:
		# Un rottame (o un bagaglio, un container): lo tira verso la rana.
		var toward := (_frog.global_position - body.global_position)
		toward.y = 0.0
		body.linear_velocity = toward.normalized() * wreck_pull + Vector3.UP * 4.0
		_flick_to = body.global_position
		_flick_left = 0.15
		return true
	pulling = true
	_target = target
	_pull_time = 0.0
	_anchor_local = target.to_local(_top_of(target))
	_last_anchor = target.to_global(_anchor_local)
	_frog.squash(Vector3(0.85, 0.85, 1.25), 0.2)
	return true


## Tira la rana verso il punto agganciato, che si muove col bersaglio.
func apply(delta: float) -> void:
	_pull_time += delta
	if not is_instance_valid(_target) or _pull_time > max_pull_time:
		stop()
		return
	var anchor := _target.to_global(_anchor_local)
	var carried := (anchor - _last_anchor) / maxf(delta, 0.0001)
	_last_anchor = anchor
	var to := anchor - _frog.global_position
	if to.length() < 0.8:
		# Arrivata: viaggia col bersaglio e ci si posa sopra.
		_frog.velocity = carried + Vector3.UP * 1.5
		stop()
		return
	_frog.velocity = to.normalized() * pull_speed + carried


func stop() -> void:
	pulling = false
	_target = null


## La cosa da agganciare: entro reach, nel cono della telecamera, visibile, la
## più vicina alla direzione dello sguardo. Mai quella su cui la rana sta.
func _find_target() -> Node3D:
	var space := _frog.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	query.shape = sphere
	query.transform = Transform3D(Basis(), _frog.global_position)
	query.collision_mask = 4 | 8 # veicoli e piattaforme
	query.exclude = [_frog.get_rid()]
	var forward := -_frog.camera_rig.flat_basis().z
	var standing_on := _frog.floor_body()
	var best: Node3D = null
	var best_score := INF
	for result in space.intersect_shape(query, 64):
		var body := result.collider as Node3D
		if body == null or body == standing_on:
			continue
		var offset := body.global_position - _frog.global_position
		var flat := Vector3(offset.x, 0.0, offset.z)
		if flat.length() < 0.5 or flat.length() > reach:
			continue
		var angle := rad_to_deg(forward.angle_to(flat))
		if angle > max_angle:
			continue
		var ray := PhysicsRayQueryParameters3D.create(_frog.global_position + Vector3.UP * 0.5, body.global_position, 1)
		if not space.intersect_ray(ray).is_empty():
			continue
		var score := angle + flat.length() * 2.0
		if score < best_score:
			best_score = score
			best = body
	return best


## Il punto più alto del bersaglio sopra il suo centro: la rana ci atterra.
func _top_of(target: Node3D) -> Vector3:
	var space := _frog.get_world_3d().direct_space_state
	var from := target.global_position + Vector3.UP * 12.0
	var ray := PhysicsRayQueryParameters3D.create(from, target.global_position + Vector3.DOWN * 3.0, 4 | 8)
	ray.collide_with_areas = false
	for i in 4:
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			break
		if hit.collider == target:
			return hit.position + Vector3.UP * 0.6
		ray.exclude = ray.exclude + [hit.rid]
	return target.global_position + Vector3.UP * 1.5
