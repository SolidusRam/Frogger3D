class_name Airplane
extends AnimatableBody3D
## Un aereo di linea: enorme, non diventa mai rottame. Arriva dal cielo e
## atterra sulla pista (land), in quattro fasi:
## - APPROACH: scende lungo una rampa fino al punto di contatto. Sotto di lui,
##   a terra, si passa; chi salta o vola gli finisce contro. A terra c'è la sua
##   ombra, e nel punto di contatto una fila di luci rosse lampeggia.
## - ROLLOUT: tocca terra (scintille, fumo dalle gomme) e frena coi motori al
##   contrario, che soffiano in avanti e spazzano rana e bagagli.
## - TAXI: rulla lento. Sotto le ali si passa; fusoliera, motori e carrelli
##   travolgono; sulle ali e sulla fusoliera si sta sicuri. Dietro ogni motore
##   una fiamma che brucia e un getto a cono che spinge via la rana e scaglia
##   rottami e bagagli: col deltaplano aperto la solleva in alto.
## - BELLY, l'atterraggio di pancia (il gradino dell'aeroporto): i carrelli
##   cedono, l'aereo tocca terra appena entrato e scivola basso e storto su
##   tutta la pista, con scintille e chiazze di fuoco dietro di sé; sotto le
##   ali non si passa più, e l'ala spazza i trenini bagagli. Già in volo perde
##   fumo nero da un motore: lo si riconosce da lontano.
## Un aereo creato con create() parte già in rullaggio. Corre lungo l'asse X
## locale della pista.

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
## L'atterraggio: velocità d'avvicinamento (a calore zero), discesa per
## metro percorso, frenata dopo il contatto, vento dei motori al contrario e
## fin dove arriva davanti ai motori.
const APPROACH_SPEED := 14.0
const GLIDE_SLOPE := 0.2
const ROLLOUT_BRAKING := 2.5
const REVERSE_WIND := 10.0
const REVERSE_LENGTH := 18.0
## La pancia: velocità al contatto, frenata, quanto affonda (i carrelli sono
## ceduti), quanto sbanda e ogni quanti metri lascia una chiazza di fuoco.
const BELLY_SPEED := 20.0
const BELLY_BRAKING := 0.9
const BELLY_SINK := 0.9
const BELLY_SWAY := 0.3
const BELLY_FIRE_SPACING := 4.0

enum Phase { APPROACH, ROLLOUT, TAXI, BELLY }

var direction := 1.0
## Velocità del rullaggio (col calore); avvicinamento e pancia ne derivano.
var speed := 7.0
var taxi_speed := 7.0
var damage := 35
var smash_speed := 14.0
var phase := Phase.TAXI
## Dove tocca terra (x lungo la pista) e se atterra di pancia.
var touchdown_x := 0.0
var belly := false
## Fin dove arriva la zona di gioco (le chiazze di fuoco solo lì dentro).
var play_half_width := 37.0

var _hazards: Array[Area3D] = []
var _blasts: Array[Area3D] = []
var _reverse_blasts: Array[Area3D] = []
var _flames: Array[Area3D] = []
var _flame_meshes: Array[Node3D] = []
var _streaks: Array[CPUParticles3D] = []
var _reverse_streaks: Array[CPUParticles3D] = []
var _base_yaw := 0.0
var _time := 0.0
var _last_hit := {}
var _shadow: Node3D
var _marker: Node3D
var _sparks: CPUParticles3D
var _engine_smoke: CPUParticles3D
var _fire_left := 0.0


## Crea un aereo già orientato. Rotazione e sync_to_physics vanno impostati
## prima che il corpo entri nella scena: attivare sync_to_physics dopo
## riporterebbe il nodo all'orientamento con cui il corpo era stato registrato.
static func create(travel_direction: float, travel_speed: float) -> Airplane:
	var plane := Airplane.new()
	plane.direction = travel_direction
	plane.speed = travel_speed
	plane.taxi_speed = travel_speed
	plane.sync_to_physics = true
	# Il muso del modello guarda verso -Z: lo si gira nel verso di marcia.
	plane.rotation.y = -PI / 2.0 * travel_direction
	return plane


## Un aereo che arriva dal cielo e tocca terra nel punto at_x della pista
## (di pancia se belly): parte in volo, sulla rampa, approach metri prima.
## Prima che entri nella scena, come create().
func land(at_x: float, approach: float, on_belly: bool) -> void:
	touchdown_x = at_x
	belly = on_belly
	phase = Phase.APPROACH
	speed = APPROACH_SPEED * taxi_speed / 7.0
	position.x = at_x - direction * approach
	position.y = approach * GLIDE_SLOPE


func _ready() -> void:
	_base_yaw = rotation.y
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
		var streaks := _blast_streaks(nozzle, Vector3(0.0, 0.22, 1.0))
		add_child(streaks)
		_streaks.append(streaks)
		# I motori al contrario: davanti a ogni motore.
		var front := Vector3(side * ENGINE_X, 1.75, -2.9)
		_reverse_blasts.append(_area(Vector3(7.0, 6.0, REVERSE_LENGTH), front + Vector3(0.0, 1.2, -REVERSE_LENGTH / 2.0)))
		var reverse := _blast_streaks(front, Vector3(0.0, 0.1, -1.0))
		add_child(reverse)
		_reverse_streaks.append(reverse)
	if belly:
		# L'ala bassa spazza tutto: rana e bagagli dei trenini.
		_hazard(Vector3(26.0, 1.4, 5.0), Vector3(0.0, 2.0, 0.5))
	if phase == Phase.APPROACH:
		_build_shadow()
		_build_marker()
	_sparks = _spark_emitter()
	add_child(_sparks)
	if belly:
		_engine_smoke = _smoke_trail(Vector3(-ENGINE_X, 1.75, 0.5))
		add_child(_engine_smoke)
	_set_engines()


func _physics_process(delta: float) -> void:
	_time += delta
	var moved := transform
	match phase:
		Phase.APPROACH:
			moved.origin.x += direction * speed * delta
			var left := (touchdown_x - moved.origin.x) * direction
			if left <= 0.0:
				moved.origin.y = -BELLY_SINK if belly else 0.0
				moved.basis = Basis.from_euler(Vector3(0.0, _base_yaw, 0.0))
				_touch_down()
			else:
				moved.origin.y = left * GLIDE_SLOPE
				# Il muso un po' in su, come in richiamata.
				moved.basis = Basis.from_euler(Vector3(0.08, _base_yaw, 0.0))
		Phase.ROLLOUT:
			speed = move_toward(speed, taxi_speed, ROLLOUT_BRAKING * delta)
			moved.origin.x += direction * speed * delta
			if speed <= taxi_speed:
				phase = Phase.TAXI
				_set_engines()
		Phase.TAXI:
			moved.origin.x += direction * speed * delta
		Phase.BELLY:
			speed = maxf(speed - BELLY_BRAKING * delta, taxi_speed)
			moved.origin.x += direction * speed * delta
			# Scivola storto, ondeggiando, un po' coricato su un'ala.
			var sway := sin(_time * 1.7) * BELLY_SWAY
			moved.basis = Basis.from_euler(Vector3(-0.04, _base_yaw + sway, 0.06))
			_fire_left -= speed * delta
			if _fire_left <= 0.0 and absf(moved.origin.x) < play_half_width + 5.0:
				_fire_left = BELLY_FIRE_SPACING
				_drop_fire(moved.origin)
	# Una sola scrittura: con sync_to_physics una seconda partirebbe dal
	# trasform vecchio e annullerebbe la prima.
	transform = moved
	_smash()
	_push()
	_burn(delta)


func _process(_delta: float) -> void:
	# La fiamma tremola.
	for flame in _flame_meshes:
		flame.scale = Vector3(randf_range(0.85, 1.1), randf_range(0.9, 1.15), randf_range(0.85, 1.1))
	if _shadow:
		_update_shadow()
	if _marker:
		# Le luci del punto di contatto lampeggiano.
		_marker.visible = fmod(_time, 0.4) < 0.25


## Vero mentre l'aereo è in volo, prima di toccare terra.
func is_flying() -> bool:
	return phase == Phase.APPROACH


## Quota sopra la pista, in metri.
func altitude() -> float:
	return position.y


## Coda dell'aereo lungo la pista (l'origine è al centro).
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
			elif body is Baggage:
				# L'ala della pancia spazza i carrelli: il carico vola.
				if body.loaded:
					body.release()
				body.linear_velocity = (push + Vector3.UP * 0.5).normalized() * randf_range(10.0, 18.0)
			elif body is Frog:
				body.take_hit(damage, push * 13.0)


## Il getto: in rullaggio spinge all'indietro rispetto all'aereo, più forte
## vicino ai motori, con un po' di spinta verso l'alto; in frenata i motori al
## contrario soffiano in avanti, senza sollevare.
func _push() -> void:
	if phase == Phase.TAXI:
		_blow(_blasts, global_basis.z, BLAST_LENGTH, BLAST_WIND, BLAST_LIFT, true)
	elif phase == Phase.ROLLOUT:
		_blow(_reverse_blasts, -global_basis.z, REVERSE_LENGTH * 1.5, REVERSE_WIND, 0.0, false)


func _blow(areas: Array[Area3D], toward: Vector3, length: float, wind: float, lift: float, from_nozzle: bool) -> void:
	for area in areas:
		for body in area.get_overlapping_bodies():
			var distance: float = (body.global_position - area.global_position).dot(toward)
			if not from_nozzle:
				# L'area dei motori al contrario è centrata: si conta dal motore.
				distance += REVERSE_LENGTH / 2.0
			if distance > length:
				continue
			var strength := 1.0 - 0.6 * clampf(distance / length, 0.0, 1.0)
			# Il getto porta via i bagagli dai carrelli, poi li scaglia.
			if body is Baggage and body.loaded:
				body.release()
			if body is Frog:
				body.apply_wind(toward * wind * strength, lift * strength)
			elif body is RigidBody3D and not body.freeze:
				var acceleration := (toward * BLAST_STRENGTH + Vector3.UP * 12.0) * strength
				body.apply_central_force(acceleration * body.mass)


func _burn(delta: float) -> void:
	if phase != Phase.TAXI:
		return
	var backward := global_basis.z
	for area in _flames:
		for body in area.get_overlapping_bodies():
			var distance: float = (body.global_position - area.global_position).dot(backward) + FLAME_LENGTH / 2.0
			if body is Frog and distance <= FLAME_LENGTH + 0.5:
				body.burn(FLAME_BURN, delta)


## Il contatto: scintille e fumo dalle gomme (o dalla pancia), una scossa a
## chi è vicino; poi la frenata, o la scivolata di pancia.
func _touch_down() -> void:
	if _shadow:
		_shadow.queue_free()
		_shadow = null
	if _marker:
		_marker.queue_free()
		_marker = null
	phase = Phase.BELLY if belly else Phase.ROLLOUT
	if belly:
		speed = BELLY_SPEED * taxi_speed / 7.0
		_fire_left = 0.0
	_sparks.emitting = true
	if not belly:
		get_tree().create_timer(0.5).timeout.connect(_sparks.set_emitting.bind(false))
	var smoke := _smoke_trail(Vector3(0.0, 0.3, 2.0))
	smoke.amount = 24
	smoke.lifetime = 1.4
	add_child(smoke)
	get_tree().create_timer(0.8).timeout.connect(smoke.set_emitting.bind(false))
	var frog := get_tree().get_first_node_in_group("frog") as Frog
	if frog and frog.global_position.distance_to(global_position) < 30.0:
		frog.camera_rig.shake(0.35 if belly else 0.2, 0.4)
	_set_engines()


## Fiamme, getti e strisce d'aria accesi secondo la fase.
func _set_engines() -> void:
	for flame in _flame_meshes:
		flame.visible = phase == Phase.TAXI
	for streaks in _streaks:
		streaks.emitting = phase == Phase.TAXI
	for streaks in _reverse_streaks:
		streaks.emitting = phase == Phase.ROLLOUT


func _drop_fire(at: Vector3) -> void:
	var patch := FirePatch.new()
	patch.position = Vector3(at.x, 0.0, at.z + (1.5 if fmod(_time, 0.6) < 0.3 else -1.5))
	get_parent().add_child(patch)


## L'ombra sulla pista, sotto l'aereo in volo: la sagoma di fusoliera e ali,
## più larga e più chiara quando l'aereo è alto.
func _build_shadow() -> void:
	_shadow = Node3D.new()
	_shadow.top_level = true
	_shadow.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for part in [[Vector3(3.6, 0.02, LENGTH), Vector3.ZERO], [Vector3(26.0, 0.02, 5.0), Vector3(0.0, 0.0, 0.5)], [Vector3(9.0, 0.02, 2.6), Vector3(0.0, 0.0, 10.5)]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		box.material = Style.material("plane_shadow")
		mesh.mesh = box
		mesh.position = part[1]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shadow.add_child(mesh)
	add_child(_shadow)
	_update_shadow()


func _update_shadow() -> void:
	var ground := (get_parent() as Node3D).global_transform * Vector3(position.x, 0.04, position.z)
	var spread := 1.0 + altitude() * 0.025
	_shadow.global_transform = Transform3D(Basis(Vector3.UP, global_rotation.y).scaled(Vector3(spread, 1.0, spread)), ground)


## Le luci rosse di traverso sulla pista, nel punto in cui l'aereo toccherà
## terra: da lì in poi la pista è pericolosa a terra.
func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.top_level = true
	var lamp := BoxMesh.new()
	lamp.size = Vector3(1.3, 0.25, 1.3)
	lamp.material = Style.material("signal_on")
	for i in 9:
		var light := MeshInstance3D.new()
		light.mesh = lamp
		light.position = Vector3(0.0, 0.12, -12.0 + i * 3.0)
		_marker.add_child(light)
	add_child(_marker)
	_marker.global_position = (get_parent() as Node3D).global_transform * Vector3(touchdown_x, 0.0, position.z)


func _spark_emitter() -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	var dot := BoxMesh.new()
	dot.size = Vector3(0.12, 0.12, 0.12)
	dot.material = Style.material("spark")
	sparks.mesh = dot
	sparks.amount = 60
	sparks.lifetime = 0.5
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(3.0, 0.2, 8.0)
	sparks.position = Vector3(0.0, 0.3, 0.0)
	sparks.direction = Vector3(0.0, 1.0, 1.0)
	sparks.spread = 50.0
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 9.0
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.emitting = false
	return sparks


## Fumo che resta nell'aria: il motore in avaria, le gomme al contatto.
func _smoke_trail(at: Vector3) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.6
	puff.height = 1.2
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = Style.material("smoke")
	smoke.mesh = puff
	smoke.amount = 30
	smoke.lifetime = 2.5
	smoke.local_coords = false
	smoke.position = at
	smoke.direction = Vector3.UP
	smoke.spread = 25.0
	smoke.gravity = Vector3(0.0, 0.6, 0.0)
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.5
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.0
	Style.fade_smoke(smoke)
	smoke.emitting = true
	return smoke


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
func _blast_area(at: Vector3) -> Area3D:
	var area := _area(Vector3.ONE, at)
	var end_length := BLAST_LENGTH
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


## Strisce d'aria che corrono nella direzione del getto (all'indietro e un po'
## in su: dove il deltaplano sale; in avanti per i motori al contrario).
func _blast_streaks(at: Vector3, toward: Vector3) -> CPUParticles3D:
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
	streaks.direction = toward
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
