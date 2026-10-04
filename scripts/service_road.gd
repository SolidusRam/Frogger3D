class_name ServiceRoad
extends Node3D
## Una strada di servizio dell'aeroporto: ci passano i trenini bagagli, uno
## dopo l'altro, tutti alla stessa velocità. Corre lungo l'asse X locale.

const WIDTH := 3.0

var direction := 1.0
var speed := 6.0
var length := 400.0
var play_half_width := 37.0
## Spazio tra la coda di un trenino e il muso del successivo, in metri.
var min_gap := 25.0
var max_gap := 50.0
## Dove finiscono i bagagli che lasciano i carrelli.
var home: Node

var _next_gap := 0.0


func _ready() -> void:
	var road := MeshInstance3D.new()
	road.mesh = Taxiway._box(Vector3(length, 0.02, WIDTH), "asphalt")
	road.position.y = 0.01
	add_child(road)
	for side in [-1.0, 1.0]:
		var line := MeshInstance3D.new()
		line.mesh = Taxiway._box(Vector3(length, 0.02, 0.12), "lane_line")
		line.position = Vector3(0.0, 0.025, side * WIDTH / 2.0)
		add_child(line)
	# All'inizio un trenino è già in strada, in un punto a caso.
	var first := _send(randf_range(-play_half_width, play_half_width))
	_next_gap = randf_range(min_gap, max_gap)
	# E un altro dietro di lui, se c'è posto prima dell'inizio della strada.
	if first.tail_x() * direction - _next_gap > _start_x() * direction:
		_send(first.tail_x() - direction * _next_gap)
		_next_gap = randf_range(min_gap, max_gap)


func _physics_process(_delta: float) -> void:
	var last: BaggageTrain = null
	for child in get_children():
		var train := child as BaggageTrain
		if train == null:
			continue
		if train.tail_x() * direction > play_half_width + 5.0:
			train.queue_free()
		elif last == null or train.tail_x() * direction < last.tail_x() * direction:
			last = train
	if last == null or (last.tail_x() - _start_x()) * direction > _next_gap:
		_send(_start_x())
		_next_gap = randf_range(min_gap, max_gap)


func trains() -> Array[BaggageTrain]:
	var found: Array[BaggageTrain] = []
	for child in get_children():
		if child is BaggageTrain and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _send(nose_x: float) -> BaggageTrain:
	var train := BaggageTrain.new()
	train.direction = direction
	train.speed = speed
	train.home = home
	train.build(randi_range(2, 4))
	train.place_nose(nose_x)
	add_child(train)
	return train


## Il muso dei trenini nuovi nasce appena fuori dalla zona di gioco.
func _start_x() -> float:
	return -direction * (play_half_width + 2.0)
