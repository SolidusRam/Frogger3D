class_name Ship
extends AnimatableBody3D
## Una nave portacontainer: scorre lungo la corsia d'acqua del porto, come un
## tronco enorme. Si sale col salto normale; il ponte di comando a poppa e il
## castello di prua sono troppo alti. In mezzo, sul ponte, i container stanno
## in una griglia di caselle (5 lungo la nave, 4 di traverso) e si impilano:
## sono muri alti 2,6 m da aggirare, un labirinto. Un container caricato
## diventa parte della nave e viaggia con lei. La prua spinge e non fa male.
## La nave corre lungo l'asse X locale: la prua guarda verso +X.

const MODEL := preload("res://assets/models/ship.glb")
## Quota del ponte rispetto alla banchina.
const DECK_Y := 0.7
const STERN_X := -20.0
const BOW_X := 21.5
const LENGTH := BOW_X - STERN_X
const HALF_WIDTH := 5.0
## Le caselle dei container: colonne lungo X, file di traverso.
const COLUMNS := 5
const ROWS := 4
const COLUMN_PITCH := 6.3
const ROW_PITCH := 2.5
const FIRST_COLUMN_X := -11.35
const MAX_STACK := 3
## Per quanti passi di fisica una casella resta prenotata da una gru.
const RESERVATION_FRAMES := 240

var speed := 4.0

## Container impilati in ogni casella: _levels[colonna][fila].
var _levels := []
## Casella -> passo di fisica in cui una gru l'ha prenotata.
var _reserved := {}


## Crea una nave già orientata (vedi Airplane.create).
static func create(travel_direction: float, travel_speed: float) -> Ship:
	var ship := Ship.new()
	ship.speed = travel_speed
	ship.sync_to_physics = true
	ship.rotation.y = 0.0 if travel_direction > 0.0 else PI
	return ship


func _init() -> void:
	for column in COLUMNS:
		var levels := []
		levels.resize(ROWS)
		levels.fill(0)
		_levels.append(levels)


func _ready() -> void:
	collision_layer = 8 # piattaforme
	collision_mask = 0
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	Style.apply_palette(model)
	# Scafo, ponte di comando, prua col castello.
	_box(Vector3(37.0, 3.2, HALF_WIDTH * 2.0), Vector3(-1.5, DECK_Y - 1.6, 0.0))
	_box(Vector3(5.4, 8.4, HALF_WIDTH * 2.0), Vector3(-17.3, 4.8, 0.0))
	var bow := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for y in [-2.5, 3.5]:
		for corner in [Vector2(17, -5), Vector2(21.5, -1.2), Vector2(21.5, 1.2), Vector2(17, 5)]:
			points.append(Vector3(corner.x, y, corner.y))
	bow.points = points
	var bow_collision := CollisionShape3D.new()
	bow_collision.shape = bow
	add_child(bow_collision)
	Sfx.loop(self, &"ship_engine", 0.0, 1.0, 1.5)
	# Una nave su due si annuncia con la sirena.
	if randf() < 0.5:
		Sfx.play_at(&"ship_horn", global_position, 0.0, 1.0, 4.0)


## Secondi in cui la lingua-ancora la tiene ferma.
var anchored_left := 0.0

func _physics_process(delta: float) -> void:
	# Ancorata dalla lingua: ferma sul posto.
	if anchored_left > 0.0:
		anchored_left -= delta
		return
	position += transform.basis.x * speed * delta


## L'ancora della lingua: la nave si ferma per seconds secondi.
func anchor(seconds: float) -> void:
	anchored_left = seconds


func is_anchored() -> bool:
	return anchored_left > 0.0


## Velocità della nave nel mondo.
func motion_velocity() -> Vector3:
	return Vector3.ZERO if anchored_left > 0.0 else global_basis.x * speed


# --- Le caselle dei container ------------------------------------------------

## Il centro di un container nella casella, al piano dato (0 = sul ponte).
static func cell_position(cell: Vector2i, level: int) -> Vector3:
	var height := ShippingContainer.SIZE.y
	return Vector3(FIRST_COLUMN_X + cell.x * COLUMN_PITCH, DECK_Y + height / 2.0 + level * height, (cell.y - (ROWS - 1) / 2.0) * ROW_PITCH)


## La casella più vicina a un punto in coordinate della nave.
static func cell_at(local: Vector3) -> Vector2i:
	var column := clampi(roundi((local.x - FIRST_COLUMN_X) / COLUMN_PITCH), 0, COLUMNS - 1)
	var row := clampi(roundi(local.z / ROW_PITCH + (ROWS - 1) / 2.0), 0, ROWS - 1)
	return Vector2i(column, row)


## Vero se il punto (in coordinate della nave) cade dentro una casella, non
## sul castello o sul ponte di comando.
static func in_cargo_area(local: Vector3) -> bool:
	var half_column := COLUMN_PITCH / 2.0
	return local.x > FIRST_COLUMN_X - half_column and local.x < FIRST_COLUMN_X + (COLUMNS - 1) * COLUMN_PITCH + half_column and absf(local.z) < HALF_WIDTH


func level(cell: Vector2i) -> int:
	return _levels[cell.x][cell.y]


func reserve(cell: Vector2i) -> void:
	_reserved[cell] = Engine.get_physics_frames()


func release(cell: Vector2i) -> void:
	_reserved.erase(cell)


func is_reserved(cell: Vector2i) -> bool:
	return _reserved.has(cell) and Engine.get_physics_frames() - _reserved[cell] < RESERVATION_FRAMES


## Quante caselle hanno almeno un container (o stanno per averlo).
func filled_cells() -> int:
	var count := 0
	for column in COLUMNS:
		for row in ROWS:
			if _levels[column][row] > 0 or is_reserved(Vector2i(column, row)):
				count += 1
	return count


## Vero se sul ponte c'è un passaggio da un lato all'altro della nave tra le
## caselle vuote (senza contare quella in more, che si immagina piena).
func has_crossing(more := Vector2i(-1, -1)) -> bool:
	var open := func(cell: Vector2i) -> bool:
		return cell != more and _levels[cell.x][cell.y] == 0 and not is_reserved(cell)
	var queue: Array[Vector2i] = []
	var seen := {}
	for column in COLUMNS:
		var start := Vector2i(column, 0)
		if open.call(start):
			queue.append(start)
			seen[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		if cell.y == ROWS - 1:
			return true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if next.x < 0 or next.x >= COLUMNS or next.y < 0 or next.y >= ROWS or seen.has(next):
				continue
			if open.call(next):
				seen[next] = true
				queue.append(next)
	return false


## Una casella da caricare seguendo lo schema: finché le caselle piene sono
## meno di cap (da 0 a 1), una casella vuota che lasci un passaggio; poi un
## piano in più su una casella già piena. Mai la casella in avoid.
func loading_candidates(cap: float, avoid := Vector2i(-1, -1)) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var ground_floor := filled_cells() < roundi(cap * COLUMNS * ROWS)
	for column in COLUMNS:
		for row in ROWS:
			var cell := Vector2i(column, row)
			if cell == avoid or is_reserved(cell):
				continue
			var stack: int = _levels[column][row]
			if ground_floor and stack == 0 and has_crossing(cell):
				candidates.append(cell)
			elif not ground_floor and stack > 0 and stack < 2:
				candidates.append(cell)
	return candidates


## La nave arriva già in parte carica: fill è la quota di caselle piene.
func load_initial(fill: float) -> void:
	var cells: Array[Vector2i] = []
	for column in COLUMNS:
		for row in ROWS:
			cells.append(Vector2i(column, row))
	cells.shuffle()
	var wanted := roundi(fill * COLUMNS * ROWS)
	for cell in cells:
		if filled_cells() >= wanted:
			break
		if has_crossing(cell):
			add_container(cell, randi() % ShippingContainer.COLORS)
			if randf() < 0.3:
				add_container(cell, randi() % ShippingContainer.COLORS)


## Un container in più nella casella: diventa parte della nave.
func add_container(cell: Vector2i, color: int) -> void:
	var at := cell_position(cell, _levels[cell.x][cell.y])
	_levels[cell.x][cell.y] += 1
	var shape := BoxShape3D.new()
	# Il modello è lungo Z: sulla nave i container stanno per lungo, lungo X.
	shape.size = Vector3(ShippingContainer.SIZE.z, ShippingContainer.SIZE.y, ShippingContainer.SIZE.x)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	add_child(collision)
	var model: Node3D = ShippingContainer.MODEL.instantiate()
	model.position = at
	model.rotation.y = PI / 2.0
	add_child(model)
	Style.apply_palette(model, {"paint": "container_%d" % color})


## Un container caduto dalla gru tocca la nave: quando appoggia sopra la
## casella più vicina si ferma lì. Se la rana è rimasta sotto, viene spinta
## fuori di lato. Falso se non appoggia ancora (sfiora soltanto) o se la
## casella è già piena fino in cima.
func attach(container: ShippingContainer) -> bool:
	var local := to_local(container.global_position)
	var cell := cell_at(local)
	if _levels[cell.x][cell.y] >= MAX_STACK:
		return false
	# Solo appoggiato sopra la sua casella, non sfiorando una colonna vicina.
	if local.y > cell_position(cell, _levels[cell.x][cell.y]).y + 0.5:
		return false
	release(cell)
	add_container(cell, container.color_index)
	_push_out_frog(cell)
	return true


func _push_out_frog(cell: Vector2i) -> void:
	var frog := get_tree().get_first_node_in_group("frog") as Node3D
	if frog == null:
		return
	var center := cell_position(cell, _levels[cell.x][cell.y] - 1)
	var local := to_local(frog.global_position)
	var half := Vector3(ShippingContainer.SIZE.z, ShippingContainer.SIZE.y, ShippingContainer.SIZE.x) / 2.0
	var offset := local - center
	if absf(offset.x) > half.x + 0.3 or absf(offset.z) > half.z + 0.3 or absf(offset.y) > half.y + 0.5:
		return
	# Fuori dal lato lungo più vicino.
	local.z = center.z + signf(offset.z if offset.z != 0.0 else 1.0) * (half.z + 0.6)
	frog.global_position = to_global(local)


func _box(size: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	add_child(collision)
