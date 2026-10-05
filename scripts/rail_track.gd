class_name RailTrack
extends Node3D
## Un binario: massicciata, rotaie, traversine, pali con le luci e i treni.
## Prima di ogni treno le luci lampeggiano per warning_time secondi, e il muso
## entra nella zona di gioco proprio allo scadere: l'avviso non cala mai col
## calore, deve restare leale. Dal livello Heat.STEP_LEVEL di calore (il
## gradino della ferrovia) metà dei treni sono rapidi: molto più veloci, con lo
## stesso avviso. Corre lungo l'asse X locale.

const SIGNAL := preload("res://assets/models/signal.glb")

enum Phase { WAITING, WARNING, PASSING }

var direction := 1.0
## Lunghezza del binario visibile, fino all'orizzonte.
var length := 400.0
var play_half_width := 37.0
var warning_time := 2.5
var min_wait := 4.0
var max_wait := 10.0
## Velocità base; il calore la alza fino al +30%: più veloce non si vedrebbe.
var base_speed := 26.0
var max_heat_bonus := 0.3
## Il rapido: quanti treni lo sono dal livello dei gradini, e la velocità.
var express_chance := 0.5
var express_speed := 55.0

var phase := Phase.WAITING
var train: Train

var _timer := 0.0
var _lamps: Array[Node3D] = []
var _blink := 0.0


## Da dove si sentono la campanella (sui pali, davanti alla rana) e il treno
## (il punto del treno più vicino alla rana: il muso quando arriva).
var _bell: Node3D
var _train_voice: Node3D


func _ready() -> void:
	_build_track()
	_build_signals()
	_bell = Node3D.new()
	add_child(_bell)
	_train_voice = Node3D.new()
	add_child(_train_voice)
	_timer = randf_range(1.0, max_wait)


func _physics_process(delta: float) -> void:
	match phase:
		Phase.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_send_train()
		Phase.WARNING:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.PASSING
		Phase.PASSING:
			if train.tail_x() * direction > play_half_width + 10.0:
				train.queue_free()
				train = null
				Sfx.unloop(_bell, &"rail_bell")
				Sfx.unloop(_train_voice, &"train_loop")
				phase = Phase.WAITING
				_timer = randf_range(min_wait, max_wait)
	_update_lamps(delta)
	_update_voices()


## La campanella e il treno seguono la rana lungo il binario: si sentono da
## davanti, e il treno dal lato da cui arriva.
func _update_voices() -> void:
	var frog := get_tree().get_first_node_in_group("frog") as Node3D
	if frog == null:
		return
	var frog_x := to_local(frog.global_position).x
	_bell.position = Vector3(clampf(frog_x, -play_half_width, play_half_width), 2.0, 2.1)
	if train:
		var ends := [train.nose_x(), train.tail_x()]
		_train_voice.position = Vector3(clampf(frog_x, ends.min(), ends.max()), 1.5, 0.0)


## Vero mentre le luci lampeggiano: dall'inizio dell'avviso al passaggio
## della coda.
func is_warning() -> bool:
	return phase != Phase.WAITING


func _send_train() -> void:
	train = Train.new()
	train.direction = direction
	train.express = Heat.level() >= Heat.STEP_LEVEL and randf() < express_chance
	train.speed = express_speed if train.express else base_speed * (1.0 + max_heat_bonus * Heat.ratio())
	train.build(2 if train.express else randi_range(3, 5))
	# Il treno si mette al suo posto prima di entrare nella scena: con
	# sync_to_physics i vagoni esisterebbero per un passo dove sono stati
	# composti, in mezzo alla zona di gioco, e travolgerebbero chi c'è senza
	# farsi vedere.
	train.place_nose(-direction * (play_half_width + train.speed * warning_time))
	add_child(train)
	phase = Phase.WARNING
	_timer = warning_time
	# La tromba suona dal lato da cui arriva il treno: dice anche da dove.
	Sfx.play_at(&"train_horn", to_global(Vector3(-direction * (play_half_width + 4.0), 2.0, 0.0)), 0.0, 1.3 if train.express else 1.0, 3.0)
	Sfx.loop(_bell, &"rail_bell", 0.0, 1.0, 1.5)
	_update_voices()
	Sfx.loop(_train_voice, &"train_loop", 0.0, 1.35 if train.express else 1.0, 3.0, true)


func _update_lamps(delta: float) -> void:
	_blink = fmod(_blink + delta, 0.5)
	var lit := is_warning()
	for i in _lamps.size():
		# Le due luci di ogni palo si alternano, come ai passaggi a livello.
		var first := i % 2 == 0
		_lamps[i].visible = lit and (_blink < 0.25) == first


func _build_track() -> void:
	var ballast := MeshInstance3D.new()
	ballast.mesh = _box(Vector3(length, 0.16, 3.2), "ballast")
	ballast.position.y = 0.08
	add_child(ballast)

	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.mesh = _box(Vector3(length, 0.12, 0.1), "rail")
		rail.position = Vector3(0.0, 0.24, side * 0.72)
		add_child(rail)

	var sleepers := MultiMesh.new()
	sleepers.transform_format = MultiMesh.TRANSFORM_3D
	sleepers.mesh = _box(Vector3(0.3, 0.1, 2.6), "sleeper")
	sleepers.instance_count = floori(length / 0.9)
	for i in sleepers.instance_count:
		sleepers.set_instance_transform(i, Transform3D(Basis(), Vector3(-length / 2.0 + i * 0.9, 0.17, 0.0)))
	var sleepers_instance := MultiMeshInstance3D.new()
	sleepers_instance.multimesh = sleepers
	add_child(sleepers_instance)


## Pali sul lato da cui arriva la rana (+Z), con le luci verso di lei.
func _build_signals() -> void:
	var x := -play_half_width + 4.0
	while x < play_half_width - 2.0:
		var post: Node3D = SIGNAL.instantiate()
		post.position = Vector3(x, 0.0, 2.1)
		add_child(post)
		Style.apply_palette(post)
		for lamp: Node3D in post.find_children("LampOn_*", "", true, false):
			lamp.visible = false
			_lamps.append(lamp)
		x += 16.0


static func _box(size: Vector3, palette_key: String) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Style.material(palette_key)
	return mesh
