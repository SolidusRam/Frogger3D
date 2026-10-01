class_name Taxiway
extends Node3D
## Un raccordo dell'aeroporto: asfalto con le linee gialle e gli aerei che
## rullano lenti, uno dopo l'altro. Gli aerei sono enormi e si vedono
## arrivare: non serve un avviso. Corre lungo l'asse X locale.

var direction := 1.0
var length := 400.0
var play_half_width := 37.0
var min_interval := 9.0
var max_interval := 15.0
## Velocità base; il calore la alza fino al +30%.
var base_speed := 7.0
var max_heat_bonus := 0.3

var _timer := 0.0


func _ready() -> void:
	_build_markings()
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
