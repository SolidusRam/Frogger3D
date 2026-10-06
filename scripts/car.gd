class_name Car
extends RigidBody3D
## Un veicolo del modello ibrido.
## DRIVING: RigidBody3D bloccato in modalità cinematica; guida lungo la corsia e
## frena se vede un altro veicolo davanti.
## WRECK: rottame fisico, libero. Se urta forte un veicolo che guida lo
## trasforma a sua volta in rottame: da questa sola regola nascono le catene.

signal wrecked(car: Car)

enum State { DRIVING, WRECK }

## Rottami presenti al massimo nello stesso momento: oltre, il più vecchio
## sprofonda subito. Tiene la fisica sotto controllo anche al calore massimo.
const MAX_WRECKS := 80
## Distanza dal muso sotto cui due veicoli sono a contatto.
const CONTACT_DISTANCE := 0.3
## Secondi di fumo di un rottame: per tutto quel tempo fa anche da corrente
## calda per il deltaplano. Il Napalm (fusione) lo allunga.
const SMOKE_SECONDS := 6.0
static var smoke_seconds := SMOKE_SECONDS

## Raggio, spinta (velocità data ai veicoli vicini) e danno alla rana
## dell'esplosione dei guantoni esplosivi.
const EXPLOSION_RADIUS := 6.0
## Il raggio vero dell'esplosione, e i miglioramenti speciali dei guantoni
## esplosivi (vedi Upgrades): la reazione a catena (le auto distrutte da
## un'esplosione esplodono a loro volta, fino a CHAIN_DEPTH passaggi) e il
## razzo (l'esplosione non ferisce la rana: la lancia in alto).
static var explosion_radius := EXPLOSION_RADIUS
static var chain_explosions := false
static var explosion_rocket := false
## Il montante migliorato: l'auto lanciata ricade con un'onda (meteora).
static var meteor_radius := 4.0
const CHAIN_DEPTH := 3
const CHAIN_FUSE := 0.35
const EXPLOSION_PUSH := 12.0
const EXPLOSION_FROG_RADIUS := 4.5
const EXPLOSION_FROG_DAMAGE := 30
## Lo sguardo in avanti (la ShapeCast che fa frenare) costa: con 150-200
## veicoli vivi era un quarto del tempo di CPU. Chi ha strada libera guarda
## una volta ogni LOOK_INTERVAL passi; chi ha qualcosa entro LOOK_NEAR metri,
## a ogni passo (lì servono frenata e urti precisi).
const LOOK_INTERVAL := 4
const LOOK_NEAR := 12.0
## Se non urta niente, esplode comunque dopo questi secondi.
const EXPLOSION_FUSE := 1.2
## Prima di questo tempo un urto non la fa esplodere: l'auto deve allontanarsi
## dalla rana, altrimenti nel traffico fitto esploderebbe in faccia a lei.
const EXPLOSION_ARMING := 0.25

## I tipi di veicolo: ingombro di gioco (larghezza, altezza, lunghezza),
## danno alla rana, frequenza relativa nel traffico, raggio delle ruote,
## modello di Blender e collisione su misura (scatole: dimensione e centro),
## così si può stare sul cofano e la cabina del camion è più bassa del
## rimorchio. Il muso guarda verso -Z locale.
const TYPES := {
	"compact": {
		"size": Vector3(1.8, 1.35, 3.4), "damage": 20, "weight": 3, "wheel_radius": 0.3,
		"model": preload("res://assets/models/compact.glb"),
		"collision": [[Vector3(1.8, 0.69, 3.4), Vector3(0.0, -0.33, 0.0)], [Vector3(1.64, 0.66, 2.05), Vector3(0.0, 0.345, 0.275)]],
	},
	"sedan": {
		"size": Vector3(2.0, 1.4, 4.4), "damage": 25, "weight": 4, "wheel_radius": 0.33,
		"model": preload("res://assets/models/sedan.glb"),
		"collision": [[Vector3(2.0, 0.69, 4.4), Vector3(0.0, -0.355, 0.0)], [Vector3(1.84, 0.71, 2.2), Vector3(0.0, 0.345, 0.15)]],
	},
	"van": {
		"size": Vector3(2.1, 2.0, 4.8), "damage": 30, "weight": 2, "wheel_radius": 0.38,
		"model": preload("res://assets/models/van.glb"),
		"collision": [[Vector3(2.1, 2.0, 4.8), Vector3.ZERO]],
	},
	"truck": {
		"size": Vector3(2.4, 2.6, 8.0), "damage": 40, "weight": 2, "wheel_radius": 0.48,
		"model": preload("res://assets/models/truck.glb"),
		"collision": [[Vector3(2.4, 2.3, 2.4), Vector3(0.0, -0.15, -2.8)], [Vector3(2.4, 2.6, 5.4), Vector3(0.0, 0.0, 1.3)]],
	},
}

static var _wrecks: Array[Car] = []

## Il tono del motore per tipo: la utilitaria ronza, il camion brontola.
const ENGINE_PITCH := {"compact": 1.3, "sedan": 1.0, "van": 0.85, "truck": 0.62}
## Sotto questa velocità d'urto un rottame che sbatte non fa rumore.
const BUMP_SOUND_SPEED := 3.0
## Il pugno suona da sé (la lamiera è dentro il colpo): l'auto colpita non
## aggiunge il suo schianto.
var _quiet_wreck := false
var _bump_wait := 0.0


## I rottami che fumano ancora: le correnti calde del deltaplano.
static func smoking_wrecks() -> Array[Car]:
	var smoking: Array[Car] = []
	for car in _wrecks:
		if car._wreck_age < smoke_seconds:
			smoking.append(car)
	return smoking


## Sceglie un tipo a caso secondo le frequenze del traffico.
static func random_type() -> String:
	var total := 0
	for type in TYPES:
		total += TYPES[type].weight
	var pick := randi() % total
	for type in TYPES:
		pick -= TYPES[type].weight
		if pick < 0:
			return type
	return "sedan"


## Tipo di veicolo (una voce di TYPES), da scegliere prima di aggiungerlo.
var model_type := "sedan"
## Larghezza, altezza e lunghezza, prese dal tipo.
var size := Vector3(2.0, 1.4, 4.4)
## Direzione di marcia nel mondo e velocità di crociera, impostate dalla corsia.
var drive_direction := Vector3.RIGHT
var cruise_speed := 8.0
var state := State.DRIVING

## Frenata e accelerazione in m/s². Con meno frenata ci sono più incidenti.
var braking := 12.0
var acceleration := 6.0
## Distanza a cui si ferma dietro un ostacolo.
var safe_gap := 2.0

## Danno inflitto alla rana e velocità con cui viene sbalzata.
var hit_damage := 25
var knockback_speed := 12.0
## Sotto questa velocità il veicolo non fa danno.
var min_harmful_speed := 2.0
## Velocità relativa oltre la quale un urto trasforma un veicolo in rottame.
var crash_speed := 4.0
## Secondi dopo i quali un rottame sprofonda e sparisce.
var wreck_lifetime := 25.0

var _speed := 0.0
var _hitbox: Area3D
var _look_ahead: ShapeCast3D
## Passi di fisica che mancano al prossimo sguardo in avanti.
var _look_wait := 0
## Superfici verniciate del modello, per annerirle quando diventa rottame.
var _painted := []
var _wheels: Array[Node] = []
## Carrozzeria disegnata: si inclina e sobbalza senza toccare il corpo fisico.
var _visual: Node3D
var _frog: Frog
var _previous_speed := 0.0
var _pitch := 0.0
var _wobble_phase := randf() * TAU
var _hop_offset := 0.0
var _scare_cooldown := 0.0
var _color_index := 0
## Tempo in cui il rottame appena colpito dalla rana non può ferirla.
var _frog_grace := 0.0
var _wreck_age := 0.0
var _last_floating_frame := -10
## Colpito dai guantoni esplosivi: esploderà al primo urto con un veicolo.
var _armed := false
## Reazione a catena: a che passaggio è questa auto, e fra quanto esplode.
var _chain_depth := 0
var _chain_fuse := -1.0
## Vero dopo che l'auto è esplosa.
var exploded := false
## Tira e molla: per quanto ancora l'auto viene tirata verso chi l'ha presa,
## e il colpo con cui poi viene scagliata.
var _yank_left := -1.0
var _yank_target: Node3D
var _yank_blow := Vector3.ZERO


func _ready() -> void:
	add_to_group("cars")
	size = TYPES[model_type].size
	hit_damage = TYPES[model_type].damage
	collision_layer = 4 # veicoli
	collision_mask = 1 | 4 | 8 # terreno, veicoli, piattaforme
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	continuous_cd = true
	mass = 300.0 * size.x * size.z
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	physics_material_override.bounce = 0.1
	_speed = cruise_speed
	_build_collision()
	_build_visual()
	_build_hitbox()
	_build_look_ahead()
	Sfx.loop(self, &"car_engine", 0.0, ENGINE_PITCH[model_type])


func _physics_process(delta: float) -> void:
	match state:
		State.DRIVING:
			_drive(delta)
			if state == State.DRIVING:
				_animate_driving(delta)
		State.WRECK:
			_frog_grace = maxf(_frog_grace - delta, 0.0)
			_bump_wait -= delta
			_wreck_age += delta
			if _armed and _wreck_age > EXPLOSION_FUSE:
				explode()
			if _yank_left > 0.0:
				_pull_toward_yanker(delta)
			if _chain_fuse > 0.0:
				_chain_fuse -= delta
				if _chain_fuse <= 0.0:
					explode()
			if _wreck_age > wreck_lifetime or global_position.y < -10.0:
				_sink_and_free()
	_hit_overlapping_frogs()


## Velocità reale del veicolo, sia che guidi sia che sia un rottame.
func motion_velocity() -> Vector3:
	return drive_direction * _speed if state == State.DRIVING else linear_velocity


func become_wreck() -> void:
	if state == State.WRECK:
		return
	state = State.WRECK
	var velocity_before := motion_velocity()
	_look_ahead.enabled = false
	freeze = false
	linear_velocity = velocity_before
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_wreck_body_entered)
	for surface in _painted:
		(surface[0] as MeshInstance3D).set_surface_override_material(surface[1], Style.material("wreck_%d" % _color_index))
	_visual.rotation = Vector3.ZERO
	_visual.position = Vector3.ZERO
	Sfx.unloop(self, &"car_engine")
	if has_meta("burnt"):
		Sfx.play_at(&"fire_ignite", global_position)
	elif not _quiet_wreck:
		Sfx.play_at(&"car_crash", global_position, 0.0, 1.0 / sqrt(ENGINE_PITCH[model_type]), 1.5)
	_emit_sparks()
	_emit_smoke()
	_wrecks.append(self)
	tree_exiting.connect(_wrecks.erase.bind(self))
	if _wrecks.size() > MAX_WRECKS:
		_wrecks.pop_front()._sink_and_free()
	Heat.on_wreck(self)
	wrecked.emit(self)


## Con il calore alto il veicolo può perdere il controllo da solo: diventa un
## rottame e sbanda di lato, e da lì partono le catene.
func lose_control() -> void:
	Sfx.play_at(&"car_skid", global_position, 0.0, 1.0, 1.5)
	become_wreck()
	var side := drive_direction.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	apply_central_impulse(side * mass * randf_range(3.0, 6.0))
	apply_torque_impulse(Vector3.UP * mass * randf_range(-4.0, 4.0))


## Il pugno della rana: il veicolo diventa un rottame e vola via.
func receive_punch(impulse: Vector3, explosive := false) -> void:
	# Per l'impresa "Boomerang": quest'auto l'ha colpita la rana.
	set_meta("punched", true)
	_quiet_wreck = true
	become_wreck()
	_frog_grace = 0.5
	_armed = explosive
	# Colpito un po' sopra il centro, così oltre a volare gira su se stesso.
	apply_impulse(impulse, Vector3.UP * size.y * 0.3)


## L'esplosione dei guantoni esplosivi: i veicoli vicini diventano rottami e
## vengono scagliati via; la rana, se è troppo vicina, si fa male.
func explode() -> void:
	exploded = true
	_armed = false
	_chain_fuse = -1.0
	var center := global_position
	var wrecked := 0
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), center)
	query.collision_mask = 4 # veicoli
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var other := result.collider as Car
		if other == null or other == self:
			continue
		if other.state == State.DRIVING:
			wrecked += 1
			if chain_explosions and _chain_depth < CHAIN_DEPTH:
				other._chain_depth = _chain_depth + 1
				other._chain_fuse = CHAIN_FUSE
		other.become_wreck()
		var away := other.global_position - center
		# Al bordo del raggio arriva ancora metà della spinta.
		var strength := 1.0 - 0.5 * clampf(away.length() / explosion_radius, 0.0, 1.0)
		var direction := (Vector3(away.x, 0.0, away.z).normalized() + Vector3.UP * 0.8).normalized()
		other.apply_central_impulse(direction * other.mass * EXPLOSION_PUSH * strength)
	apply_central_impulse(Vector3.UP * mass * 5.0)
	if _frog and not _frog.is_dead:
		var to_frog := _frog.global_position - center
		if to_frog.length() < EXPLOSION_FROG_RADIUS:
			var away := Vector3(to_frog.x, 0.0, to_frog.z).normalized()
			if explosion_rocket:
				# Il razzo: niente danno, un lancio in alto.
				_frog.launch(away * 6.0 + Vector3.UP * 14.0)
			else:
				_frog.take_hit(EXPLOSION_FROG_DAMAGE, (away + Vector3.UP).normalized() * 12.0)
		if to_frog.length() < 30.0:
			_frog.camera_rig.shake(0.4, 0.35)
	_emit_explosion()
	Sfx.play_at(&"car_explode", center, 0.0, 1.0, 2.0)
	Feats.note(&"explosion", wrecked)
	# Maestria dei guantoni esplosivi.
	Progress.trial_add("explosive_gloves", 0, wrecked)
	Progress.trial_best("explosive_gloves", 1, wrecked)


func _drive(delta: float) -> void:
	var target_speed := cruise_speed
	_look_wait -= 1
	if _look_wait <= 0:
		_look_ahead.force_shapecast_update()
		var near := _look_ahead.is_colliding() and _look_ahead.get_closest_collision_safe_fraction() * _look_ahead.target_position.length() < LOOK_NEAR
		_look_wait = 1 if near else LOOK_INTERVAL
	if _look_ahead.is_colliding():
		var distance := _look_ahead.get_closest_collision_safe_fraction() * _look_ahead.target_position.length()
		var ahead := _look_ahead.get_collider(0) as Car
		var ahead_speed := 0.0
		if ahead:
			ahead_speed = maxf(ahead.motion_velocity().dot(drive_direction), 0.0)
		if distance <= CONTACT_DISTANCE:
			# A contatto: due veicoli cinematici si attraverserebbero, quindi qui
			# si decide l'urto. Troppo veloce è un tamponamento, piano si accoda.
			if ahead and _speed - ahead_speed > crash_speed:
				ahead.become_wreck()
				become_wreck()
				return
			_speed = minf(_speed, ahead_speed)
			return
		# Velocità a cui ci si può ancora fermare dietro chi precede, se frena
		# come noi: tiene conto anche della sua velocità.
		var room := maxf(distance - safe_gap, 0.0)
		target_speed = minf(cruise_speed, sqrt(ahead_speed * ahead_speed + 2.0 * braking * room))
	var rate := braking if target_speed < _speed else acceleration
	_speed = move_toward(_speed, target_speed, rate * delta)
	global_position += drive_direction * _speed * delta


func _on_wreck_body_entered(body: Node) -> void:
	if _bump_wait <= 0.0 and linear_velocity.length() > BUMP_SOUND_SPEED:
		_bump_wait = 0.35
		Sfx.play_at(&"wreck_hit", global_position, linear_to_db(clampf(linear_velocity.length() / 12.0, 0.2, 1.0)))
	var other := body as Car
	if _armed and other and _wreck_age > EXPLOSION_ARMING:
		explode()
		return
	# Il montante migliorato: l'auto lanciata ricade con un'onda.
	if has_meta("meteor") and _wreck_age > 0.3 and (body is StaticBody3D or other):
		remove_meta("meteor")
		_meteor_wave()
	if other and other.state == State.DRIVING:
		if (linear_velocity - other.motion_velocity()).length() > crash_speed:
			other.become_wreck()
			if has_meta("thrown"):
				_thrown_hit(other)
			# Maestria del montante: un'auto lanciata ne ribalta un'altra.
			if has_meta("uppercut"):
				Progress.trial_add("uppercut", 1, 1)


## Per seconds secondi quest'auto non fa male alla rana (il rottame tenuto
## o appena scagliato dalla lingua-catapulta).
func spare_frog(seconds: float) -> void:
	_frog_grace = maxf(_frog_grace, seconds)


## Un rottame scagliato dalla lingua-catapulta ha colpito un'auto: conta i
## colpi (la prova dello strike) e, con lo strike, la prima volta rimbalza
## verso l'auto in marcia più vicina.
func _thrown_hit(other: Car) -> void:
	var hits: int = get_meta("thrown") + 1
	set_meta("thrown", hits)
	Progress.trial_best("catapult_tongue", 1, hits)
	if not has_meta("strike"):
		return
	remove_meta("strike")
	var best: Car = null
	for car: Car in get_tree().get_nodes_in_group("cars"):
		if car == other or car == self or car.state != State.DRIVING:
			continue
		var gap := car.global_position.distance_to(global_position)
		if gap < 15.0 and (best == null or gap < best.global_position.distance_to(global_position)):
			best = car
	if best:
		var toward := best.global_position - global_position
		linear_velocity = Vector3(toward.x, 0.0, toward.z).normalized() * maxf(linear_velocity.length(), 14.0) + Vector3.UP * 2.0


## Tira e molla (guantone a molla migliorato): l'auto, già rottame, viene
## tirata verso target per time secondi, poi scagliata col colpo blow.
func yank(target: Node3D, blow: Vector3, time: float) -> void:
	_yank_target = target
	_yank_blow = blow
	_yank_left = time


func _pull_toward_yanker(delta: float) -> void:
	_yank_left -= delta
	if is_instance_valid(_yank_target):
		var toward := _yank_target.global_position - global_position
		toward.y = 0.0
		linear_velocity = toward.normalized() * 10.0 + Vector3.UP * 1.0 if toward.length() > 2.5 else Vector3.ZERO
	if _yank_left <= 0.0:
		apply_impulse(_yank_blow, Vector3.UP * size.y * 0.3)


## La meteora: le auto vicine al punto di caduta diventano rottami e saltano.
func _meteor_wave() -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = meteor_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 4
	for result in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var other := result.collider as Car
		if other == null or other == self:
			continue
		other.become_wreck()
		var away := other.global_position - global_position
		other.linear_velocity = (Vector3(away.x, 0.0, away.z).normalized() + Vector3.UP * 1.5).normalized() * 8.0
	_emit_explosion()


## Fa male solo se è il veicolo ad andare addosso alla rana: deve muoversi
## verso di lei, e più in fretta di lei. Chi viaggia insieme al veicolo, sopra o
## accanto, non si fa male, e nemmeno chi sbatte contro un veicolo fermo.
## I rottami che galleggiano sono zattere e non fanno mai male.
func _hit_overlapping_frogs() -> void:
	if _frog_grace > 0.0 or is_floating():
		return
	var velocity := motion_velocity()
	for body in _hitbox.get_overlapping_bodies():
		var frog := body as Frog
		if frog == null:
			continue
		var toward_frog := (frog.global_position - global_position).normalized()
		var own_speed := velocity.dot(toward_frog)
		var closing_speed := (velocity - frog.velocity).dot(toward_frog)
		if own_speed >= min_harmful_speed and closing_speed >= min_harmful_speed:
			Feats.note(&"car_hit", 1.0 if has_meta("punched") else 0.0)
			frog.last_hit_by = self
			frog.take_hit(hit_damage, _knockback_for(frog, velocity))


## Chiamato dal fiume a ogni passo in cui il rottame è in acqua.
func mark_floating() -> void:
	_last_floating_frame = Engine.get_physics_frames()


func is_floating() -> bool:
	return Engine.get_physics_frames() - _last_floating_frame <= 1


## Sbalza la rana soprattutto di lato, fuori dalla corsia: se venisse spinta solo
## in avanti il veicolo la raggiungerebbe e la colpirebbe di nuovo.
func _knockback_for(frog: Node3D, velocity: Vector3) -> Vector3:
	var forward := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var side_sign := signf((frog.global_position - global_position).dot(side))
	if side_sign == 0.0:
		side_sign = 1.0 if randf() < 0.5 else -1.0
	var direction := (forward * 0.5 + side * side_sign).normalized()
	return direction * knockback_speed + Vector3.UP * 5.0


func _sink_and_free() -> void:
	_wrecks.erase(self)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	freeze = true
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - size.y * 1.5, 1.0)
	tween.tween_callback(queue_free)


func _build_collision() -> void:
	for part in TYPES[model_type].collision:
		var shape := BoxShape3D.new()
		shape.size = part[0]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = part[1]
		add_child(collision)


func _build_visual() -> void:
	_color_index = randi() % Style.CAR_COLORS
	_visual = Node3D.new()
	add_child(_visual)
	var model: Node3D = TYPES[model_type].model.instantiate()
	_visual.add_child(model)
	_painted = Style.apply_palette(model, {"paint": "car_%d" % _color_index})
	_wheels = model.find_children("Wheel_*", "", true, false)
	_frog = get_tree().get_first_node_in_group("frog") as Frog


## Sospensioni: il muso si abbassa in frenata e si alza in accelerazione; il
## motore fa tremare appena la carrozzeria. Se la rana passa davanti a
## un'auto in corsa, l'auto fa un sobbalzo di spavento.
func _animate_driving(delta: float) -> void:
	var acceleration_now := (_speed - _previous_speed) / delta
	_previous_speed = _speed
	var target_pitch := clampf(acceleration_now * 0.015, -0.12, 0.06)
	_pitch = lerpf(_pitch, target_pitch, 1.0 - exp(-10.0 * delta))
	_visual.rotation.x = _pitch

	Sfx.set_loop(self, &"car_engine", linear_to_db(0.4 + 0.6 * clampf(_speed / 14.0, 0.0, 1.0)), ENGINE_PITCH[model_type] * (0.75 + 0.5 * clampf(_speed / 16.0, 0.0, 1.0)))
	var spin: float = -_speed / TYPES[model_type].wheel_radius * delta
	for wheel: Node3D in _wheels:
		wheel.rotate_x(spin)

	var wobble := 0.0
	if _speed > 0.5:
		_wobble_phase += delta * (10.0 + _speed)
		wobble = 0.025 * sin(_wobble_phase)
	_visual.position.y = wobble + _hop_offset

	_scare_cooldown -= delta
	if _scare_cooldown <= 0.0 and _speed > 3.0 and _frog and not _frog.is_dead:
		var to_frog := _frog.global_position - global_position
		var ahead := to_frog.dot(drive_direction)
		var sideways := (to_frog - drive_direction * ahead - Vector3.UP * to_frog.y).length()
		if ahead > 0.0 and ahead < size.z / 2.0 + 6.0 and sideways < size.x:
			_scare_cooldown = 2.0
			Sfx.play_at(&"car_horn", global_position, 0.0, ENGINE_PITCH[model_type] * 0.4 + 0.6)
			var tween := create_tween()
			tween.tween_property(self, "_hop_offset", 0.45, 0.1).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "_hop_offset", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Scintille all'impatto, a raggiera.
func _emit_sparks(amount := 20) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = amount
	sparks.lifetime = 0.5
	sparks.explosiveness = 1.0
	sparks.local_coords = false
	sparks.direction = Vector3.UP
	sparks.spread = 75.0
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 9.0
	sparks.gravity = Vector3(0.0, -15.0, 0.0)
	sparks.mesh = _box_mesh(Vector3.ONE * 0.12, Style.material("spark"))
	add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)


## Una palla di fuoco low-poly che si gonfia e sparisce, con molte scintille.
func _emit_explosion() -> void:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	mesh.material = Style.material("spark")
	ball.mesh = mesh
	get_parent().add_child(ball)
	ball.global_position = global_position
	ball.scale = Vector3.ONE * 0.5
	var tween := ball.create_tween()
	tween.tween_property(ball, "scale", Vector3.ONE * explosion_radius * 0.7, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(ball.queue_free)
	_emit_sparks(60)


## Fumo dal rottame per qualche secondo: sbuffi low-poly che salgono,
## crescono e svaniscono. Le particelle restano nel mondo mentre il rottame vola.
func _emit_smoke() -> void:
	var smoke := CPUParticles3D.new()
	smoke.amount = 10
	smoke.lifetime = 1.8
	smoke.local_coords = false
	smoke.direction = Vector3.UP
	smoke.spread = 20.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 2.5
	smoke.gravity = Vector3(0.0, 0.5, 0.0)
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 1.6
	Style.fade_smoke(smoke)
	var puff := SphereMesh.new()
	puff.radius = 0.35
	puff.height = 0.7
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = Style.material("smoke")
	smoke.mesh = puff
	smoke.position.y = size.y / 2.0
	add_child(smoke)
	smoke.emitting = true
	# Collegato al metodo del fumo, non a una lambda che lo cattura: se il
	# rottame sparisce prima, Godot scollega da solo il segnale.
	get_tree().create_timer(smoke_seconds).timeout.connect(smoke.set_emitting.bind(false))


## Area che rileva la rana ai lati e davanti, ma non sul tetto: stare sopra un
## veicolo non fa danno.
func _build_hitbox() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x + 0.3, size.y - 0.3, size.z + 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.15
	_hitbox = Area3D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2 # rana
	_hitbox.add_child(collision)
	add_child(_hitbox)


## Sensore davanti al muso, lungo quanto serve per fermarsi da velocità di
## crociera. Vede solo i veicoli: per la rana non si frena.
func _build_look_ahead() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x * 0.8, size.y * 0.5, 0.5)
	_look_ahead = ShapeCast3D.new()
	_look_ahead.shape = shape
	_look_ahead.collision_mask = 4 # veicoli
	_look_ahead.position = Vector3(0.0, 0.0, -size.z / 2.0 - 0.3)
	var length := cruise_speed * cruise_speed / (2.0 * braking) + safe_gap + 1.0
	_look_ahead.target_position = Vector3(0.0, 0.0, -length)
	# Si aggiorna a mano, in _drive; i veicoli sono sfalsati fra loro.
	_look_ahead.enabled = false
	_look_wait = get_instance_id() % LOOK_INTERVAL
	add_child(_look_ahead)


static func _box_mesh(box_size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	return mesh
