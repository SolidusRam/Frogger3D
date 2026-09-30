class_name Floater
extends AnimatableBody3D
## Base per ciò che scorre sul fiume (tronchi, coccodrilli): si muove a
## velocità costante e trasporta chi ci sta sopra.

## Larghezza, altezza e lunghezza. La parte anteriore guarda verso -Z locale.
var size := Vector3(1.6, 1.0, 8.0)
var drift_velocity := Vector3.ZERO


func _ready() -> void:
	collision_layer = 8 # piattaforme
	collision_mask = 0
	sync_to_physics = true
	_build()


func _physics_process(delta: float) -> void:
	global_position += drift_velocity * delta


## Costruisce collisione e grafica; le sottoclassi lo estendono.
func _build() -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


static func _box_mesh(box_size: Vector3, color: Color) -> BoxMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	return mesh
