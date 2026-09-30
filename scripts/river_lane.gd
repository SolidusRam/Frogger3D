class_name RiverLane
extends Node3D
## Una corrente del fiume: genera tronchi e coccodrilli a un capo e li elimina
## all'altro. Corre lungo l'asse X locale; direction indica il verso.

const CROCODILE_SIZE := Vector3(1.4, 0.8, 6.0)
const LOG_WIDTH := 1.6
const LOG_HEIGHT := 1.0

var direction := 1.0
var speed := 3.0
var half_length := 45.0
## Quota del centro degli oggetti che galleggiano.
var float_height := 0.0
## Spazio libero tra un oggetto e il successivo, in metri.
var min_gap := 3.0
var max_gap := 9.0
var crocodile_chance := 0.25

var _last: Floater
var _next_is_crocodile := false
var _next_length := 0.0
var _next_gap := 0.0


func _ready() -> void:
	_roll_next()
	var x := _start_x()
	var first: Floater = null
	while x * direction < half_length:
		var floater := _spawn(x)
		if first == null:
			first = floater
		x += direction * _spacing_after(floater)
	_last = first


func _physics_process(_delta: float) -> void:
	if _last == null or (_last.position.x - _start_x()) * direction >= _spacing_after(_last):
		_spawn(_start_x())
	for child in get_children():
		var floater := child as Floater
		if floater and floater.position.x * direction > half_length + floater.size.z:
			floater.queue_free()


func _spawn(x: float) -> Floater:
	var floater: Floater
	if _next_is_crocodile:
		floater = Crocodile.new()
		floater.size = CROCODILE_SIZE
	else:
		floater = RiverLog.new()
		floater.size = Vector3(LOG_WIDTH, LOG_HEIGHT, _next_length)
	# Il lato anteriore (-Z locale) guarda nel verso della corrente.
	floater.position = Vector3(x, float_height, 0.0)
	floater.rotation.y = -PI / 2.0 * direction
	floater.drift_velocity = global_basis.x.normalized() * direction * speed
	add_child(floater)
	_last = floater
	_roll_next()
	return floater


## Distanza tra il centro di floater e quello dell'oggetto che lo segue.
func _spacing_after(floater: Floater) -> float:
	return (floater.size.z + _next_length) / 2.0 + _next_gap


func _roll_next() -> void:
	_next_is_crocodile = randf() < crocodile_chance
	_next_length = CROCODILE_SIZE.z if _next_is_crocodile else randf_range(6.0, 11.0)
	_next_gap = randf_range(min_gap, max_gap)


func _start_x() -> float:
	return -direction * half_length
