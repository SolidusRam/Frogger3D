class_name Taxiway
extends Node3D
## Un raccordo dell'aeroporto: asfalto con le linee gialle e gli aerei che
## rullano lenti, uno dopo l'altro. Gli aerei sono enormi e si vedono
## arrivare: non serve un avviso. Sotto i motori corrono due strade di
## servizio: i mezzi che le percorrono finiscono contro i motori e il getto li
## scaglia all'indietro, addosso a chi attraversa dietro l'aereo. Corre lungo
## l'asse X locale.

var direction := 1.0
var length := 400.0
var play_half_width := 37.0
var min_interval := 9.0
var max_interval := 15.0
## Velocità base; il calore la alza fino al +30%.
var base_speed := 7.0
var max_heat_bonus := 0.3
## Strade di servizio sotto i motori: velocità dei mezzi e spazio tra l'uno e
## l'altro (pochi: il getto ne fa già abbastanza).
var service_min_speed := 5.0
var service_max_speed := 9.0
var service_min_gap := 30.0
var service_max_gap := 60.0
const SERVICE_LANE_WIDTH := 4.0

var _timer := 0.0


func _ready() -> void:
	_build_markings()
	for side in [-1.0, 1.0]:
		_add_service_lane(side * Airplane.ENGINE_X)
	# All'inizio un aereo è già in arrivo, poco fuori dalla zona di gioco.
	_send_plane(-direction * (play_half_width + Airplane.LENGTH))
	_timer = randf_range(min_interval, max_interval)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_send_plane(-direction * (play_half_width + 60.0))
		_timer = randf_range(min_interval, max_interval)
	for child in get_children():
		var plane := child as Airplane
		if plane and plane.tail_x() * direction > play_half_width + 60.0:
			plane.queue_free()


func _send_plane(x: float) -> void:
	var plane := Airplane.create(direction, base_speed * (1.0 + max_heat_bonus * Heat.ratio()))
	plane.position.x = x
	add_child(plane)


func _add_service_lane(z: float) -> void:
	var road := MeshInstance3D.new()
	road.mesh = _box(Vector3(length, 0.02, SERVICE_LANE_WIDTH), "asphalt")
	road.position = Vector3(0.0, 0.01, z)
	add_child(road)
	for side in [-1.0, 1.0]:
		var line := MeshInstance3D.new()
		line.mesh = _box(Vector3(length, 0.02, 0.12), "lane_line")
		line.position = Vector3(0.0, 0.025, z + side * SERVICE_LANE_WIDTH / 2.0)
		add_child(line)
	var lane := Lane.new()
	lane.position.z = z
	lane.direction = 1.0 if randf() < 0.5 else -1.0
	lane.speed = randf_range(service_min_speed, service_max_speed)
	lane.half_length = play_half_width
	lane.min_gap = service_min_gap
	lane.max_gap = service_max_gap
	add_child(lane)


func _build_markings() -> void:
	var line := MeshInstance3D.new()
	line.mesh = _box(Vector3(length, 0.02, 0.35), "taxi_line")
	line.position.y = 0.02
	add_child(line)
	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		edge.mesh = _box(Vector3(length, 0.02, 0.2), "taxi_line")
		edge.position = Vector3(0.0, 0.02, side * 14.0)
		add_child(edge)


static func _box(size: Vector3, palette_key: String) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Style.material(palette_key)
	return mesh
