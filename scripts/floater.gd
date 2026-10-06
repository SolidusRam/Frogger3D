class_name Floater
extends AnimatableBody3D
## Base per ciò che scorre sul fiume (tronchi, coccodrilli): si muove a
## velocità costante e trasporta chi ci sta sopra.

## Larghezza, altezza e lunghezza. La parte anteriore guarda verso -Z locale.
var size := Vector3(1.6, 1.0, 8.0)
var drift_velocity := Vector3.ZERO
## L'ancora della lingua: fermo sul posto per qualche secondo.
var anchored_left := 0.0


func _ready() -> void:
	collision_layer = 8 # piattaforme
	collision_mask = 0
	sync_to_physics = true
	_build()


func _physics_process(delta: float) -> void:
	if _held(delta):
		return
	global_position += drift_velocity * delta


## L'ancora della lingua: per seconds secondi non scorre più.
func anchor(seconds: float) -> void:
	anchored_left = seconds


func is_anchored() -> bool:
	return anchored_left > 0.0


## Vero (e conta il tempo) mentre l'ancora lo tiene fermo.
func _held(delta: float) -> bool:
	if anchored_left <= 0.0:
		return false
	anchored_left -= delta
	return true


## Costruisce collisione e grafica; le sottoclassi lo estendono.
func _build() -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


## Un parallelepipedo col materiale condiviso della voce di tavolozza data.
static func _box_mesh(box_size: Vector3, palette_key: String) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = Style.material(palette_key)
	return mesh
