class_name Wildfire
extends Node3D
## L'incendio che insegue la rana: è partito nella sua foresta, ed è il motivo
## per cui lei corre. Un muro di fuoco su tutta la larghezza avanza verso -Z,
## dietro la rana. Il caos lo alimenta: più sale il calore, più corre; e
## accelera col tempo, minuto dopo minuto, finché corre più della rana. Non
## resta mai più indietro di max_gap; raggiunta una tana viene respinto lì
## (ma non rallenta: la velocità raggiunta resta).
## Sui fiumi e sull'acqua del porto rallenta. Chi ci finisce dentro brucia;
## le auto che raggiunge diventano rottami (che non scaldano).
## La telecamera guarda avanti, quindi lo si sente in tre modi: il bagliore
## arancione sulla strada davanti, il fumo che passa sopra la rana e, nell'HUD,
## la distanza col bordo dello schermo che si arrossa.
## Nel cielo (vedi Worlds) è un temporale: un muro di nubi nere coi fulmini e
## la pioggia, con le stesse regole (set_world).

const WIDTH := 140.0
const FLAMES := 70

@export var frog: Frog
@export var course: Course
@export var hud: Hud
## Velocità a calore zero e al massimo, in m/s, all'inizio della run.
@export var min_speed := 1.2
@export var max_speed := 4.0
## Quanto accelera: m/s in più per ogni minuto di inseguimento. Al 15° minuto
## corre come la rana che cammina (7 m/s).
@export var acceleration_per_minute := 0.2
## Più di così non corre.
@export var top_speed := 7.5
## Sull'acqua corre questa frazione della velocità.
@export var water_factor := 0.6
## Mai più indietro di così; è anche la distanza a cui lo respinge una tana.
@export var max_gap := 40.0
## A calore pieno il caos non costa più calore: nutre l'inseguitore. Ogni
## rottame vicino alla rana lo avvicina di tanti metri.
@export var fed_per_wreck := 0.8
## Vita tolta al secondo a chi è nel fuoco.
@export var burn := 80.0
## Sotto questa distanza il bordo dello schermo si arrossa.
@export var danger_distance := 25.0

## Quota del fronte del fuoco: la rana sta a quote più basse.
var front_z := 0.0
## Modalità prova: l'incendio si ferma.
var stopped := false
## Le prime run: l'incendio aspetta che la rana si muova (vedi Hints).
var waiting := false
## Secondi di inseguimento (fermo non conta): fanno accelerare il fuoco.
var elapsed := 0.0
## Ogni mondo passato l'inseguitore corre di più (vedi Worlds.chaser_factor).
var world_factor := 1.0

var _flames: MultiMesh
var _heights := PackedFloat32Array()
var _lights: Array[OmniLight3D] = []
var _front_smoke: CPUParticles3D
var _frog_smoke: CPUParticles3D
var _reach: Area3D
## Un generatore tutto suo per il tremolio delle fiamme: la grafica non deve
## cambiare la sequenza casuale del gioco (percorso, traffico).
var _rng := RandomNumberGenerator.new()
## Da dove si sente il fuoco: sul fronte, proprio dietro la rana. Il
## crepitio c'è sempre; il ruggito cresce quando il fuoco si avvicina.
var _voice: Node3D
## Il temporale del cielo, e quello che cambia con lui: l'aspetto (in _look),
## i suoni e i fulmini.
var sky := false
var _look: Node3D
var _loop_sound := &"fire_loop"
var _roar_sound := &"fire_roar"
var _bolt_wait := 0.0
var _flash: OmniLight3D


func _ready() -> void:
	add_to_group("wildfire")
	front_z = frog.global_position.z + max_gap
	course.den_reached.connect(_on_den_reached)
	Heat.wreck_created.connect(_on_wreck_created)
	_build()
	_voice = Node3D.new()
	add_child(_voice)
	_start_sounds()


func _start_sounds() -> void:
	Sfx.loop(_voice, _loop_sound, 0.0, 1.0, 2.5)
	Sfx.loop(_voice, _roar_sound, -60.0, 1.0, 2.5)


## Il fuoco della terra o il temporale del cielo: rifà l'aspetto e i suoni.
func set_world(in_sky: bool) -> void:
	if in_sky == sky:
		return
	sky = in_sky
	Sfx.unloop(_voice, _loop_sound)
	Sfx.unloop(_voice, _roar_sound)
	_loop_sound = &"storm_loop" if sky else &"fire_loop"
	_roar_sound = &"storm_roar" if sky else &"fire_roar"
	_start_sounds()
	_look.queue_free()
	_lights.clear()
	_build_look()
	if hud:
		hud.set_chaser_icon("storm" if sky else "fire")


func _physics_process(delta: float) -> void:
	if not stopped and not waiting:
		elapsed += delta
		var speed := speed()
		var kind := course.kind_at(front_z)
		if kind == Course.Kind.RIVER or kind == Course.Kind.PORT:
			speed *= water_factor
		front_z -= speed * delta
	# Non resta mai troppo indietro: la pressione c'è sempre.
	front_z = minf(front_z, frog.global_position.z + max_gap)
	# La rana molto dietro il fronte non ci è arrivata correndo (in 8 m di fuoco
	# sarebbe già bruciata): è ricomparsa, per esempio dopo una caduta. Il
	# fuoco ricomincia da max_gap.
	if frog.global_position.z > front_z + 8.0:
		front_z = frog.global_position.z + max_gap
	position.z = front_z
	if frog.global_position.z > front_z - 1.0:
		Feats.note(&"fire_burn")
		frog.burn(burn, delta)
	for body in _reach.get_overlapping_bodies():
		var car := body as Car
		if car and car.state == Car.State.DRIVING:
			car.set_meta("burnt", true)
			car.become_wreck()


func _process(delta: float) -> void:
	var gap := distance()
	var closeness := clampf(1.0 - gap / max_gap, 0.0, 1.0)
	for light in _lights:
		light.light_energy = 0.5 + 3.5 * closeness
	# Sopra e davanti alla telecamera (che sta dietro la rana): il fumo passa
	# sopra la rana senza coprire la vista.
	_frog_smoke.global_position = frog.global_position + Vector3(0.0, 7.0, 2.0)
	_frog_smoke.emitting = gap < 35.0
	_voice.global_position = Vector3(frog.global_position.x, 2.0, front_z)
	var near := clampf(1.0 - (gap - 6.0) / (danger_distance - 6.0), 0.0, 1.0)
	Sfx.set_loop(_voice, _roar_sound, linear_to_db(maxf(near, 0.001)), 0.9 + 0.2 * near)
	for i in FLAMES:
		var x := -WIDTH / 2.0 + (i + 0.5) * WIDTH / FLAMES
		var height := _heights[i] * _rng.randf_range(0.85, 1.15)
		var basis := Basis.from_scale(Vector3(_rng.randf_range(0.9, 1.1), height, _rng.randf_range(0.9, 1.1)))
		_flames.set_instance_transform(i, Transform3D(basis, Vector3(x, height * 0.5, -0.5 + (i % 2) * 1.2)))
	if sky:
		_lightning(delta)
	if hud:
		hud.set_fire_distance(gap, clampf(1.0 - (gap - 3.0) / (danger_distance - 3.0), 0.0, 1.0))


## Velocità sulla terra, in m/s: il calore e i minuti di inseguimento.
func speed() -> float:
	var base := lerpf(min_speed, max_speed, Heat.ratio()) + acceleration_per_minute * elapsed / 60.0
	return minf(base * world_factor, top_speed * world_factor)


## Il teletrasporto lascia indietro l'incendio: nel mondo nuovo l'inseguitore
## riparte a max_gap, senza l'accelerazione accumulata, ma più veloce di
## quello di prima.
func new_world(worlds_passed: int) -> void:
	elapsed = 0.0
	world_factor = Worlds.chaser_factor(worlds_passed)
	front_z = frog.global_position.z + max_gap


## A calore pieno il caos nutre l'inseguitore (solo quello vicino alla rana,
## come per il calore; i rottami del fuoco no).
func _on_wreck_created(car: Node3D) -> void:
	if Heat.value < Heat.MAX or car.has_meta("burnt"):
		return
	if car.global_position.distance_to(frog.global_position) <= Heat.wreck_radius:
		front_z -= fed_per_wreck


## Metri fra la rana e il fronte del fuoco.
func distance() -> float:
	return front_z - frog.global_position.z


## Una tana è un rifugio: il fuoco viene respinto a max_gap.
func _on_den_reached(_count: int, _distance: float) -> void:
	front_z = frog.global_position.z + max_gap


func _build() -> void:
	for i in FLAMES:
		_heights.append(_rng.randf_range(2.5, 6.0))
	_build_look()
	# Il fumo che arriva da dietro e passa sopra la rana.
	_frog_smoke = _smoke(Vector3(8.0, 0.5, 0.5), 16, 2.5, 0.6)
	_frog_smoke.direction = Vector3(0.0, 0.1, -1.0)
	_frog_smoke.top_level = true
	add_child(_frog_smoke)

	# Le auto che il fuoco raggiunge.
	_reach = Area3D.new()
	_reach.collision_layer = 0
	_reach.collision_mask = 4 # veicoli
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, 6.0, 3.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 3.0
	_reach.add_child(collision)
	add_child(_reach)


## L'aspetto: le fiamme, la terra bruciata, il bagliore e il fumo; o, nel
## cielo, le nubi nere, la pioggia e il lampo dei fulmini.
func _build_look() -> void:
	_look = Node3D.new()
	add_child(_look)
	# Le fiamme: coni che tremolano, in due file sfalsate. Nel cielo, sbuffi
	# di nubi nere alti come le fiamme.
	var mesh: PrimitiveMesh
	if sky:
		var puff := SphereMesh.new()
		puff.radius = 2.2
		puff.height = 1.4
		puff.radial_segments = 7
		puff.rings = 3
		mesh = puff
	else:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.3
		cone.height = 1.0
		cone.radial_segments = 5
		cone.rings = 1
		mesh = cone
	mesh.material = Style.material("storm_cloud" if sky else "fire")
	_flames = MultiMesh.new()
	_flames.transform_format = MultiMesh.TRANSFORM_3D
	_flames.mesh = mesh
	_flames.instance_count = FLAMES
	var flames := MultiMeshInstance3D.new()
	flames.multimesh = _flames
	# Il tremolio si aggiorna a ogni fotogramma: niente interpolazione fisica
	# (altrimenti Godot avvisa a ogni aggiornamento).
	flames.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_look.add_child(flames)

	# Dietro il fuoco, la terra bruciata (nel cielo, le nubi fradice).
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(WIDTH * 3.0, 0.05, 200.0)
	plane.material = Style.material("storm_ground" if sky else "burnt")
	ground.mesh = plane
	ground.position = Vector3(0.0, 0.03, 100.5)
	_look.add_child(ground)

	# Il bagliore che illumina la strada davanti alla rana (nel cielo, una luce
	# fredda e livida).
	for x in [-30.0, 0.0, 30.0]:
		var light := OmniLight3D.new()
		light.light_color = Color(0.55, 0.65, 1.0) if sky else Color(1.0, 0.45, 0.1)
		light.omni_range = 45.0
		light.position = Vector3(x, 5.0, -2.0)
		_look.add_child(light)
		_lights.append(light)

	_front_smoke = _smoke(Vector3(WIDTH / 2.0, 1.0, 1.0), 70, 3.5, 0.9)
	_front_smoke.direction = Vector3(0.0, 1.0, -0.3)
	_look.add_child(_front_smoke)
	if not sky:
		return
	# La pioggia, che scende davanti al fronte.
	var rain := CPUParticles3D.new()
	var drop := BoxMesh.new()
	drop.size = Vector3(0.04, 0.7, 0.04)
	drop.material = Style.material("rain")
	rain.mesh = drop
	rain.amount = 400
	rain.lifetime = 0.8
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(WIDTH / 2.0, 0.5, 8.0)
	rain.direction = Vector3.DOWN
	rain.spread = 4.0
	rain.gravity = Vector3.ZERO
	rain.initial_velocity_min = 22.0
	rain.initial_velocity_max = 26.0
	rain.position = Vector3(0.0, 16.0, -6.0)
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_look.add_child(rain)
	# Il lampo dei fulmini: si accende un attimo a ogni colpo.
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.85, 0.9, 1.0)
	_flash.omni_range = 70.0
	_flash.light_energy = 0.0
	_look.add_child(_flash)


## I fulmini del temporale: ogni tanto uno cade sul fronte, con il lampo e il
## tuono. Solo da vedere e sentire: il pericolo è il fronte, come il fuoco.
func _lightning(delta: float) -> void:
	_flash.light_energy = maxf(_flash.light_energy - delta * 40.0, 0.0)
	_bolt_wait -= delta
	if _bolt_wait > 0.0:
		return
	_bolt_wait = _rng.randf_range(0.5, 1.8)
	var x := _rng.randf_range(-40.0, 40.0)
	var bolt := Node3D.new()
	var top := Vector3(x, 30.0, _rng.randf_range(-2.0, 2.0))
	for i in 5:
		var bottom := top + Vector3(_rng.randf_range(-3.0, 3.0), -6.0, _rng.randf_range(-1.0, 1.0))
		var piece := MeshInstance3D.new()
		var stick := BoxMesh.new()
		# Lungo Z, poi girato verso il pezzo successivo.
		stick.size = Vector3(0.35, 0.35, top.distance_to(bottom))
		stick.material = Style.material("lightning")
		piece.mesh = stick
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.transform = Transform3D(Basis.looking_at(bottom - top, Vector3.FORWARD), (top + bottom) / 2.0)
		bolt.add_child(piece)
		top = bottom
	_look.add_child(bolt)
	bolt.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_tree().create_timer(0.12).timeout.connect(bolt.queue_free)
	_flash.position = Vector3(x, 12.0, -4.0)
	_flash.light_energy = 6.0
	Sfx.play_at(&"thunder", to_global(Vector3(x, 10.0, 0.0)), 0.0, _rng.randf_range(0.85, 1.1), 4.0)


func _smoke(extents: Vector3, amount: int, lifetime: float, radius: float) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = radius
	puff.height = radius * 2.0
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = Style.material("fire_smoke")
	smoke.mesh = puff
	smoke.amount = amount
	smoke.lifetime = lifetime
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = extents
	smoke.spread = 20.0
	smoke.gravity = Vector3.ZERO
	smoke.initial_velocity_min = 3.0
	smoke.initial_velocity_max = 6.0
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.8
	Style.fade_smoke(smoke)
	return smoke
