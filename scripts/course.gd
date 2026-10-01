class_name Course
extends Node3D
## Il percorso infinito. Crea blocchi davanti alla rana (verso -Z) e cancella
## quelli rimasti dietro. Una sezione è una serie di ostacoli (strade e fiumi,
## separati da strisce sicure) che finisce con una tana; ogni sezione è più
## difficile della precedente.

signal den_reached(count: int, distance: float)

enum Kind { START, SAFE, ROAD, RIVER, RAIL, DEN }

const TREE := preload("res://assets/models/tree.glb")
const HOUSE := preload("res://assets/models/house.glb")
const LAMP := preload("res://assets/models/lamp.glb")


@export var frog: Frog
## Larghezza del terreno e mezza larghezza della zona di gioco (muri invisibili).
@export var ground_width := 120.0
@export var play_half_width := 37.0
## Quanti metri di percorso tenere pronti davanti e dietro la rana.
@export var look_ahead := 160.0
@export var keep_behind := 40.0

@export_group("Blocchi")
@export var start_depth := 30.0
@export var safe_depth := 6.0
@export var den_depth := 12.0
@export var road_lane_width := 4.0
@export var river_lane_width := 3.5
@export var rail_track_spacing := 4.5
## Massicciata e binari arrivano fino all'orizzonte: il treno si vede arrivare.
@export var rail_ground_width := 400.0

var dens_reached := 0
var best_distance := 0.0

## Sezione per cui si stanno creando i blocchi: decide la difficoltà.
var _planning_section := 0
var _plan: Array[Kind] = []
## Bordo verso cui si costruisce: il prossimo blocco parte da qui e va verso -Z.
var _front_z := 0.0
var _start_z := 0.0
var _chunks_created := 0


func _ready() -> void:
	_start_z = frog.global_position.z
	_front_z = _start_z + 10.0
	_add_chunk(Kind.START)


func _physics_process(_delta: float) -> void:
	while _front_z > frog.global_position.z - look_ahead:
		if _plan.is_empty():
			_plan_section()
		_add_chunk(_plan.pop_front())

	for chunk in get_children():
		var far_edge: float = chunk.get_meta("near_z") - chunk.get_meta("depth")
		if far_edge > frog.global_position.z + keep_behind:
			chunk.queue_free()

	best_distance = maxf(best_distance, _start_z - frog.global_position.z)


## Distanza percorsa dall'inizio, in metri.
func distance() -> float:
	return best_distance


func _plan_section() -> void:
	var obstacles := 2 + mini(_planning_section, 3) + randi_range(0, 1)
	for i in obstacles:
		_plan.append(_random_obstacle())
		_plan.append(Kind.SAFE)
	# L'ultima striscia sicura lascia il posto alla tana.
	_plan[_plan.size() - 1] = Kind.DEN
	_planning_section += 1


## Strada, fiume o, dalla seconda sezione, ferrovia.
func _random_obstacle() -> Kind:
	var roll := randf()
	if _planning_section >= 1 and roll < 0.2:
		return Kind.RAIL
	return Kind.ROAD if roll < 0.62 else Kind.RIVER


func _add_chunk(kind: Kind) -> void:
	var difficulty := _planning_section - 1 if kind != Kind.START else 0
	var chunk := Node3D.new()
	var depth := 0.0
	match kind:
		Kind.START:
			depth = start_depth
			_add_ground(chunk, depth, "grass")
		Kind.SAFE:
			depth = safe_depth
			_add_ground(chunk, depth, "grass")
		Kind.ROAD:
			var lanes := clampi(3 + difficulty + randi_range(-1, 1), 2, 7)
			depth = lanes * road_lane_width + 1.0
			_add_ground(chunk, depth, "sidewalk")
			var road := Road.new()
			road.lane_count = lanes
			road.lane_width = road_lane_width
			road.min_speed = minf(6.0 + difficulty * 0.7, 14.0)
			road.max_speed = minf(12.0 + difficulty * 0.9, 20.0)
			chunk.add_child(road)
		Kind.RIVER:
			var currents := clampi(3 + floori(difficulty / 2.0) + randi_range(-1, 1), 2, 6)
			depth = currents * river_lane_width
			var river := River.new()
			river.lane_count = currents
			river.lane_width = river_lane_width
			river.length = ground_width
			river.min_speed = minf(2.0 + difficulty * 0.3, 5.0) * Heat.river_speed_factor()
			river.max_speed = minf(5.0 + difficulty * 0.4, 8.0) * Heat.river_speed_factor()
			river.crocodile_chance = minf(0.2 + difficulty * 0.05, 0.5)
			chunk.add_child(river)
		Kind.RAIL:
			var tracks := clampi(1 + floori(difficulty / 2.0) + randi_range(0, 1), 1, 3)
			depth = tracks * rail_track_spacing + 2.0
			_add_ground(chunk, depth, "gravel", rail_ground_width)
			for i in tracks:
				var track := RailTrack.new()
				track.position.z = (i - (tracks - 1) / 2.0) * rail_track_spacing
				track.direction = 1.0 if randf() < 0.5 else -1.0
				track.length = rail_ground_width
				track.play_half_width = play_half_width
				chunk.add_child(track)
		Kind.DEN:
			depth = den_depth
			_add_ground(chunk, depth, "den_grass")
			_add_den(chunk, depth)

	_add_side_walls(chunk, depth)
	_add_props(chunk, kind, depth)
	chunk.position.z = _front_z - depth / 2.0
	chunk.set_meta("near_z", _front_z)
	chunk.set_meta("depth", depth)
	chunk.name = "%s_%d" % [Kind.keys()[kind], _chunks_created]
	_chunks_created += 1
	add_child(chunk)
	_front_z -= depth


func _add_ground(chunk: Node3D, depth: float, palette_key: String, width := -1.0) -> void:
	var size := Vector3(ground_width if width < 0.0 else width, 4.0, depth)
	var ground := StaticBody3D.new()
	ground.collision_mask = 0
	ground.position.y = -2.0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ground.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_mesh(size, palette_key)
	ground.add_child(mesh)
	chunk.add_child(ground)


## Muri invisibili ai lati: fermano la rana e i rottami, non i veicoli che
## guidano (sono cinematici e li attraversano).
func _add_side_walls(chunk: Node3D, depth: float) -> void:
	var walls := StaticBody3D.new()
	walls.collision_mask = 0
	for side in [-1.0, 1.0]:
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 40.0, depth)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(side * (play_half_width + 0.5), 16.0, 0.0)
		walls.add_child(collision)
	chunk.add_child(walls)


## Lo scenario ai lati, fuori dai muri invisibili: alberi sull'erba, case alla
## partenza e ogni tanto lungo il percorso, lampioni lungo le strade.
func _add_props(chunk: Node3D, kind: Kind, depth: float) -> void:
	var outside := play_half_width + 4.0
	var edge := ground_width / 2.0 - 3.0
	match kind:
		Kind.START, Kind.SAFE, Kind.DEN:
			for side in [-1.0, 1.0]:
				for i in maxi(1, floori(depth / 6.0)):
					var tree := _prop(chunk, TREE, Vector3(side * randf_range(outside, edge), 0.0, randf_range(-depth, depth) * 0.4))
					tree.rotation.y = randf() * TAU
					tree.scale = Vector3.ONE * randf_range(0.8, 1.3)
				if kind == Kind.START or randf() < 0.25:
					# Le case guardano verso il percorso.
					var house := _prop(chunk, HOUSE, Vector3(side * 50.0, 0.0, randf_range(-depth, depth) * 0.25))
					house.rotation.y = -PI / 2.0 * side
		Kind.ROAD:
			for side in [-1.0, 1.0]:
				var z := -depth / 2.0 + 2.0
				while z < depth / 2.0:
					# Il braccio del lampione punta verso la strada.
					var lamp := _prop(chunk, LAMP, Vector3(side * (play_half_width + 1.2), 0.0, z))
					lamp.rotation.y = 0.0 if side < 0.0 else PI
					z += 12.0


func _prop(chunk: Node3D, scene: PackedScene, at: Vector3) -> Node3D:
	var prop: Node3D = scene.instantiate()
	prop.position = at
	chunk.add_child(prop)
	Style.apply_palette(prop)
	return prop


## La tana: un portale su un prato. Entrarci registra il checkpoint.
func _add_den(chunk: Node3D, depth: float) -> void:
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.mesh = _box_mesh(Vector3(0.8, 6.0, 0.8), "gold")
		post.position = Vector3(side * 8.0, 3.0, 0.0)
		chunk.add_child(post)
	var bar := MeshInstance3D.new()
	bar.mesh = _box_mesh(Vector3(16.8, 0.8, 0.8), "gold")
	bar.position.y = 6.0
	chunk.add_child(bar)

	for x in [-20.0, -12.0, 12.0, 20.0]:
		var pad := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 2.0
		cylinder.bottom_radius = 2.0
		cylinder.height = 0.1
		cylinder.material = Style.material("pad")
		pad.mesh = cylinder
		pad.position = Vector3(x, 0.05, 0.0)
		chunk.add_child(pad)

	var trigger := Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2 # rana
	var shape := BoxShape3D.new()
	shape.size = Vector3(play_half_width * 2.0, 20.0, depth)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 10.0
	trigger.add_child(collision)
	trigger.body_entered.connect(_on_den_entered.bind(chunk), CONNECT_ONE_SHOT)
	chunk.add_child(trigger)


func _on_den_entered(body: Node3D, chunk: Node3D) -> void:
	if body is Frog:
		dens_reached += 1
		frog.set_respawn_point(Vector3(0.0, 0.1, chunk.global_position.z))
		den_reached.emit(dens_reached, distance())


static func _box_mesh(size: Vector3, palette_key: String) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Style.material(palette_key)
	return mesh
