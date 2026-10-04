class_name Airplane
extends AnimatableBody3D
## Un aereo di linea in rullaggio: enorme e lento, non diventa mai rottame.
## Sotto le ali si passa; fusoliera, motori e carrelli travolgono rana e
## veicoli; sulle ali e sulla fusoliera si sta sicuri. Dietro ogni motore c'è
## una fiamma che brucia, e poi un getto a cono che spinge via la rana e
## scaglia rottami e bagagli: col deltaplano aperto la solleva in alto.
## Il decollo (il gradino dell'aeroporto): l'aereo si ferma sul raccordo, la
## fiamma e il getto si allungano per SPOOL_TIME secondi, poi accelera fino a
## ROLL_SPEED col getto lungo il doppio e più forte, e fuori dalla zona di
## gioco si alza in volo. Corre lungo l'asse X locale del raccordo.

const MODEL := preload("res://assets/models/airplane.glb")
const LENGTH := 24.0
## Getto dietro i motori: lunghezza, velocità del vento che spinge la rana,
## spinta verso l'alto per il deltaplano e accelerazione data ai rottami. Il
## getto si allarga e si alza: in fondo è largo BLAST_END_WIDTH e alto
## BLAST_END_HEIGHT.
const BLAST_LENGTH := 22.0
const BLAST_END_WIDTH := 8.0
const BLAST_END_HEIGHT := 12.0
const BLAST_WIND := 16.0
const BLAST_LIFT := 45.0
const BLAST_STRENGTH := 55.0
## La fiamma subito dietro ogni motore: lunga, larga e quanta vita toglie al
## secondo. Si vede: è il pericolo di chi attraversa dietro l'aereo.
const FLAME_LENGTH := 7.0
const FLAME_WIDTH := 2.2
const FLAME_BURN := 60.0
const ENGINE_X := 6.0
## Il retro dei motori, da dove escono fiamma e getto.
const NOZZLE := Vector3(ENGINE_X, 1.75, 0.5)
## Il decollo: secondi da fermo coi motori che salgono di giri, accelerazione
## e velocità massima della corsa, e quanto si allungano fiamma e getto (e
## quanto rinforza il vento) a pieni giri.
const SPOOL_TIME := 2.0
const ROLL_ACCELERATION := 7.0
const ROLL_SPEED := 35.0
const TAKEOFF_POWER := 2.0
const TAKEOFF_WIND := 1.6

enum Phase { TAXI, SPOOL, ROLL }

var direction := 1.0
var speed := 7.0
var damage := 35
var smash_speed := 14.0
## Se decolla, e il punto del raccordo (centro dell'aereo) in cui si ferma.
var takeoff := false
var hold_x := 0.0
var phase := Phase.TAXI
## Giri dei motori: 1 in rullaggio, fino a TAKEOFF_POWER al decollo.
var power := 1.0
## Fin dove arriva la zona di gioco: oltre, l'aereo che decolla si alza.
var play_half_width := 37.0

var _hazards: Array[Area3D] = []
var _blasts: Array[Area3D] = []
var _flames: Array[Area3D] = []
var _flame_meshes: Array[MeshInstance3D] = []
var _streaks: Array[CPUParticles3D] = []
## Getto e fiamma lunghi del decollo: attivi solo sopra i giri del rullaggio.
var _long_blasts: Array[Area3D] = []
var _long_flames: Array[Area3D] = []
var _timer := 0.0
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
		var nozzle := Vector3(side * NOZZLE.x, NOZZLE.y, NOZZLE.z)
		_blasts.append(_blast_area(nozzle))
		_flames.append(_area(Vector3(FLAME_WIDTH, FLAME_WIDTH, FLAME_LENGTH), nozzle + Vector3(0.0, 0.0, FLAME_LENGTH / 2.0)))
		_flame_meshes.append(_flame_mesh(nozzle))
		var streaks := _blast_streaks(nozzle)
		add_child(streaks)
		_streaks.append(streaks)
		if takeoff:
			_long_blasts.append(_blast_area(nozzle, TAKEOFF_POWER))
			_long_flames.append(_area(Vector3(FLAME_WIDTH, FLAME_WIDTH, FLAME_LENGTH * TAKEOFF_POWER), nozzle + Vector3(0.0, 0.0, FLAME_LENGTH * TAKEOFF_POWER / 2.0)))


func _physics_process(delta: float) -> void:
	match phase:
		Phase.TAXI:
			position.x += direction * speed * delta
			if takeoff and (position.x - hold_x) * direction >= 0.0:
				phase = Phase.SPOOL
				_timer = SPOOL_TIME
		Phase.SPOOL:
			_timer -= delta
			power = lerpf(TAKEOFF_POWER, 1.0, maxf(_timer, 0.0) / SPOOL_TIME)
			if _timer <= 0.0:
				phase = Phase.ROLL
				speed = 0.0
		Phase.ROLL:
			speed = minf(speed + ROLL_ACCELERATION * delta, ROLL_SPEED)
			position.x += direction * speed * delta
			# Fuori dalla zona di gioco si alza: muso in su e via.
			if position.x * direction > play_half_width + LENGTH / 2.0:
				position.y += speed * 0.25 * delta
				rotation.x = move_toward(rotation.x, 0.15, 0.2 * delta)
	_smash()
	_push()
	_burn(delta)


func _process(_delta: float) -> void:
	# La fiamma tremola, e al decollo si allunga.
	for flame in _flame_meshes:
		flame.scale = Vector3(randf_range(0.85, 1.1), randf_range(0.9, 1.15), randf_range(0.85, 1.1) * power)
	for streaks in _streaks:
		streaks.initial_velocity_min = 20.0 * power
		streaks.initial_velocity_max = 28.0 * power


## Vero mentre l'aereo è fermo sul raccordo e i motori salgono di giri.
func is_spooling() -> bool:
	return phase == Phase.SPOOL


func is_rolling() -> bool:
	return phase == Phase.ROLL


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
## Al decollo il getto è lungo power volte tanto e il vento più forte.
func _push() -> void:
	var backward := global_basis.z
	var length := BLAST_LENGTH * power
	var wind := BLAST_WIND * lerpf(1.0, TAKEOFF_WIND, (power - 1.0) / (TAKEOFF_POWER - 1.0))
	for area in (_long_blasts if power > 1.05 else _blasts):
		for body in area.get_overlapping_bodies():
			var distance: float = (body.global_position - area.global_position).dot(backward)
			if distance > length:
				continue
			var strength := 1.0 - 0.6 * clampf(distance / length, 0.0, 1.0)
			# Il getto porta via i bagagli dai carrelli, poi li scaglia.
			if body is Baggage and body.loaded:
				body.release()
			if body is Frog:
				body.apply_wind(backward * wind * strength, BLAST_LIFT * strength)
			elif body is RigidBody3D and not body.freeze:
				var acceleration := (backward * BLAST_STRENGTH + Vector3.UP * 12.0) * strength
				body.apply_central_force(acceleration * body.mass)


func _burn(delta: float) -> void:
	var backward := global_basis.z
	for area in (_long_flames if power > 1.05 else _flames):
		for body in area.get_overlapping_bodies():
			# L'area lunga è centrata a metà: conta quanto è lunga ora la fiamma.
			var distance: float = (body.global_position - area.global_position).dot(backward) + area.get_child(0).shape.size.z / 2.0
			if body is Frog and distance <= FLAME_LENGTH * power + 0.5:
				body.burn(FLAME_BURN, delta)


func _solid(size: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	add_child(collision)


func _hazard(size: Vector3, at: Vector3) -> void:
	_hazards.append(_area(size, at))


## Il getto è un tronco di piramide che parte dal motore e si allarga
## all'indietro, soprattutto verso l'alto.
func _blast_area(at: Vector3, scale_length := 1.0) -> Area3D:
	var area := _area(Vector3.ONE, at)
	var end_length := BLAST_LENGTH * scale_length
	var shape := ConvexPolygonShape3D.new()
	var near := Vector2(1.6, 1.8)
	var points := PackedVector3Array()
	for x in [-1.0, 1.0]:
		points.append(Vector3(x * near.x, -near.y, 0.0))
		points.append(Vector3(x * near.x, near.y, 0.0))
		points.append(Vector3(x * BLAST_END_WIDTH / 2.0, -at.y, end_length))
		points.append(Vector3(x * BLAST_END_WIDTH / 2.0, BLAST_END_HEIGHT - at.y, end_length))
	shape.points = points
	(area.get_child(0) as CollisionShape3D).shape = shape
	return area


## Strisce d'aria che corrono all'indietro e si aprono verso l'alto: fanno
## vedere dove arriva il getto, cioè dove il deltaplano sale.
func _blast_streaks(at: Vector3) -> CPUParticles3D:
	var streaks := CPUParticles3D.new()
	streaks.position = at
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 1.2, 0.12)
	mesh.material = Style.material("jet_air")
	streaks.mesh = mesh
	streaks.amount = 36
	streaks.lifetime = 0.9
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	streaks.emission_box_extents = Vector3(1.0, 0.8, 0.2)
	# Indietro (+Z) e un po' in su: lo stesso cono della zona che spinge.
	streaks.direction = Vector3(0.0, 0.22, 1.0)
	streaks.spread = 9.0
	streaks.gravity = Vector3.ZERO
	streaks.initial_velocity_min = 20.0
	streaks.initial_velocity_max = 28.0
	streaks.particle_flag_align_y = true
	streaks.scale_amount_min = 0.8
	streaks.scale_amount_max = 1.6
	return streaks


## Un cono basso e luminoso: largo al motore, si stringe all'indietro.
func _flame_mesh(at: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.85
	mesh.height = FLAME_LENGTH
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = Style.material("jet_flame")
	var pivot := MeshInstance3D.new()
	pivot.position = at
	add_child(pivot)
	var flame := MeshInstance3D.new()
	flame.mesh = mesh
	# L'asse del cilindro (Y) va all'indietro (+Z): la base larga sta al motore.
	flame.rotation.x = PI / 2.0
	flame.position.z = FLAME_LENGTH / 2.0
	pivot.add_child(flame)
	return pivot


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
