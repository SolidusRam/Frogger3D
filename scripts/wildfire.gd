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
## Vita tolta al secondo a chi è nel fuoco.
@export var burn := 80.0
## Sotto questa distanza il bordo dello schermo si arrossa.
@export var danger_distance := 25.0

## Quota del fronte del fuoco: la rana sta a quote più basse.
var front_z := 0.0
## Modalità prova: l'incendio si ferma.
var stopped := false
## Secondi di inseguimento (fermo non conta): fanno accelerare il fuoco.
var elapsed := 0.0

var _flames: MultiMesh
var _heights := PackedFloat32Array()
var _lights: Array[OmniLight3D] = []
var _front_smoke: CPUParticles3D
var _frog_smoke: CPUParticles3D
var _reach: Area3D
## Un generatore tutto suo per il tremolio delle fiamme: la grafica non deve
## cambiare la sequenza casuale del gioco (percorso, traffico).
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("wildfire")
	front_z = frog.global_position.z + max_gap
	course.den_reached.connect(_on_den_reached)
	_build()


func _physics_process(delta: float) -> void:
	if not stopped:
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
		frog.burn(burn, delta)
	for body in _reach.get_overlapping_bodies():
		var car := body as Car
		if car and car.state == Car.State.DRIVING:
			car.set_meta("burnt", true)
			car.become_wreck()


func _process(_delta: float) -> void:
	var gap := distance()
	var closeness := clampf(1.0 - gap / max_gap, 0.0, 1.0)
	for light in _lights:
		light.light_energy = 0.5 + 3.5 * closeness
	# Sopra e davanti alla telecamera (che sta dietro la rana): il fumo passa
	# sopra la rana senza coprire la vista.
	_frog_smoke.global_position = frog.global_position + Vector3(0.0, 7.0, 2.0)
	_frog_smoke.emitting = gap < 35.0
	for i in FLAMES:
		var x := -WIDTH / 2.0 + (i + 0.5) * WIDTH / FLAMES
		var height := _heights[i] * _rng.randf_range(0.85, 1.15)
		var basis := Basis.from_scale(Vector3(_rng.randf_range(0.9, 1.1), height, _rng.randf_range(0.9, 1.1)))
		_flames.set_instance_transform(i, Transform3D(basis, Vector3(x, height * 0.5, -0.5 + (i % 2) * 1.2)))
	if hud:
		hud.set_fire_distance(gap, clampf(1.0 - (gap - 3.0) / (danger_distance - 3.0), 0.0, 1.0))


## Velocità sulla terra, in m/s: il calore e i minuti di inseguimento.
func speed() -> float:
	return minf(lerpf(min_speed, max_speed, Heat.ratio()) + acceleration_per_minute * elapsed / 60.0, top_speed)


## Metri fra la rana e il fronte del fuoco.
func distance() -> float:
	return front_z - frog.global_position.z


## Una tana è un rifugio: il fuoco viene respinto a max_gap.
func _on_den_reached(_count: int, _distance: float) -> void:
	front_z = frog.global_position.z + max_gap


func _build() -> void:
	# Le fiamme: coni che tremolano, in due file sfalsate.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.3
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	cone.material = Style.material("fire")
	_flames = MultiMesh.new()
	_flames.transform_format = MultiMesh.TRANSFORM_3D
	_flames.mesh = cone
	_flames.instance_count = FLAMES
	for i in FLAMES:
		_heights.append(_rng.randf_range(2.5, 6.0))
	var flames := MultiMeshInstance3D.new()
	flames.multimesh = _flames
	# Il tremolio si aggiorna a ogni fotogramma: niente interpolazione fisica
	# (altrimenti Godot avvisa a ogni aggiornamento).
	flames.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(flames)

	# Dietro il fuoco, la terra bruciata.
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(WIDTH * 3.0, 0.05, 200.0)
	plane.material = Style.material("burnt")
	ground.mesh = plane
	ground.position = Vector3(0.0, 0.03, 100.5)
	add_child(ground)

	# Il bagliore che illumina la strada davanti alla rana.
	for x in [-30.0, 0.0, 30.0]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.45, 0.1)
		light.omni_range = 45.0
		light.position = Vector3(x, 5.0, -2.0)
		add_child(light)
		_lights.append(light)

	_front_smoke = _smoke(Vector3(WIDTH / 2.0, 1.0, 1.0), 70, 3.5, 0.9)
	_front_smoke.direction = Vector3(0.0, 1.0, -0.3)
	add_child(_front_smoke)
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
