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
## La rana ha i guantoni (vedi Upgrades: gli attrezzi iniziali e le carte).
## Senza, niente pugno e niente guantoni sul modello.
var enabled := true:
	set(value):
		enabled = value
		for glove in _gloves:
			glove.visible = value
## Guantoni esplosivi: l'auto colpita esplode al primo urto con un veicolo.
var explosive := false
## Montante: il pugno solleva le auto molto di più (volano e ricadono).
var uppercut := false
## Guantone a molla: il pugno arriva lontano.
var long_reach := false
@export var uppercut_lift := 1.2
@export var long_reach_distance := 4.0
## Miglioramenti speciali (la maestria delle carte, vedi Upgrades): meteora
## e doppio montante; perforante e tira e molla.
var meteor := false
var double_uppercut := false
var piercing := false
var yank := false
## Il doppio montante colpisce anche così in alto; tira e molla: quanto tira
## l'auto e quanto più forte la scaglia.
@export var high_punch_height := 3.0
@export var yank_time := 0.25
@export var yank_boost := 1.5

var _frog: Frog
var _gloves: Array[Node3D] = []
var _next_glove := 0
var _query := PhysicsShapeQueryParameters3D.new()


func setup(frog: Frog) -> void:
	_frog = frog
	_query.shape = SphereShape3D.new()
	_query.collision_mask = 4 # veicoli
	# I guantoni sono nel modello della rana.
	for glove: Node3D in [frog.model.get_node("GloveL"), frog.model.get_node("GloveR")]:
		glove.set_meta("rest", glove.position)
		_gloves.append(glove)


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func is_ready() -> bool:
	return enabled and cooldown_left == 0.0


func use() -> void:
	cooldown_left = cooldown
	var forward := -_frog.camera_rig.flat_basis().z
	_frog.visual.rotation.y = atan2(-forward.x, -forward.z)
	_frog.squash(Vector3(0.9, 0.9, 1.2), 0.15)
	_throw_glove()

	var hit_reach := long_reach_distance if long_reach else reach
	var hit_lift := uppercut_lift if uppercut else lift
	var blow := (forward + Vector3.UP * hit_lift) * impulse
	var origin := _frog.global_position + Vector3.UP * 0.6
	var space := _frog.get_world_3d().direct_space_state
	var results: Array[Dictionary] = []
	if long_reach and piercing:
		# Perforante: tutta la linea fino alla portata.
		var line := BoxShape3D.new()
		line.size = Vector3(radius * 2.0, 2.0, hit_reach)
		var along := Basis.looking_at(forward, Vector3.UP)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = line
		query.collision_mask = 4
		query.transform = Transform3D(along, origin + forward * hit_reach / 2.0)
		results.append_array(space.intersect_shape(query, 16))
	else:
		(_query.shape as SphereShape3D).radius = radius * (1.25 if long_reach else 1.0)
		_query.transform = Transform3D(Basis(), origin + forward * hit_reach)
		results.append_array(space.intersect_shape(_query, 8))
	if uppercut and double_uppercut:
		# Doppio montante: anche in alto, dove ricadono le auto lanciate.
		_query.transform = Transform3D(Basis(), origin + Vector3.UP * high_punch_height + forward * hit_reach)
		results.append_array(space.intersect_shape(_query, 8))
	var hits: Array[Car] = []
	var far := 0
	for result in results:
		var car := result.collider as Car
		if car and not hits.has(car):
			hits.append(car)
			if car.global_position.distance_to(_frog.global_position) > 3.0:
				far += 1
			if uppercut:
				car.set_meta("uppercut", true)
				if meteor:
					car.set_meta("meteor", true)
			if long_reach and yank:
				_yank(car, blow)
			else:
				car.receive_punch(blow, explosive)
		elif result.collider is Baggage:
			result.collider.receive_punch(blow)
			Sfx.play_at(&"baggage_hit", result.collider.global_position)
	_frog.power_used.emit(&"punch")
	# Il colpo che va a segno suona da sé (la lamiera è dentro): le auto
	# colpite non aggiungono il loro schianto.
	if hits.is_empty():
		Sfx.play(&"punch_swing")
	else:
		Sfx.play(&"punch_hit", 0.0, 1.0 - 0.04 * mini(hits.size() - 1, 4))
	# Maestria di montante e guantone a molla.
	if uppercut:
		Progress.trial_add("uppercut", 0, hits.size())
	if long_reach:
		Progress.trial_add("long_glove", 0, far)
		Progress.trial_best("long_glove", 1, hits.size())
	if not hits.is_empty():
		_frog.punched.emit(hits)


## Tira e molla: il guantone afferra l'auto e la tira verso la rana, poi la
## scaglia via più forte (lo fa l'auto, vedi Car.yank).
func _yank(car: Car, blow: Vector3) -> void:
	car.receive_punch(Vector3.ZERO, explosive)
	car.yank(_frog, blow * yank_boost, yank_time)


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
	_frog.set_palette("glove", key)
	for glove in _gloves:
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
