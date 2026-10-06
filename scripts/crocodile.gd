class_name Crocodile
extends Floater
## Un coccodrillo: la schiena è una piattaforma, la testa no. La bocca si apre a
## intervalli e morde la rana che ci si trova davanti.

const HEAD_LENGTH := 1.6
const MODEL := preload("res://assets/models/crocodile.glb")

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
			# Chi è immerso col tuffo passa sotto la bocca.
			if body is Frog and not body.submerged:
				# Di lato, fuori dalla corrente: in avanti il coccodrillo, che va
				# alla stessa velocità dell'acqua, la raggiungerebbe di nuovo.
				var side := drift_velocity.normalized().cross(Vector3.UP)
				var side_sign := 1.0 if (body.global_position - global_position).dot(side) >= 0.0 else -1.0
				Feats.note(&"croc_bite")
				body.take_hit(bite_damage, side * side_sign * 6.0 + Vector3.UP * 6.0)


func _set_mouth_open(open: bool) -> void:
	if open == _mouth_open:
		return
	_mouth_open = open
	# Si sente solo il coccodrillo vicino: un fiume pieno sarebbe un cantiere.
	var frog := get_tree().get_first_node_in_group("frog") as Node3D
	if frog and frog.global_position.distance_to(global_position) < 18.0:
		Sfx.play_at(&"croc_open" if open else &"croc_snap", global_position)
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

	# Il modello (build_crocodile): la mascella superiore è il nodo Jaw.
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	Style.apply_palette(model)
	_jaw = model.get_node("Jaw")

	var head_z := -size.z / 2.0 + HEAD_LENGTH / 2.0
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
