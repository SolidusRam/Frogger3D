class_name PunchPower
extends Node
## Il pugno: colpisce i veicoli davanti alla rana, nella direzione in cui
## guarda la telecamera, e li trasforma in rottami; i bagagli volano via. L'attrezzo sono i guantoni,
## che scattano in avanti alternandosi. I potenziamenti cambiano questi valori.

## Distanza e raggio della zona colpita davanti alla rana.
@export var reach := 1.3
@export var radius := 1.2
## Spinta in N·s: un'auto (2400 kg) parte a circa 12 m/s, un camion (5760 kg)
## a circa 5.
@export var impulse := 30000.0
## Quanto il pugno solleva il veicolo, rispetto alla spinta orizzontale.
@export var lift := 0.35
@export var cooldown := 0.4

var cooldown_left := 0.0
## Guantoni esplosivi: l'auto colpita esplode al primo urto con un veicolo.
var explosive := false
## Montante: il pugno solleva le auto molto di più (volano e ricadono).
var uppercut := false
## Guantone a molla: il pugno arriva lontano.
var long_reach := false
@export var uppercut_lift := 1.2
@export var long_reach_distance := 4.0

var _frog: Frog
var _gloves: Array[Node3D] = []
var _next_glove := 0
var _query := PhysicsShapeQueryParameters3D.new()


func setup(frog: Frog) -> void:
	_frog = frog
	_query.shape = SphereShape3D.new()
	_query.collision_mask = 4 # veicoli
	for side in [-1.0, 1.0]:
		var glove := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.28
		mesh.height = 0.5
		mesh.material = Style.material("glove")
		glove.mesh = mesh
		glove.position = Vector3(side * 0.55, 0.38, -0.3)
		glove.set_meta("rest", glove.position)
		frog.visual.add_child(glove)
		_gloves.append(glove)


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func is_ready() -> bool:
	return cooldown_left == 0.0


func use() -> void:
	cooldown_left = cooldown
	var forward := -_frog.camera_rig.flat_basis().z
	_frog.visual.rotation.y = atan2(-forward.x, -forward.z)
	_frog.squash(Vector3(0.9, 0.9, 1.2), 0.15)
	_throw_glove()

	var hit_reach := long_reach_distance if long_reach else reach
	var hit_lift := uppercut_lift if uppercut else lift
	(_query.shape as SphereShape3D).radius = radius * (1.25 if long_reach else 1.0)
	_query.transform = Transform3D(Basis(), _frog.global_position + Vector3.UP * 0.6 + forward * hit_reach)
	var hits: Array[Car] = []
	for result in _frog.get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var car := result.collider as Car
		if car and not hits.has(car):
			hits.append(car)
			car.receive_punch((forward + Vector3.UP * hit_lift) * impulse, explosive)
		elif result.collider is Baggage:
			result.collider.receive_punch((forward + Vector3.UP * hit_lift) * impulse)
	_frog.power_used.emit(&"punch")
	if not hits.is_empty():
		_frog.punched.emit(hits)


## Equipaggia o toglie i guantoni esplosivi; si vede: diventano arancioni.
func set_explosive(on: bool) -> void:
	explosive = on
	_refresh_gloves()


## Montante: si vede, i guantoni diventano gialli.
func set_uppercut(on: bool) -> void:
	uppercut = on
	_refresh_gloves()


## Guantone a molla: si vede, i guantoni diventano blu e più grossi.
func set_long_reach(on: bool) -> void:
	long_reach = on
	_refresh_gloves()


func _refresh_gloves() -> void:
	var key := ""
	if explosive:
		key = "glove_hot"
	elif uppercut:
		key = "glove_up"
	elif long_reach:
		key = "glove_long"
	for glove: MeshInstance3D in _gloves:
		glove.material_override = Style.material(key) if key != "" else null
		glove.scale = Vector3.ONE * (1.35 if long_reach else 1.0)


## Un guantone scatta in avanti e torna; destro e sinistro si alternano. Va in
## tempo reale: il fermo-immagine lo congela già disteso sull'auto.
func _throw_glove() -> void:
	var glove := _gloves[_next_glove]
	_next_glove = (_next_glove + 1) % _gloves.size()
	var rest: Vector3 = glove.get_meta("rest")
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(glove, "position", rest + Vector3(-signf(rest.x) * 0.3, 0.15, -1.5), 0.05)
	tween.parallel().tween_property(glove, "scale", Vector3.ONE * 1.8, 0.05)
	tween.tween_property(glove, "position", rest, 0.18).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(glove, "scale", Vector3.ONE, 0.18)
