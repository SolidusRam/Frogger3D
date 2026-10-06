class_name TonguePower
extends Node
## La lingua-rampino (si sblocca nella tana, slot lingua). Quando è pronta,
## un mirino segna la cosa che aggancerebbe: la più vicina nella direzione
## della telecamera, entro reach metri, senza dover mirare. Premendo E la
## lingua la aggancia; tenendo premuto la lingua si accorcia fino a
## tether_length e resta tesa come una fune: ci si fa trascinare da un'auto,
## un tronco, una nave, un treno, un aereo. Lasciando, la rana vola via con lo
## slancio che ha. Un rottame invece lo si tira verso di sé finché si tiene
## premuto; lasciato, prosegue con la sua spinta. Le mosche, la lingua le
## mangia al volo, e il mirino le preferisce. Funziona anche dall'acqua.

@export var reach := 12.0
## Quanto può essere lontano dalla direzione della telecamera, in gradi.
@export var max_angle := 40.0
## La fune: lunghezza a cui si accorcia, velocità con cui si accorcia e
## massima velocità con cui tira.
@export var tether_length := 2.5
@export var reel_speed := 16.0
@export var pull_speed := 22.0
## Tirando, in più rispetto al bersaglio; allo sgancio, un piccolo balzo.
@export var release_hop := 3.0
@export var cooldown := 1.0
## Velocità a cui la lingua porta un rottame verso la rana.
@export var wreck_pull := 12.0

## Equipaggiata nella tana.
var enabled := false
## Miglioramenti speciali: la fionda (lasciando dopo un traino si parte a
## velocità doppia) e la lingua doppia (mentre una lingua trascina, l'altra
## mangia le mosche vicine).
var slingshot := false
var double_tongue := false
@export var double_tongue_reach := 6.0
## La lingua-catapulta (carta, slot lingua): aggancia solo rottami (e mosche),
## li tiene sospesi sopra la testa finché si tiene premuto e, lasciando, li
## scaglia dove guarda la telecamera. Miglioramenti: lancio lungo e strike
## (il rottame, colpita un'auto, rimbalza verso la più vicina).
var catapult := false
var long_throw := false
var strike := false
@export var throw_speed := 24.0
@export var long_throw_factor := 1.6
@export var hold_height := 2.8
## La lingua mangiafuoco (carta): ingoia il fuoco vicino (un rottame che fuma,
## una chiazza di fuoco, l'incendio) e lo risputa come palla di fuoco. Senza
## fuoco intorno è scarica. Miglioramenti: la raffica (tre palle più piccole)
## e il drago (la palla esplode).
var fire_eater := false
var volley := false
var dragon := false
## Fuoco in bocca, pronto da sputare.
var loaded := false
## La lingua-ancora (carta): aggancia una cosa che si muove (un'auto, un
## tronco, un coccodrillo, una nave; non treni né aerei) e la ferma per
## anchor_seconds. Miglioramenti: l'ancora pesante (il doppio del tempo) e la
## doppia ancora (due cose ferme insieme).
var anchor := false
var heavy_anchor := false
var double_anchor := false
@export var anchor_seconds := 4.0
var _anchored: Array[Node3D] = []
var _anchored_logs := {}
var _mouth_fire: CPUParticles3D
var cooldown_left := 0.0
## Vero mentre la lingua è agganciata a qualcosa.
var attached := false
## Il bersaglio che il mirino segna ora (null se nessuno).
var aimed: Node3D

var _frog: Frog
var _target: Node3D
var _anchor_local := Vector3.ZERO
var _last_anchor := Vector3.ZERO
var _length := 0.0
var _tongue: MeshInstance3D
var _sight: MeshInstance3D
var _flick_to := Vector3.ZERO
var _flick_left := 0.0
## Metri percorsi trascinata in questo traino (per la prova della lingua).
var _tow_distance := 0.0
var _tow_last := Vector3.ZERO


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
	# Il mirino: una punta rivolta in giù, sopra il bersaglio.
	_sight = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 0.0
	cone.height = 0.7
	cone.radial_segments = 4
	cone.rings = 1
	cone.material = Style.material("tongue")
	_sight.mesh = cone
	_sight.top_level = true
	_sight.visible = false
	frog.add_child(_sight)


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_flick_left = maxf(_flick_left - delta, 0.0)
	# La mangiafuoco non mira: prende il fuoco più vicino.
	aimed = _find_target() if is_ready() and not fire_eater else null
	_sight.visible = aimed != null
	if aimed:
		_sight.global_position = _top_of(aimed) + Vector3.UP * (1.2 + 0.15 * sin(Time.get_ticks_msec() / 150.0))
		_sight.rotation.y += delta * 4.0
	_draw_tongue()
	if anchor:
		_tick_anchor()
	if _mouth_fire and _mouth_fire.emitting:
		_mouth_fire.global_position = _mouth()


func is_ready() -> bool:
	return enabled and cooldown_left == 0.0 and not attached


## Da 0 (appena usata) a 1 (pronta).
func ready_ratio() -> float:
	return 1.0 if attached else 1.0 - cooldown_left / cooldown


## Aggancia ciò che il mirino segna. Falso se non c'è niente: la lingua
## scatta a vuoto e si ricarica in fretta.
func use() -> bool:
	if fire_eater:
		return _use_fire()
	var target := aimed if aimed else _find_target()
	Sfx.play(&"tongue_shoot")
	if target is Fly:
		# Una mosca si mangia al volo: niente aggancio, niente calore.
		_flick_to = target.global_position
		_flick_left = 0.15
		target.collect()
		cooldown_left = 0.3
		return true
	if target == null:
		cooldown_left = 0.3
		_flick_to = _mouth() - _frog.camera_rig.flat_basis().z * 3.0
		_flick_left = 0.12
		return false
	_frog.power_used.emit(&"tongue")
	if anchor:
		_anchor(target)
		return true
	attached = true
	_target = target
	Sfx.play_at(&"tongue_stick", _top_of(target))
	_anchor_local = target.to_local(_top_of(target))
	_last_anchor = target.to_global(_anchor_local)
	_length = _mouth().distance_to(_last_anchor)
	_frog.squash(Vector3(0.85, 0.85, 1.25), 0.2)
	if not _is_loose(target):
		Progress.trial_add("tongue", 0, 1)
		_tow_distance = 0.0
		_tow_last = _frog.global_position
	return true


## Un rottame si tira (vedi pull_wreck), tutto il resto trascina la rana.
func is_towing() -> bool:
	return attached and not _is_loose(_target)


## La fune: la rana segue il punto agganciato, che si muove col bersaglio, e
## la lingua si accorcia fino a tether_length. Dentro la lunghezza della fune
## la rana è libera (cade, scivola); oltre, la fune la tira.
func apply(delta: float) -> void:
	if not _still_hooked():
		release()
		return
	var anchor := _target.to_global(_anchor_local)
	var carried := (anchor - _last_anchor) / maxf(delta, 0.0001)
	_last_anchor = anchor
	_length = move_toward(_length, tether_length, reel_speed * delta)
	var to := anchor - _frog.global_position
	var distance := to.length()
	var relative := _frog.velocity - carried
	relative.y -= _frog.gravity_down * delta
	if distance > _length and distance > 0.01:
		var direction := to / distance
		var outward := -relative.dot(direction)
		if outward > 0.0:
			relative += direction * outward
		relative += direction * minf((distance - _length) * 12.0, pull_speed)
	_frog.velocity = carried + relative
	var moved := _frog.global_position - _tow_last
	_tow_distance += Vector2(moved.x, moved.z).length()
	_tow_last = _frog.global_position
	if double_tongue:
		_eat_nearby_flies()


## La lingua doppia: le mosche vicine finiscono in bocca da sole.
func _eat_nearby_flies() -> void:
	for fly: Node3D in _frog.get_tree().get_nodes_in_group("flies"):
		if fly.global_position.distance_to(_frog.global_position) < double_tongue_reach:
			fly.collect()


## Il rottame agganciato viene tirato verso la rana, fino a tether_length.
## Con la catapulta resta sospeso sopra la sua testa.
func pull_wreck(_delta: float) -> void:
	if not _still_hooked():
		release()
		return
	var body := _target as RigidBody3D
	# Un rottame fermo da un po' dorme: la lingua lo sveglia.
	body.sleeping = false
	if catapult:
		# Il rottame tenuto (e appena scagliato) non investe la rana.
		if body is Car:
			body.spare_frog(0.5)
		var hold := _frog.global_position + Vector3.UP * hold_height
		body.linear_velocity = (hold - body.global_position).limit_length(1.0) * minf(body.global_position.distance_to(hold) * 8.0, 26.0)
		body.angular_velocity = body.angular_velocity * 0.9
		return
	var toward := _frog.global_position - body.global_position
	toward.y = 0.0
	if toward.length() > tether_length + 1.0:
		body.linear_velocity = toward.normalized() * wreck_pull + Vector3.UP * 2.0


## Lasciato E (o perso l'aggancio): la rana vola via con lo slancio che ha.
func release() -> void:
	if not attached:
		return
	attached = false
	Sfx.play(&"tongue_reel")
	if catapult and is_instance_valid(_target) and _is_loose(_target):
		_throw(_target as RigidBody3D)
	elif not _is_loose(_target):
		Progress.trial_best("tongue", 1, _tow_distance)
		if slingshot:
			_frog.velocity.x *= 2.0
			_frog.velocity.z *= 2.0
		_frog.velocity.y = maxf(_frog.velocity.y, release_hop)
	_target = null
	cooldown_left = cooldown


## La catapulta: il rottame parte dove guarda la telecamera, un po' in alto.
func _throw(body: RigidBody3D) -> void:
	var forward := -_frog.camera_rig.flat_basis().z
	var speed := throw_speed * (long_throw_factor if long_throw else 1.0)
	body.linear_velocity = forward * speed + Vector3.UP * 4.0
	if body is Car:
		body.spare_frog(0.5)
	body.set_meta("thrown", 0)
	if strike:
		body.set_meta("strike", true)
	Progress.trial_add("catapult_tongue", 0, 1)
	_frog.squash(Vector3(0.85, 1.2, 0.85), 0.2)
	Sfx.play(&"punch_swing", 0.0, 0.8)


# --- La lingua-ancora ---------------------------------------------------------

## Ferma il bersaglio. Senza la doppia ancora, la nuova libera la vecchia.
func _anchor(target: Node3D) -> void:
	var limit := 2 if double_anchor else 1
	while _anchored.size() >= limit:
		var old: Node3D = _anchored.pop_front()
		if is_instance_valid(old):
			old.anchor(0.0)
	target.anchor(anchor_seconds * (2.0 if heavy_anchor else 1.0))
	_anchored.append(target)
	_flick_to = _top_of(target)
	_flick_left = 0.2
	cooldown_left = 1.0
	Sfx.play_at(&"tongue_stick", _flick_to, 0.0, 0.7)
	Progress.trial_add("anchor_tongue", 0, 1)


## I segni sopra le cose ancorate, e la prova della doppia ancora: i tronchi
## ancorati su cui si passa in una sola traversata.
func _tick_anchor() -> void:
	_anchored.assign(_anchored.filter(func(node: Node3D) -> bool: return is_instance_valid(node) and node.is_anchored()))
	var floor := _frog.floor_body()
	if floor is RiverLog and floor.is_anchored():
		_anchored_logs[floor.get_instance_id()] = true
		Progress.trial_best("anchor_tongue", 1, _anchored_logs.size())
	elif _frog.is_on_floor() and not (floor is Floater or floor is Ship):
		_anchored_logs.clear()


# --- La lingua mangiafuoco -----------------------------------------------------

## Scarica: ingoia il fuoco più vicino. Carica: sputa la palla di fuoco.
func _use_fire() -> bool:
	if loaded:
		_spit()
		return true
	var source := _fire_source()
	Sfx.play(&"tongue_shoot")
	if source == Vector3.INF:
		cooldown_left = 0.3
		_flick_to = _mouth() - _frog.camera_rig.flat_basis().z * 3.0
		_flick_left = 0.12
		return false
	_flick_to = source
	_flick_left = 0.2
	loaded = true
	cooldown_left = 0.4
	Sfx.play(&"sizzle", 0.0, 1.4)
	_mouth_flames(true)
	return true


## Il fuoco più vicino entro reach: un rottame che fuma, una chiazza di fuoco,
## il fronte dell'incendio. Vector3.INF se non c'è.
func _fire_source() -> Vector3:
	var best := Vector3.INF
	var best_gap := reach
	var points: Array[Vector3] = []
	for car in Car.smoking_wrecks():
		points.append(car.global_position)
	for patch in _frog.get_tree().get_nodes_in_group("fire_patches"):
		points.append(patch.global_position)
	var fire := _frog.get_tree().get_first_node_in_group("wildfire") as Wildfire
	if fire and fire.distance() < reach:
		points.append(Vector3(_frog.global_position.x, 1.0, fire.front_z))
	for point in points:
		var gap := point.distance_to(_frog.global_position)
		if gap < best_gap:
			best_gap = gap
			best = point
	return best


## La palla di fuoco (tre più piccole con la raffica) dove guarda la
## telecamera.
func _spit() -> void:
	loaded = false
	_mouth_flames(false)
	_frog.power_used.emit(&"tongue")
	cooldown_left = cooldown
	var forward := -_frog.camera_rig.flat_basis().z
	var angles := [-12.0, 0.0, 12.0] if volley else [0.0]
	for angle: float in angles:
		var ball := Fireball.new()
		ball.direction = forward.rotated(Vector3.UP, deg_to_rad(angle))
		ball.dragon = dragon
		ball.size = 0.7 if volley else 1.0
		_frog.get_parent().add_child(ball)
		ball.global_position = _mouth() + forward * 0.5
	Progress.trial_add("fire_tongue", 0, 1)
	_frog.squash(Vector3(1.2, 0.85, 1.2), 0.2)


## Col fuoco in bocca, due fiammelle escono dal muso.
func _mouth_flames(on: bool) -> void:
	if _mouth_fire == null:
		_mouth_fire = CPUParticles3D.new()
		_mouth_fire.amount = 10
		_mouth_fire.lifetime = 0.35
		_mouth_fire.direction = Vector3.UP
		_mouth_fire.spread = 25.0
		_mouth_fire.initial_velocity_min = 1.0
		_mouth_fire.initial_velocity_max = 2.0
		_mouth_fire.gravity = Vector3.ZERO
		var mesh := SphereMesh.new()
		mesh.radius = 0.08
		mesh.height = 0.16
		mesh.radial_segments = 5
		mesh.rings = 2
		mesh.material = Style.material("fire")
		_mouth_fire.mesh = mesh
		_mouth_fire.top_level = true
		_frog.add_child(_mouth_fire)
	_mouth_fire.emitting = on


## Senza sgancio né slancio: un colpo interrompe tutto.
func stop() -> void:
	attached = false
	_target = null


func _still_hooked() -> bool:
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		return false
	# Il bersaglio esce dalla zona di gioco: la lingua si stacca prima del bordo.
	return absf(_target.to_global(_anchor_local).x) < _frog.play_half_width - 1.0


## Si ancora un'auto in marcia, un tronco, un coccodrillo, una nave.
static func _can_anchor(body: Node3D) -> bool:
	if body is Car:
		return body.state == Car.State.DRIVING
	return body is Floater or body is Ship


static func _is_loose(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	return rigid != null and not rigid.freeze


func _mouth() -> Vector3:
	return _frog.mouth_position()


func _draw_tongue() -> void:
	var to := Vector3.ZERO
	if attached and is_instance_valid(_target):
		to = _target.to_global(_anchor_local)
	elif _flick_left > 0.0:
		to = _flick_to
	var mouth := _mouth()
	_tongue.visible = to != Vector3.ZERO and mouth.distance_to(to) > 0.3
	if _tongue.visible:
		_tongue.global_position = (mouth + to) / 2.0
		var up := Vector3.UP if absf((to - mouth).normalized().y) < 0.99 else Vector3.FORWARD
		_tongue.look_at(to, up)
		_tongue.scale = Vector3(1.0, 1.0, mouth.distance_to(to))


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
	# Le mosche prima di tutto: il mirino le preferisce.
	for fly: Node3D in _frog.get_tree().get_nodes_in_group("flies"):
		var to_fly := fly.global_position - _frog.global_position
		var flat_fly := Vector3(to_fly.x, 0.0, to_fly.z)
		if to_fly.length() > reach or flat_fly.length() < 0.3:
			continue
		var fly_angle := rad_to_deg(forward.angle_to(flat_fly))
		if fly_angle > max_angle:
			continue
		var fly_score := fly_angle + flat_fly.length() * 2.0 - 30.0
		if fly_score < best_score:
			best_score = fly_score
			best = fly
	for result in space.intersect_shape(query, 64):
		var body := result.collider as Node3D
		if body == null or body == standing_on:
			continue
		# La catapulta prende solo quello che si può scagliare; l'ancora solo
		# quello che si può fermare.
		if catapult and not _is_loose(body):
			continue
		if anchor and not _can_anchor(body):
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


## Il punto più alto del bersaglio sopra il suo centro (una mosca: lei).
func _top_of(target: Node3D) -> Vector3:
	if target is Fly:
		return target.global_position
	var space := _frog.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(target.global_position + Vector3.UP * 12.0, target.global_position + Vector3.DOWN * 3.0, 4 | 8)
	for i in 4:
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			break
		if hit.collider == target:
			return hit.position + Vector3.UP * 0.3
		ray.exclude = ray.exclude + [hit.rid]
	return target.global_position + Vector3.UP * 1.5
