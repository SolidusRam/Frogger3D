class_name Train
extends Node3D
## Un treno: locomotiva e vagoni (carri chiusi e pianali). È l'unico veicolo
## che non diventa mai rottame: travolge auto e rottami, fa molto male alla
## rana, e chi sta sul tetto viaggia con lui come su un tronco velocissimo.
## Il rapido (il gradino della ferrovia) è bianco, corto e molto più veloce,
## e la sua scia risucchia verso i binari chi sta lì accanto.
## Corre lungo l'asse X locale del binario; direction indica il verso.

const GAP := 0.6
## Lunghezza e altezza di ogni rotabile; il pianale è basso: ci si sale col
## salto normale, sul carro chiuso serve il super salto.
const KINDS := {
	"locomotive": {"model": preload("res://assets/models/locomotive.glb"), "length": 14.0, "height": 3.8},
	"boxcar": {"model": preload("res://assets/models/boxcar.glb"), "length": 12.0, "height": 3.7},
	"flatcar": {"model": preload("res://assets/models/flatcar.glb"), "length": 12.0, "height": 1.2},
}
## Altezza del telaio: sotto c'è solo lo spazio delle ruote.
const FRAME := 0.7
## La scia del rapido: fin dove arriva di lato (dalla fiancata), quanto tira
## e quanto dura dietro la coda.
const WAKE_RANGE := 3.0
const WAKE_PULL := 9.0
const WAKE_TAIL := 12.0
const HALF_WIDTH := 1.5
const EXPRESS_COLORS := {"loco": "express", "loco_stripe": "express_stripe", "wagon": "express"}

var direction := 1.0
var speed := 26.0
var damage := 60
## Velocità data ai veicoli travolti.
var smash_speed := 22.0
var length := 0.0
## Il rapido: bianco, due carrozze, scia che risucchia.
var express := false

var _wagons: Array[AnimatableBody3D] = []
var _areas: Array[Area3D] = []
## Ultimo passo di fisica in cui ogni corpo è stato travolto: un colpo solo.
var _last_hit := {}


## Compone il treno: la locomotiva davanti e wagon_count vagoni dietro.
func build(wagon_count: int) -> void:
	var kinds: Array[String] = ["locomotive"]
	for i in wagon_count:
		kinds.append("boxcar" if express or randf() < 0.55 else "flatcar")
	var offset := 0.0
	for kind in kinds:
		var info: Dictionary = KINDS[kind]
		var wagon := _make_wagon(info)
		wagon.position.x = -direction * (offset + info.length / 2.0)
		add_child(wagon)
		_wagons.append(wagon)
		offset += info.length + GAP
	length = offset - GAP


## Sposta il treno in modo che il muso sia nel punto x del binario.
func place_nose(x: float) -> void:
	var shift := x - nose_x()
	for wagon in _wagons:
		wagon.position.x += shift


func nose_x() -> float:
	return _wagons[0].position.x + direction * KINDS["locomotive"].length / 2.0


func tail_x() -> float:
	return nose_x() - direction * length


func _physics_process(delta: float) -> void:
	for wagon in _wagons:
		wagon.position.x += direction * speed * delta
	_smash()
	if express:
		_suck()


## La scia del rapido: chi sta accanto ai binari, dal muso a poco dopo la
## coda, viene tirato verso il treno, più forte quanto è più vicino.
func _suck() -> void:
	var frog := get_tree().get_first_node_in_group("frog") as Frog
	if frog == null:
		return
	var local := to_local(frog.global_position)
	var behind_nose := (nose_x() - local.x) * direction
	var ahead_of_wake := (local.x - tail_x()) * direction + WAKE_TAIL
	var gap := absf(local.z) - HALF_WIDTH
	if behind_nose < 0.0 or ahead_of_wake < 0.0 or gap <= 0.0 or gap > WAKE_RANGE:
		return
	var toward := global_basis.z.normalized() * -signf(local.z)
	frog.apply_wind(toward * WAKE_PULL * (1.0 - gap / WAKE_RANGE), 0.0)


## Travolge ciò che tocca ai lati e sul muso (non sul tetto): i veicoli
## diventano rottami e volano via, la rana perde molta vita.
func _smash() -> void:
	var forward := global_basis.x.normalized() * direction
	var side := forward.cross(Vector3.UP)
	var frame := Engine.get_physics_frames()
	for area in _areas:
		for body in area.get_overlapping_bodies():
			var id := body.get_instance_id()
			if frame - _last_hit.get(id, -1000) < 30:
				continue
			_last_hit[id] = frame
			var side_sign := 1.0 if (body.global_position - area.global_position).dot(side) >= 0.0 else -1.0
			var push := (forward * 0.7 + side * side_sign + Vector3.UP * 0.6).normalized()
			# La rana va sbalzata di lato e bassa: verso l'alto atterrerebbe sul
			# tetto dei vagoni che seguono, e viaggerebbe col treno che l'ha presa.
			var frog_push := (forward * 0.5 + side * side_sign + Vector3.UP * 0.3).normalized()
			if body is Car:
				body.become_wreck()
				body.apply_central_impulse(push * body.mass * smash_speed)
			elif body is Frog:
				body.take_hit(damage, frog_push * 18.0)


func _make_wagon(info: Dictionary) -> AnimatableBody3D:
	var wagon := AnimatableBody3D.new()
	wagon.collision_layer = 8 # piattaforme: ci si sale sopra
	wagon.collision_mask = 0
	wagon.sync_to_physics = true
	# Il muso dei modelli guarda verso -Z: lo si gira nel verso di marcia.
	wagon.rotation.y = -PI / 2.0 * direction
	var height: float = info.height
	var body_height := height - FRAME

	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, body_height, info.length)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = FRAME + body_height / 2.0
	wagon.add_child(collision)

	var model: Node3D = info.model.instantiate()
	wagon.add_child(model)
	Style.apply_palette(model, EXPRESS_COLORS if express else {})

	# Zona d'impatto: un po' più larga e lunga, ma più bassa del tetto, così
	# chi viaggia sopra non si fa male.
	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(3.5, maxf(body_height - 0.1, 0.4), info.length + 0.5)
	var area_collision := CollisionShape3D.new()
	area_collision.shape = area_shape
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 | 4 # rana, veicoli
	area.position.y = 0.3 + area_shape.size.y / 2.0
	area.add_child(area_collision)
	wagon.add_child(area)
	_areas.append(area)
	return wagon
