class_name Lane
extends Node3D
## Una corsia: genera veicoli a un capo e li elimina all'altro. La corsia corre
## lungo l'asse X locale; direction indica il verso (+1 o -1).

const CAR_SIZE := Vector3(2.0, 1.4, 4.0)
const TRUCK_SIZE := Vector3(2.4, 2.6, 8.0)

var direction := 1.0
var speed := 8.0
var half_length := 35.0
## Spazio libero tra un veicolo e il successivo, in metri.
var min_gap := 6.0
var max_gap := 20.0
var truck_chance := 0.2

var _next_is_truck := false
var _next_gap := 0.0
var _spawn_query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_spawn_query.collision_mask = 4 # veicoli
	_spawn_query.shape = BoxShape3D.new()
	_roll_next()
	_prepopulate()


func _physics_process(_delta: float) -> void:
	if _spawn_area_is_clear():
		_spawn_car(_start_x())

	for child in get_children():
		var car := child as Car
		if car and car.state == Car.State.DRIVING and car.position.x * direction > half_length + car.size.z:
			car.queue_free()


## Riempie la corsia all'avvio, così il traffico non parte vuoto.
func _prepopulate() -> void:
	var x := _start_x()
	while x * direction < half_length:
		var car := _spawn_car(x)
		x += direction * _spacing_after(car)


func _spawn_car(x: float) -> Car:
	var car := Car.new()
	if _next_is_truck:
		car.size = TRUCK_SIZE
		car.hit_damage = 40
	else:
		car.size = CAR_SIZE
	car.position = Vector3(x, car.size.y / 2.0, 0.0)
	# Il muso (-Z locale) deve guardare nel verso della corsia.
	car.rotation.y = -PI / 2.0 * direction
	car.drive_direction = global_basis.x.normalized() * direction
	car.cruise_speed = speed
	add_child(car)
	_roll_next()
	return car


## Il prossimo veicolo nasce solo se all'inizio della corsia c'è spazio per lui
## e per la distanza che deve tenere da chi lo precede. Un rottame fermo
## all'inizio blocca le nascite.
func _spawn_area_is_clear() -> bool:
	var next_size := TRUCK_SIZE if _next_is_truck else CAR_SIZE
	var box := _spawn_query.shape as BoxShape3D
	box.size = Vector3(next_size.z + _next_gap, next_size.y, next_size.x)
	var center_x := _start_x() + direction * _next_gap / 2.0
	_spawn_query.transform = global_transform * Transform3D(Basis(), Vector3(center_x, next_size.y / 2.0, 0.0))
	return get_world_3d().direct_space_state.intersect_shape(_spawn_query, 1).is_empty()


## Distanza tra il centro di car e quello del veicolo che lo segue.
func _spacing_after(car: Car) -> float:
	var next_length := TRUCK_SIZE.z if _next_is_truck else CAR_SIZE.z
	return (car.size.z + next_length) / 2.0 + _next_gap


func _roll_next() -> void:
	_next_is_truck = randf() < truck_chance
	_next_gap = randf_range(min_gap, max_gap)


func _start_x() -> float:
	return -direction * half_length
