class_name Lane
extends Node3D
## Una corsia: genera veicoli a un capo e li elimina all'altro. La corsia corre
## lungo l'asse X locale; direction indica il verso (+1 o -1).

var direction := 1.0
var speed := 8.0
var half_length := 35.0
## Spazio libero tra un veicolo e il successivo, in metri.
var min_gap := 6.0
var max_gap := 20.0

var _next_type := "sedan"
var _next_gap := 0.0
var _spawn_query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_spawn_query.collision_mask = 4 # veicoli
	_spawn_query.shape = BoxShape3D.new()
	_roll_next()
	_prepopulate()


func _physics_process(delta: float) -> void:
	if _spawn_area_is_clear():
		_spawn_car(_start_x())

	var loss_chance := Heat.loss_of_control_chance() * delta
	for child in get_children():
		var car := child as Car
		if car == null or car.state != Car.State.DRIVING:
			continue
		if car.position.x * direction > half_length + car.size.z:
			car.queue_free()
		elif loss_chance > 0.0 and absf(car.position.x) < half_length and randf() < loss_chance:
			car.lose_control()


## Riempie la corsia all'avvio, così il traffico non parte vuoto.
func _prepopulate() -> void:
	var x := _start_x()
	while x * direction < half_length:
		var car := _spawn_car(x)
		x += direction * _spacing_after(car)


func _spawn_car(x: float) -> Car:
	var car := Car.new()
	car.model_type = _next_type
	car.size = Car.TYPES[_next_type].size
	car.position = Vector3(x, car.size.y / 2.0, 0.0)
	# Il muso (-Z locale) deve guardare nel verso della corsia.
	car.rotation.y = -PI / 2.0 * direction
	car.drive_direction = global_basis.x.normalized() * direction
	# Il calore conta alla nascita: i nuovi veicoli sono più veloci, frenano
	# peggio e si schiantano più facilmente.
	car.cruise_speed = speed * Heat.traffic_speed_factor()
	car.braking *= Heat.braking_factor()
	car.crash_speed *= Heat.crash_speed_factor()
	add_child(car)
	_roll_next()
	return car


## Il prossimo veicolo nasce solo se all'inizio della corsia c'è spazio per lui
## e per la distanza che deve tenere da chi lo precede. Un rottame fermo
## all'inizio blocca le nascite.
func _spawn_area_is_clear() -> bool:
	var next_size: Vector3 = Car.TYPES[_next_type].size
	var box := _spawn_query.shape as BoxShape3D
	box.size = Vector3(next_size.z + _next_gap, next_size.y, next_size.x)
	var center_x := _start_x() + direction * _next_gap / 2.0
	_spawn_query.transform = global_transform * Transform3D(Basis(), Vector3(center_x, next_size.y / 2.0, 0.0))
	return get_world_3d().direct_space_state.intersect_shape(_spawn_query, 1).is_empty()


## Distanza tra il centro di car e quello del veicolo che lo segue.
func _spacing_after(car: Car) -> float:
	var next_length: float = Car.TYPES[_next_type].size.z
	return (car.size.z + next_length) / 2.0 + _next_gap


func _roll_next() -> void:
	_next_type = Car.random_type()
	_next_gap = randf_range(min_gap, max_gap) * Heat.gap_factor()


func _start_x() -> float:
	return -direction * half_length
