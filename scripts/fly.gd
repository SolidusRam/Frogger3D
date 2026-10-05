class_name Fly
extends Node3D
## Una mosca: la valuta del gioco. Sta sopra le cose che si muovono (il tetto
## di un'auto, il dorso di un coccodrillo, un tronco, un vagone, l'ala di un
## aereo, il ponte di una nave) e viaggia con loro: per prenderla bisogna
## salirci, o arrivarci con la lingua. La mosca d'oro, rara e solo su treni
## e aerei, è una valuta a sé: serve ad attivare i miglioramenti delle carte.
## Le mosche raccolte si spendono allo stagno.

## La rana la prende entro questo raggio (più la statistica "Lingua lunga").
const PICKUP_RADIUS := 1.1
const GOLDEN_CHANCE := 0.2

## Statistica dello stagno "Fortuna": più mosche d'oro.
static var golden_factor := 1.0
## Un generatore tutto suo: le mosche non devono cambiare la sequenza casuale
## del gioco (percorso, traffico).
static var _rng := RandomNumberGenerator.new()


## Il generatore delle mosche, per le scelte che le riguardano.
static func rng() -> RandomNumberGenerator:
	return _rng

var golden := false

var _wings: Array[Node3D] = []
var _halo: Node3D
var _time := 0.0
var _taken := false


## Con probabilità chance mette una mosca su carrier, nel punto dato (in
## coordinate di carrier). Le mosche d'oro solo dove can_be_golden.
static func maybe_add(carrier: Node3D, chance: float, at: Vector3, can_be_golden := false) -> Fly:
	if _rng.randf() >= chance:
		return null
	var fly := Fly.new()
	fly.golden = can_be_golden and _rng.randf() < GOLDEN_CHANCE * golden_factor
	fly.position = at
	carrier.add_child(fly)
	return fly


func _ready() -> void:
	add_to_group("flies")
	Sfx.loop(self, &"fly_buzz", 0.0, 1.25 if golden else 1.0, 0.35)
	_time = _rng.randf() * TAU
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.3
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = Style.material("gold" if golden else "pupil")
	body.mesh = sphere
	# Troppo piccola per fare ombra: sarebbero solo chiamate di disegno in più.
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.02, 0.16)
		box.material = Style.material("eye")
		wing.mesh = box
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing.position = Vector3(side * 0.18, 0.08, 0.0)
		add_child(wing)
		_wings.append(wing)
	# Un anello che gira: la mosca si vede anche da lontano.
	_halo = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.38
	ring.outer_radius = 0.46
	ring.rings = 8
	ring.ring_segments = 3
	ring.material = Style.material("gold" if golden else "sign_white")
	(_halo as MeshInstance3D).mesh = ring
	(_halo as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)


func _process(delta: float) -> void:
	_time += delta
	for i in _wings.size():
		_wings[i].rotation.z = (1.0 if i == 0 else -1.0) * sin(_time * 40.0) * 0.6
	_halo.rotation.x = PI / 2.0
	_halo.rotation.y += delta * 3.0
	_halo.scale = Vector3.ONE * (1.0 + 0.1 * sin(_time * 4.0))


func _physics_process(_delta: float) -> void:
	var frog := get_tree().get_first_node_in_group("frog") as Node3D
	var game := get_tree().get_first_node_in_group("game")
	if frog == null or game == null or _taken:
		return
	var reach: float = PICKUP_RADIUS + game.fly_magnet
	if global_position.distance_to(frog.global_position + Vector3.UP * 0.5) < reach:
		collect()


## Presa: vale per le mosche della run, e fa un piccolo scatto.
func collect() -> void:
	if _taken:
		return
	_taken = true
	Sfx.unloop(self, &"fly_buzz")
	Sfx.play(&"fly_golden" if golden else &"fly_collect")
	var game := get_tree().get_first_node_in_group("game")
	if game:
		if golden:
			game.add_golden(1)
		else:
			game.add_flies(1)
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.8, 0.08)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.1)
	tween.tween_callback(queue_free)
