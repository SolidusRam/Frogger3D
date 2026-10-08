class_name Formation
extends Node3D
## Un passaggio della pattuglia acrobatica (vedi Aerobatics, il bioma del
## cielo). Il capo vola in alto, innocuo, e disegna la scia; i gregari
## arrivano dopo, bassi, e ripercorrono esattamente la sua strada LIFT metri
## più sotto: passano sotto il fumo. Sul banco di nubi la scia lascia anche
## un'ombra colorata, che dice dove passeranno. Curve in piano e giri della
## morte (in cima si passa sotto, in basso no). Sugli aerei si sale, come sui
## tetti delle auto. Il gradino del livello 3: il capo ha perso il controllo e
## la sua scia è uno scarabocchio, che i gregari seguono fedeli.
## Colpito il capo (un pugno vicino, o la rana che gli finisce addosso), il
## capo precipita e i gregari lo seguono: si schiantano dove si schianta lui,
## o spariscono con lui nel vuoto. Corre lungo l'asse X locale.

const MODEL := preload("res://assets/models/stunt_plane.glb")
## Quanto il capo vola più in alto dei gregari.
const LIFT := 7.0
## La quota dei gregari: la fusoliera va da 0,65 a 1,55 m, all'altezza della
## rana; col salto normale ci si sale sopra.
const CRUISE_Y := 1.1
## Distanza fra i punti del percorso.
const SAMPLE := 0.25
const LOOP_RADIUS := 4.5
const GRAVITY := 14.0
## Il capo si colpisce con un pugno da qui.
const LEADER_REACH := 4.0
const HIT_DAMAGE := 30
const CRASH_RADIUS := 4.5
const CRASH_DAMAGE := 30
const TRAIL_COLORS: Array[String] = ["trail_green", "trail_white", "trail_red"]

var direction := 1.0
var speed := 16.0
var wingmen := 3
## Secondi fra il capo e il primo gregario, e fra un gregario e l'altro.
var first_delay := 1.6
var spacing := 0.38
## Mezza profondità del blocco: le curve ci stanno dentro.
var half_depth := 10.0
## Da dove entra a dove esce, lungo X.
var half_length := 70.0
var loop_chance := 0.75
## Un secondo giro della morte, nei passaggi che ne hanno già uno.
var double_loop_chance := 0.35
## Il gradino: lo scarabocchio.
var scribble := false

## Il percorso dei gregari (punti e "alto" di ogni punto).
var _points: Array[Vector3] = []
var _ups: Array[Vector3] = []
## Dove passano i gregari, un passo di fisica dopo l'altro: il primo
## gregario è indietro di _delays[0] passi.
var _ghost: Array[Transform3D] = []
var _leader: AnimatableBody3D
var _wingmen: Array[AnimatableBody3D] = []
var _delays: Array[int] = []
var _hit_wait: Array[float] = []
var _s := 0.0
var _crashed := false
var _crash_time := 0.0
var _fall_velocity := Vector3.ZERO
## Dove è finito il capo precipitato: "ground" (sul banco) o "void".
var _crash_end := ""
var _shadow: Node3D
var _frog: Frog
var _trail_key := ""


func _ready() -> void:
	_frog = get_tree().get_first_node_in_group("frog") as Frog
	_trail_key = TRAIL_COLORS[randi() % TRAIL_COLORS.size()]
	_build_path()
	var steps := Engine.physics_ticks_per_second
	for i in wingmen:
		_delays.append(roundi((first_delay + spacing * i) * steps))
		_hit_wait.append(0.0)
	_leader = _make_plane(true)
	for i in wingmen:
		_wingmen.append(_make_plane(false))
	_shadow = Node3D.new()
	add_child(_shadow)
	var lifetime := first_delay + spacing * wingmen + 1.2
	_leader.add_child(_trail(lifetime, false))
	_shadow.add_child(_trail(lifetime, true))
	Sfx.loop(_leader, &"jet_loop", -8.0, 1.5, 3.0, true)
	if _frog:
		_frog.power_used.connect(_on_power_used)
	_place_all()


func _physics_process(delta: float) -> void:
	_fly_leader(delta)
	_fly_wingmen(delta)
	if _leader == null and _wingmen.is_empty():
		queue_free()


func _fly_leader(delta: float) -> void:
	if not _crashed:
		_s += speed * delta
		var path := _sample(_s)
		if _leader:
			_leader.transform = path.translated(Vector3.UP * LIFT)
			if _s > _length() + 10.0:
				_leader.queue_free()
				_leader = null
		_record(path)
		return
	if _leader == null:
		return
	# Precipita: va dove lo porta lo slancio, e la gravità.
	_crash_time += delta
	_fall_velocity.y -= GRAVITY * delta
	var position_now := _leader.position + _fall_velocity * delta
	var heading := _fall_velocity.normalized()
	var spin := Basis(heading, _crash_time * 6.0)
	_leader.transform = Transform3D(spin * Basis.looking_at(heading, Vector3.UP if absf(heading.y) < 0.99 else Vector3.FORWARD), position_now)
	# I gregari scendono dalla loro quota a quella del capo in poco tempo.
	var drop := LIFT * maxf(0.0, 1.0 - _crash_time / 0.6)
	_record(Transform3D(_leader.transform.basis, position_now - Vector3.UP * drop))
	if position_now.y <= CRUISE_Y - 0.5 and _ground_below(_leader.global_position):
		_crash_end = "ground"
		_explode(_leader)
		_leader = null
	elif position_now.y < -30.0:
		_crash_end = "void"
		_leader.queue_free()
		_leader = null


func _fly_wingmen(delta: float) -> void:
	var still_recording := _leader != null or not _crashed
	for i in range(_wingmen.size() - 1, -1, -1):
		var plane := _wingmen[i]
		var index := _ghost.size() - 1 - _delays[i]
		if index < 0:
			# Non ancora entrato: aspetta sulla strada, prima della partenza.
			plane.transform = _sample(index * speed / Engine.physics_ticks_per_second)
			continue
		if index >= _ghost.size() - 1 and not still_recording:
			# Arrivato dove è finito il capo.
			if _crash_end == "ground":
				_explode(plane)
			else:
				plane.queue_free()
			_wingmen.remove_at(i)
			_delays.remove_at(i)
			_hit_wait.remove_at(i)
			continue
		plane.transform = _ghost[index]
		# Il capo non c'è più e la strada non si allunga: i gregari la
		# percorrono fino in fondo, un passo alla volta.
		if not still_recording:
			_delays[i] -= 1
		if not _crashed and _s - (_delays[i] * speed / Engine.physics_ticks_per_second) > _length() + 10.0:
			plane.queue_free()
			_wingmen.remove_at(i)
			_delays.remove_at(i)
			_hit_wait.remove_at(i)
			continue
		_hit_wait[i] = maxf(_hit_wait[i] - delta, 0.0)
		_check_hit(plane, i)


## Il gregario travolge la rana che tocca (non chi gli sta sopra: la zona
## d'impatto è più bassa del dorso).
func _check_hit(plane: AnimatableBody3D, i: int) -> void:
	if _hit_wait[i] > 0.0:
		return
	var area: Area3D = plane.get_node("Hazard")
	for body in area.get_overlapping_bodies():
		if body is Frog:
			var forward := -plane.global_basis.z
			body.take_hit(HIT_DAMAGE, forward * 9.0 + Vector3.UP * 6.0)
			_hit_wait[i] = 0.5


## Un pugno vicino al capo lo abbatte.
func _on_power_used(power: StringName) -> void:
	if power == &"punch" and _leader and not _crashed and _frog.global_position.distance_to(_leader.global_position) <= LEADER_REACH:
		crash()


func _on_leader_touched(body: Node3D) -> void:
	if body is Frog and not _crashed:
		crash()


## Il capo precipita: i gregari lo seguiranno.
func crash() -> void:
	if _crashed or _leader == null:
		return
	_crashed = true
	_fall_velocity = -_leader.basis.z * speed * 0.8 + Vector3(0.0, -2.0, randf_range(-3.0, 3.0))
	Sfx.play_at(&"punch_hit", _leader.global_position, 0.0, 0.8)
	Sfx.unloop(_leader, &"jet_loop")


func is_crashed() -> bool:
	return _crashed


## Il capo e i gregari, per chi li cerca (i test, la lingua).
func leader() -> AnimatableBody3D:
	return _leader


func wingmen_planes() -> Array[AnimatableBody3D]:
	return _wingmen


func _explode(plane: AnimatableBody3D) -> void:
	var at := plane.global_position
	Heat.on_wreck(plane)
	Sfx.play_at(&"car_explode", at, -2.0)
	var patch := FirePatch.new()
	get_parent().add_child(patch)
	patch.global_position = Vector3(at.x, 0.0, at.z)
	if _frog and _frog.global_position.distance_to(at) < CRASH_RADIUS:
		var away := _frog.global_position - at
		away.y = 0.0
		_frog.take_hit(CRASH_DAMAGE, away.normalized() * 10.0 + Vector3.UP * 7.0)
	plane.queue_free()


func _ground_below(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN * 3.0, 1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _record(at: Transform3D) -> void:
	_ghost.append(at)
	# L'ombra della scia, sul banco di nubi, sotto la strada dei gregari.
	_shadow.position = Vector3(at.origin.x, 0.04, at.origin.z)


func _place_all() -> void:
	_leader.transform = _sample(0.0).translated(Vector3.UP * LIFT)
	_record(_sample(0.0))
	for i in _wingmen.size():
		_wingmen[i].transform = _sample(-_delays[i] * speed / Engine.physics_ticks_per_second)


# --- Il percorso --------------------------------------------------------------

## Entra da un lato e esce dall'altro, ondeggiando lungo Z dentro il blocco;
## forse uno o due giri della morte. Lo scarabocchio aggiunge zig-zag fitti.
func _build_path() -> void:
	var amp := randf_range(0.5, 0.95) * (half_depth - 2.5)
	var waves := randf_range(0.8, 2.0)
	var phase := randf() * TAU
	var loops: Array[float] = []
	if randf() < loop_chance:
		if randf() < double_loop_chance:
			loops.assign([randf_range(-22.0, -8.0) * direction, randf_range(8.0, 22.0) * direction])
		else:
			loops.append(randf_range(-18.0, 18.0))
	var x := -direction * half_length
	while (x - direction * half_length) * direction < 0.0:
		var z := amp * sin(waves * PI * x / half_length + phase)
		var y := CRUISE_Y
		if scribble:
			z += 2.6 * sin(x * 0.9 + phase) + 1.2 * sin(x * 2.3)
			y += 0.7 * absf(sin(x * 0.6 + phase))
		z = clampf(z, -half_depth + 1.5, half_depth - 1.5)
		_points.append(Vector3(x, y, z))
		_ups.append(Vector3.UP)
		if not loops.is_empty() and (x - loops[0]) * direction >= 0.0:
			_add_loop(Vector3(x, y, z))
			loops.remove_at(0)
		x += direction * SAMPLE


## Il giro della morte: un cerchio verticale nel piano del volo, che torna
## al punto di partenza. In cima si passa sotto.
func _add_loop(start: Vector3) -> void:
	var center := start + Vector3.UP * LOOP_RADIUS
	var count := ceili(TAU * LOOP_RADIUS / SAMPLE)
	for i in range(1, count):
		var angle := TAU * i / count
		var point := start + Vector3(direction * LOOP_RADIUS * sin(angle), LOOP_RADIUS * (1.0 - cos(angle)), 0.0)
		_points.append(point)
		_ups.append((center - point).normalized())


func _length() -> float:
	return (_points.size() - 1) * SAMPLE


## Il punto a s metri dall'inizio, orientato lungo la strada. Prima
## dell'inizio e dopo la fine, la strada continua dritta.
func _sample(s: float) -> Transform3D:
	var last := _points.size() - 1
	var f := s / SAMPLE
	var i := clampi(floori(f), 0, last - 1)
	var t := f - i
	var a := _points[i]
	var b := _points[i + 1]
	var tangent := (b - a).normalized()
	var origin := a.lerp(b, t)
	if f < 0.0:
		origin = _points[0] + tangent * s
	elif f > last:
		origin = _points[last] + tangent * (s - _length())
	var up := _ups[i].lerp(_ups[i + 1], clampf(t, 0.0, 1.0)).normalized()
	if absf(tangent.dot(up)) > 0.99:
		up = Vector3.UP if absf(tangent.y) < 0.9 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(tangent, up), origin)


# --- I pezzi ------------------------------------------------------------------

func _make_plane(is_leader: bool) -> AnimatableBody3D:
	var plane := AnimatableBody3D.new()
	plane.sync_to_physics = true
	plane.collision_layer = 8 if not is_leader else 0 # sui gregari si sale
	plane.collision_mask = 0
	var model: Node3D = MODEL.instantiate()
	plane.add_child(model)
	Style.apply_palette(model, {"stunt_stripe": "gold"} if is_leader else {})
	if not is_leader:
		_solid(plane, Vector3(1.0, 0.9, 6.0), Vector3.ZERO)
		_solid(plane, Vector3(5.6, 0.2, 1.6), Vector3(0.0, -0.2, 0.2))
		# La zona che travolge: più bassa del dorso, chi è sopra non si fa male.
		var hazard := Area3D.new()
		hazard.name = "Hazard"
		hazard.collision_layer = 0
		hazard.collision_mask = 2 # rana
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.8, 0.75, 6.6)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = -0.1
		hazard.add_child(collision)
		plane.add_child(hazard)
	else:
		# Il capo non fa male: chi gli finisce addosso lo abbatte.
		var touch := Area3D.new()
		touch.collision_layer = 0
		touch.collision_mask = 2
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.6, 1.2, 6.0)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		touch.add_child(collision)
		touch.body_entered.connect(_on_leader_touched)
		plane.add_child(touch)
	add_child(plane)
	return plane


func _solid(plane: AnimatableBody3D, size: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	plane.add_child(collision)


## La scia di fumo colorato del capo, che resta nel cielo finché sono passati
## i gregari; on_ground: la sua ombra sul banco di nubi, piatta.
func _trail(lifetime: float, on_ground: bool) -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	var mesh: PrimitiveMesh
	if on_ground:
		var mark := BoxMesh.new()
		mark.size = Vector3(1.4, 0.02, 1.4)
		mesh = mark
	else:
		var puff := SphereMesh.new()
		puff.radius = 0.6
		puff.height = 1.2
		puff.radial_segments = 6
		puff.rings = 3
		mesh = puff
	# L'ombra sul banco ha un tono più scuro: la scia bianca sul bianco non
	# si leggerebbe.
	mesh.material = Style.material(_trail_key + "_mark" if on_ground else _trail_key)
	trail.mesh = mesh
	trail.amount = roundi(lifetime * 45.0)
	trail.lifetime = lifetime
	trail.local_coords = false
	trail.direction = Vector3.UP
	trail.spread = 0.0
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.0
	Style.fade_smoke(trail)
	if on_ground:
		trail.scale_amount_curve = null
	trail.position = Vector3(0.0, 0.0, 3.0) if not on_ground else Vector3.ZERO
	return trail
