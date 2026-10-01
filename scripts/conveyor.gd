class_name Conveyor
extends StaticBody3D
## Un nastro trasportatore del porto: un "fiume di terra". Chi ci sta sopra
## (rana, container, rottami) viene portato di lato. Corre lungo l'asse X
## locale; direction indica il verso.

const WIDTH := 3.0
const HEIGHT := 0.3
const SLAT_SPACING := 1.2

var direction := 1.0
var speed := 4.0
var length := 90.0

var _slats: MultiMesh
var _offset := 0.0


func _ready() -> void:
	collision_layer = 1 # terreno
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, HEIGHT, WIDTH)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = HEIGHT / 2.0
	add_child(collision)

	var belt := MeshInstance3D.new()
	belt.mesh = _box(Vector3(length, HEIGHT, WIDTH), "belt")
	belt.position.y = HEIGHT / 2.0
	add_child(belt)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.mesh = _box(Vector3(length, 0.4, 0.2), "crane")
		rail.position = Vector3(0.0, 0.2, side * (WIDTH / 2.0 + 0.1))
		add_child(rail)

	# Listelli che scorrono: fanno vedere verso dove porta il nastro.
	_slats = MultiMesh.new()
	_slats.transform_format = MultiMesh.TRANSFORM_3D
	_slats.mesh = _box(Vector3(0.25, 0.04, WIDTH - 0.2), "trim")
	_slats.instance_count = floori(length / SLAT_SPACING)
	var slats_instance := MultiMeshInstance3D.new()
	slats_instance.multimesh = _slats
	add_child(slats_instance)


func _physics_process(delta: float) -> void:
	# Velocità costante della superficie: Godot la passa a chi ci sta sopra.
	constant_linear_velocity = global_basis.x.normalized() * direction * speed
	_offset = fmod(_offset + speed * delta, SLAT_SPACING)
	for i in _slats.instance_count:
		var x := -length / 2.0 + i * SLAT_SPACING + _offset * direction
		_slats.set_instance_transform(i, Transform3D(Basis(), Vector3(x, HEIGHT + 0.02, 0.0)))


static func _box(size: Vector3, palette_key: String) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Style.material(palette_key)
	return mesh
