class_name Port
extends Node3D
## Il porto: una banchina, una o due corsie d'acqua con le navi portacontainer
## e le loro gru, e una banchina sicura dall'altra parte; tra due corsie c'è
## un molo. L'acqua è ferma e ha le regole del fiume. Il blocco va da +Z (dove
## arriva la rana) a -Z.

const NEAR_QUAY := 6.0
const WATER := 14.0
const PIER := 5.0
const FAR_QUAY := 4.0
const EDGE := 0.35

var lanes := 1
var difficulty := 0
var length := 400.0
var play_half_width := 37.0


static func depth_for(lane_count: int) -> float:
	return NEAR_QUAY + lane_count * WATER + (lane_count - 1) * PIER + FAR_QUAY


func _ready() -> void:
	var z := depth_for(lanes) / 2.0
	_quay(z, NEAR_QUAY)
	z -= NEAR_QUAY
	var first_direction := 1.0 if randf() < 0.5 else -1.0
	for i in lanes:
		var center := z - WATER / 2.0
		var water := River.new()
		water.still = true
		water.lane_count = 1
		water.lane_width = WATER
		water.length = length
		water.position.z = center
		add_child(water)
		var lane := ShipLane.new()
		lane.position.z = center
		# Due corsie: navi in versi opposti.
		lane.direction = first_direction * (1.0 if i % 2 == 0 else -1.0)
		lane.speed = randf_range(3.0, 5.0)
		lane.play_half_width = play_half_width
		lane.initial_fill = minf(0.2 + 0.05 * difficulty, 0.45)
		lane.loading_cap = minf(0.4 + 0.04 * difficulty, 0.6)
		add_child(lane)
		z -= WATER
		if i < lanes - 1:
			_quay(z, PIER)
			z -= PIER
	_quay(z, FAR_QUAY)


## Una banchina di cemento che va da near_z verso -Z, con il bordo giallo
## sull'acqua.
func _quay(near_z: float, depth: float) -> void:
	var ground := StaticBody3D.new()
	ground.collision_mask = 0
	ground.position = Vector3(0.0, -2.0, near_z - depth / 2.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 4.0, depth)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ground.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box(Vector3(length, 4.0, depth), "concrete")
	ground.add_child(mesh)
	add_child(ground)
	var far_edge := near_z - depth
	var depth_total := depth_for(lanes)
	for edge_z in [near_z, far_edge]:
		# Solo i bordi sull'acqua, non quelli verso il resto del percorso.
		if absf(edge_z) >= depth_total / 2.0 - 0.01:
			continue
		var line := MeshInstance3D.new()
		line.mesh = _box(Vector3(length, 0.02, EDGE), "taxi_line")
		line.position = Vector3(0.0, 0.01, edge_z - signf(edge_z - (near_z - depth / 2.0)) * EDGE / 2.0)
		add_child(line)


static func _box(size: Vector3, palette_key: String) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Style.material(palette_key)
	return mesh
