class_name ShipLane
extends Node3D
## Una corsia d'acqua del porto: le navi entrano da un lato ed escono
## dall'altro, una dopo l'altra, con un tratto d'acqua libera in mezzo. Due
## gru scavalcano la corsia, una per metà, e caricano le navi che passano.
## Corre lungo l'asse X locale; direction indica il verso.

var direction := 1.0
var speed := 4.0
var play_half_width := 37.0
## Acqua libera tra la poppa di una nave e la prua della successiva.
var min_gap := 8.0
var max_gap := 22.0
## Quota di caselle piene con cui arriva una nave.
var initial_fill := 0.25
## Le gru caricano a terra finché le caselle piene sono questa quota; poi
## impilano.
var loading_cap := 0.45

var cranes: Array[Crane] = []

var _last: Ship
var _next_gap := 0.0


func _ready() -> void:
	_next_gap = randf_range(min_gap, max_gap)
	# La corsia parte già piena; la prossima nave segue la prima, quella
	# all'inizio della corsia.
	var x := _start_x()
	var first: Ship = null
	while x * direction < play_half_width + Ship.LENGTH:
		var ship := _spawn(x)
		if first == null:
			first = ship
		x += direction * (Ship.LENGTH + _next_gap)
		_next_gap = randf_range(min_gap, max_gap)
	_last = first
	for side in [-1.0, 1.0]:
		var crane := Crane.new()
		crane.lane = self
		# Ogni gru lavora su una metà, senza incrociare l'altra.
		crane.min_x = -play_half_width + 4.0 if side < 0.0 else 2.5
		crane.max_x = -2.5 if side < 0.0 else play_half_width - 4.0
		crane.position.x = randf_range(crane.min_x, crane.max_x)
		add_child(crane)
		cranes.append(crane)


func _physics_process(_delta: float) -> void:
	if _last == null or (_last.position.x - _start_x()) * direction >= Ship.LENGTH + _next_gap:
		_spawn(_start_x())
		_next_gap = randf_range(min_gap, max_gap)
	for ship in ships():
		if ship.position.x * direction > play_half_width + Ship.LENGTH:
			ship.queue_free()


func ships() -> Array[Ship]:
	var found: Array[Ship] = []
	for child in get_children():
		var ship := child as Ship
		if ship and not ship.is_queued_for_deletion():
			found.append(ship)
	return found


## La nave sotto il punto dato, sul ponte o sui container (null se nessuna).
func ship_under(point: Vector3) -> Ship:
	for ship in ships():
		var local := ship.to_local(point)
		if absf(local.z) <= Ship.HALF_WIDTH and local.x >= Ship.STERN_X and local.x <= Ship.BOW_X and local.y > Ship.DECK_Y - 0.5:
			return ship
	return null


## La gru più vicina al punto, lungo la corsia.
func nearest_crane(point: Vector3) -> Crane:
	var x := to_local(point).x
	var best: Crane = null
	for crane in cranes:
		if best == null or absf(crane.position.x - x) < absf(best.position.x - x):
			best = crane
	return best


func _spawn(x: float) -> Ship:
	# L'origine della nave sta a metà strada fra poppa e prua, più o meno.
	var ship := Ship.create(direction, speed)
	ship.position.x = x
	add_child(ship)
	ship.load_initial(initial_fill)
	_last = ship
	return ship


func _start_x() -> float:
	return -direction * (play_half_width + Ship.LENGTH)
