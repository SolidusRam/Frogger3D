class_name Crocodile
extends Floater
## Un coccodrillo: la schiena è una piattaforma, la testa no. La bocca si apre a
## intervalli e morde la rana che ci si trova davanti.

const HEAD_LENGTH := 1.6

var bite_damage := 35
var open_duration := 1.2
var closed_duration := 2.8

var _mouth: Area3D
var _jaw: Node3D
var _mouth_open := false
var _cycle_time := 0.0


func _ready() -> void:
	# Ogni coccodrillo parte da un punto diverso del ciclo.
	_cycle_time = randf() * (open_duration + closed_duration)
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	_cycle_time = fmod(_cycle_time + delta, open_duration + closed_duration)
	_set_mouth_open(_cycle_time < open_duration)
	if _mouth_open:
		for body in _mouth.get_overlapping_bodies():
			if body is Frog:
				# Di lato, fuori dalla corrente: in avanti il coccodrillo, che va
				# alla stessa velocità dell'acqua, la raggiungerebbe di nuovo.
				var side := drift_velocity.normalized().cross(Vector3.UP)
				var side_sign := 1.0 if (body.global_position - global_position).dot(side) >= 0.0 else -1.0
				body.take_hit(bite_damage, side * side_sign * 6.0 + Vector3.UP * 6.0)


func _set_mouth_open(open: bool) -> void:
	if open == _mouth_open:
		return
	_mouth_open = open
	var tween := create_tween()
	tween.tween_property(_jaw, "rotation:x", deg_to_rad(40.0) if open else 0.0, 0.15)


## La collisione copre solo la schiena: sulla testa non si sta in piedi.
func _build() -> void:
	var body_length := size.z - HEAD_LENGTH
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, body_length)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.z = HEAD_LENGTH / 2.0
	add_child(collision)

	var back := MeshInstance3D.new()
	back.mesh = _box_mesh(Vector3(size.x, size.y, body_length), "croc")
	back.position.z = HEAD_LENGTH / 2.0
	add_child(back)

	var head_z := -size.z / 2.0 + HEAD_LENGTH / 2.0
	var lower_jaw := MeshInstance3D.new()
	lower_jaw.mesh = _box_mesh(Vector3(size.x * 0.7, size.y * 0.35, HEAD_LENGTH), "croc_dark")
	lower_jaw.position = Vector3(0.0, -size.y * 0.1, head_z)
	add_child(lower_jaw)

	# La mascella superiore ruota attorno al suo attacco posteriore.
	_jaw = Node3D.new()
	_jaw.position = Vector3(0.0, size.y * 0.1, head_z + HEAD_LENGTH / 2.0)
	add_child(_jaw)
	var upper_jaw := MeshInstance3D.new()
	upper_jaw.mesh = _box_mesh(Vector3(size.x * 0.7, size.y * 0.35, HEAD_LENGTH), "croc")
	upper_jaw.position.z = -HEAD_LENGTH / 2.0
	_jaw.add_child(upper_jaw)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = _box_mesh(Vector3(0.2, 0.2, 0.2), "croc_eye")
		eye.position = Vector3(side * size.x * 0.3, size.y * 0.55, -size.z / 2.0 + HEAD_LENGTH + 0.2)
		add_child(eye)

	var mouth_shape := BoxShape3D.new()
	mouth_shape.size = Vector3(size.x + 0.4, 2.0, HEAD_LENGTH + 0.8)
	var mouth_collision := CollisionShape3D.new()
	mouth_collision.shape = mouth_shape
	_mouth = Area3D.new()
	_mouth.collision_layer = 0
	_mouth.collision_mask = 2 # rana
	_mouth.position = Vector3(0.0, size.y * 0.5, head_z - 0.4)
	_mouth.add_child(mouth_collision)
	add_child(_mouth)
