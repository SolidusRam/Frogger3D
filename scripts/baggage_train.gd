class_name BaggageTrain
extends Node3D
## Un trenino bagagli: un trattorino e da 2 a 4 carrelli carichi di valigie e
## pacchi. Corre sulle strade di servizio dell'aeroporto, sotto le ali, e non
## diventa mai rottame. Il getto degli aerei gli porta via il carico (lo
## libera Airplane), un pugno fa volare un bagaglio. Su trattorino e carrelli
## si sale e si viaggia; fa male solo il muso del trattorino, a chi gli sta
## davanti. Corre lungo l'asse X locale; direction indica il verso.

const TUG_MODEL := preload("res://assets/models/tug.glb")
const DOLLY_MODEL := preload("res://assets/models/dolly.glb")
const TUG_LENGTH := 2.6
## Il carrello col suo timone.
const DOLLY_LENGTH := 3.15
const GAP := 0.3
## Altezza del pianale dei carrelli.
const BED := 0.55
## Caselle del carico: due di traverso, tre per lungo, al centro del pianale.
const CELL_X := [-0.36, 0.36]
const CELL_Z := [-0.85, 0.0, 0.85]

var direction := 1.0
var speed := 6.0
var damage := 15
var knockback_speed := 10.0
var length := 0.0
## Dove finiscono i bagagli che lasciano i carrelli.
var home: Node

var _cars: Array[AnimatableBody3D] = []
var _nose: Area3D
var _last_hit_frame := -1000


## Compone il trenino e lo carica. Come per il treno, va fatto prima che entri
## nella scena: dopo, i corpi si spostano solo al passo di fisica successivo.
func build(dolly_count: int) -> void:
	var tug := _make_car(TUG_MODEL, -direction * TUG_LENGTH / 2.0)
	_solid(tug, Vector3(1.4, 0.8, TUG_LENGTH), Vector3(0.0, 0.65, 0.0))
	_solid(tug, Vector3(1.4, 0.1, 1.4), Vector3(0.0, 1.74, 0.6))
	_nose = _make_nose(tug)
	var offset := TUG_LENGTH + GAP
	for i in dolly_count:
		# Il timone sporge davanti: il centro del pianale è più indietro.
		var dolly := _make_car(DOLLY_MODEL, -direction * (offset + DOLLY_LENGTH - 1.3))
		_solid(dolly, Vector3(1.5, 0.15, 2.6), Vector3(0.0, BED - 0.075, 0.0))
		_load(dolly)
		offset += DOLLY_LENGTH + GAP
	length = offset - GAP


## Sposta il trenino in modo che il muso sia nel punto x della strada. Anche
## questo prima che entri nella scena.
func place_nose(x: float) -> void:
	var shift := x - nose_x()
	for car in _cars:
		car.position.x += shift


func nose_x() -> float:
	return _cars[0].position.x + direction * TUG_LENGTH / 2.0


func tail_x() -> float:
	return nose_x() - direction * length


func velocity() -> Vector3:
	return global_basis.x.normalized() * direction * speed


## I bagagli ancora sui carrelli.
func cargo() -> Array[Baggage]:
	var found: Array[Baggage] = []
	for car in _cars:
		for child in car.get_children():
			if child is Baggage and child.loaded:
				found.append(child)
	return found


func _physics_process(delta: float) -> void:
	for car in _cars:
		car.position.x += direction * speed * delta
	_hit_frog()


## Il muso travolge chi gli sta davanti, con un colpo solo ogni mezzo secondo.
func _hit_frog() -> void:
	var frame := Engine.get_physics_frames()
	if frame - _last_hit_frame < 30:
		return
	var forward := velocity().normalized()
	for body in _nose.get_overlapping_bodies():
		var frog := body as Frog
		if frog == null or (velocity() - frog.velocity).dot(forward) < 2.0:
			continue
		_last_hit_frame = frame
		var side := forward.cross(Vector3.UP)
		var side_sign := 1.0 if (frog.global_position - _nose.global_position).dot(side) >= 0.0 else -1.0
		frog.take_hit(damage, (forward * 0.5 + side * side_sign).normalized() * knockback_speed + Vector3.UP * 4.0)


## Riempie il pianale: un bagaglio quasi in ogni casella, a volte un secondo
## strato.
func _load(dolly: AnimatableBody3D) -> void:
	for x in CELL_X:
		for z in CELL_Z:
			if randf() < 0.15:
				continue
			var height := BED
			for layer in 2:
				if layer == 1 and randf() < 0.65:
					break
				var baggage := Baggage.new()
				baggage.kind = Baggage.random_kind()
				baggage.home = home
				baggage.carrier = self
				var size: Vector3 = Baggage.KINDS[baggage.kind].size
				baggage.position = Vector3(x, height + size.y / 2.0, z)
				baggage.rotation.y = randf_range(-0.15, 0.15)
				dolly.add_child(baggage)
				height += size.y


func _make_car(model_scene: PackedScene, x: float) -> AnimatableBody3D:
	var car := AnimatableBody3D.new()
	car.position.x = x
	car.collision_layer = 8 # piattaforme: ci si sale sopra
	car.collision_mask = 0
	car.sync_to_physics = true
	# Il muso dei modelli guarda verso -Z: lo si gira nel verso di marcia.
	car.rotation.y = -PI / 2.0 * direction
	var model: Node3D = model_scene.instantiate()
	car.add_child(model)
	Style.apply_palette(model)
	add_child(car)
	_cars.append(car)
	return car


func _solid(car: AnimatableBody3D, size: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	car.add_child(collision)


## Davanti al trattorino, più basso del cofano: chi ci sta sopra non si fa male.
func _make_nose(tug: AnimatableBody3D) -> Area3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 0.8, 0.7)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 # rana
	area.position = Vector3(0.0, 0.5, -TUG_LENGTH / 2.0 - 0.2)
	area.add_child(collision)
	tug.add_child(area)
	return area
