class_name Backdrop
extends Node3D
## Lo sfondo: montagne all'orizzonte e una pianura sotto l'altopiano di gioco.
## Segue la rana lungo Z, così l'orizzonte resta sempre lontano. La
## disposizione è sempre la stessa (seme fisso): un paesaggio riconoscibile.

const MOUNTAIN := preload("res://assets/models/mountain.glb")

@export var frog: Node3D
@export var mountain_count := 18
@export var min_distance := 190.0
@export var max_distance := 280.0
## Quanto la pianura sta sotto il piano di gioco (sotto il letto dei fiumi).
@export var plain_depth := 4.5


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in mountain_count:
		var angle := TAU * i / mountain_count + rng.randf_range(-0.12, 0.12)
		var distance := rng.randf_range(min_distance, max_distance)
		var mountain: Node3D = MOUNTAIN.instantiate()
		add_child(mountain)
		Style.apply_palette(mountain)
		mountain.position = Vector3(sin(angle) * distance, -plain_depth, cos(angle) * distance)
		mountain.rotation.y = rng.randf() * TAU
		var scale_xz := rng.randf_range(0.7, 1.6)
		mountain.scale = Vector3(scale_xz, scale_xz * rng.randf_range(0.8, 1.3), scale_xz)

	var plain := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200.0, 1200.0)
	plane.material = Style.material("far_ground")
	plain.mesh = plane
	plain.position.y = -plain_depth
	add_child(plain)


func _process(_delta: float) -> void:
	global_position = Vector3(0.0, 0.0, frog.global_position.z)
