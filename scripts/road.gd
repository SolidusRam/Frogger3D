class_name Road
extends Node3D
## Un tratto di strada: asfalto, strisce e corsie con versi alterni. Le corsie
## corrono lungo X e si susseguono lungo Z, la direzione in cui avanza la rana.

@export var lane_count := 4
@export var lane_width := 4.0
@export var length := 70.0
@export var min_speed := 6.0
@export var max_speed := 12.0


func _ready() -> void:
	_build_asphalt()
	for i in lane_count:
		var lane := Lane.new()
		lane.position.z = _lane_offset(i)
		lane.direction = 1.0 if i % 2 == 0 else -1.0
		lane.speed = randf_range(min_speed, max_speed)
		lane.half_length = length / 2.0
		add_child(lane)


func _lane_offset(index: int) -> float:
	return (index - (lane_count - 1) / 2.0) * lane_width


func _build_asphalt() -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.18, 0.18, 0.2)
	var road := MeshInstance3D.new()
	road.mesh = _box_mesh(Vector3(length, 0.02, lane_count * lane_width), asphalt)
	road.position.y = 0.01
	add_child(road)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.9, 0.9, 0.85)
	for i in lane_count - 1:
		var line := MeshInstance3D.new()
		line.mesh = _box_mesh(Vector3(length, 0.02, 0.15), paint)
		line.position = Vector3(0.0, 0.02, (_lane_offset(i) + _lane_offset(i + 1)) / 2.0)
		add_child(line)


static func _box_mesh(box_size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	return mesh
