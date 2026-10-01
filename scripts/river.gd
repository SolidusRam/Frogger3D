class_name River
extends Node3D
## Un tratto di fiume: un canale largo lane_count correnti, con il letto in
## fondo e l'acqua in superficie. Le correnti corrono lungo X e si susseguono
## lungo Z. L'acqua fa galleggiare i rottami e li trascina con la corrente.
## Le sponde sono il terreno ai due lati del canale, fuori da questa scena.

@export var lane_count := 4
@export var lane_width := 3.5
@export var length := 120.0
@export var min_speed := 2.0
@export var max_speed := 5.0
@export var crocodile_chance := 0.25
## Quota della superficie rispetto alle sponde (che stanno a 0).
@export var water_level := -0.4
@export var depth := 3.0

@export_group("Galleggiamento dei rottami")
## Oltre 1 il rottame galleggia: a 2 resta immerso per circa metà.
@export var buoyancy := 2.0
@export var water_drag := 1.5
@export var angular_drag := 2.0
## Quanto in fretta la corrente porta un rottame alla sua velocità.
@export var current_pull := 1.0

var _lanes: Array[RiverLane] = []
var _water: Area3D


func _ready() -> void:
	_build_bed_and_water()
	for i in lane_count:
		var lane := RiverLane.new()
		lane.position.z = _lane_offset(i)
		lane.direction = 1.0 if i % 2 == 0 else -1.0
		lane.speed = randf_range(min_speed, max_speed)
		lane.half_length = length / 2.0 - 12.0
		lane.float_height = water_level + 0.1
		lane.crocodile_chance = crocodile_chance
		add_child(lane)
		_lanes.append(lane)


func _physics_process(_delta: float) -> void:
	for body in _water.get_overlapping_bodies():
		var wreck := body as Car
		if wreck and wreck.state == Car.State.WRECK:
			_float(wreck)


## Quota della superficie nel mondo.
func surface_y() -> float:
	return global_position.y + water_level


## Velocità della corrente nel punto dato (zero fuori dalle correnti).
func current_at(point: Vector3) -> Vector3:
	var local_z := to_local(point).z
	for i in lane_count:
		if absf(local_z - _lane_offset(i)) <= lane_width / 2.0:
			var lane := _lanes[i]
			return global_basis.x.normalized() * lane.direction * lane.speed
	return Vector3.ZERO


func _float(wreck: Car) -> void:
	wreck.mark_floating()
	# Ingombro verticale reale: un'auto su un fianco è alta quanto è larga.
	var b := wreck.global_basis
	var height := absf(b.x.y) * wreck.size.x + absf(b.y.y) * wreck.size.y + absf(b.z.y) * wreck.size.z
	var bottom := wreck.global_position.y - height / 2.0
	var submerged := clampf((surface_y() - bottom) / height, 0.0, 1.0)
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	var force := Vector3.UP * wreck.mass * gravity * buoyancy * submerged
	force -= wreck.linear_velocity * wreck.mass * water_drag * submerged
	var current := current_at(wreck.global_position)
	var horizontal := Vector3(wreck.linear_velocity.x, 0.0, wreck.linear_velocity.z)
	force += (current - horizontal) * wreck.mass * current_pull * submerged
	wreck.apply_central_force(force)
	wreck.apply_torque(-wreck.angular_velocity * wreck.mass * angular_drag * submerged)


func _lane_offset(index: int) -> float:
	return (index - (lane_count - 1) / 2.0) * lane_width


func _build_bed_and_water() -> void:
	var width := lane_count * lane_width

	var bed := StaticBody3D.new()
	bed.collision_mask = 0
	bed.position.y = -depth - 0.5
	var bed_shape := BoxShape3D.new()
	bed_shape.size = Vector3(length, 1.0, width)
	var bed_collision := CollisionShape3D.new()
	bed_collision.shape = bed_shape
	bed.add_child(bed_collision)
	add_child(bed)

	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.15, 0.4, 0.7, 0.75)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var surface := MeshInstance3D.new()
	var surface_mesh := BoxMesh.new()
	surface_mesh.size = Vector3(length, 0.05, width)
	surface_mesh.material = water_material
	surface.mesh = surface_mesh
	surface.position.y = water_level
	add_child(surface)

	# L'area dell'acqua arriva poco sotto la superficie: chi sta su un tronco
	# non la tocca, chi galleggia sì.
	_water = Area3D.new()
	_water.collision_layer = 16 # acqua
	_water.collision_mask = 2 | 4 # rana, veicoli
	var water_shape := BoxShape3D.new()
	water_shape.size = Vector3(length, depth, width)
	var water_collision := CollisionShape3D.new()
	water_collision.shape = water_shape
	_water.add_child(water_collision)
	_water.position.y = water_level - 0.1 - depth / 2.0
	_water.body_entered.connect(_on_body_entered)
	_water.body_exited.connect(_on_body_exited)
	add_child(_water)


func _on_body_entered(body: Node3D) -> void:
	if body is Frog:
		body.enter_water(self)


func _on_body_exited(body: Node3D) -> void:
	if body is Frog:
		body.exit_water(self)
