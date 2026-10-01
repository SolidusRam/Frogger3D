class_name ShippingContainer
extends RigidBody3D
## Un container lasciato cadere da una gru. Mentre cade fa molto male alla
## rana; a terra diventa un ostacolo e una piattaforma, e se è su un nastro
## viene trascinato. Dopo un po' sprofonda e sparisce, come i rottami.

const MODEL := preload("res://assets/models/container.glb")
const COLORS := 4
const SIZE := Vector3(2.44, 2.6, 6.1)

var damage := 50
var lifetime := 20.0

var _age := 0.0
var _hitbox: Area3D
var _hit := false


func _ready() -> void:
	collision_layer = 4 # come i veicoli: la rana ci sbatte e ci sale sopra
	collision_mask = 1 | 4 | 8
	mass = 2500.0
	continuous_cd = true
	var shape := BoxShape3D.new()
	shape.size = SIZE
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	Style.apply_palette(model, {"paint": "container_%d" % (randi() % COLORS)})

	# Sotto il container: ferisce la rana solo mentre cade.
	var hit_shape := BoxShape3D.new()
	hit_shape.size = Vector3(SIZE.x + 0.4, 1.2, SIZE.z + 0.4)
	var hit_collision := CollisionShape3D.new()
	hit_collision.shape = hit_shape
	_hitbox = Area3D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2 # rana
	_hitbox.position.y = -SIZE.y / 2.0
	_hitbox.add_child(hit_collision)
	add_child(_hitbox)


func _physics_process(delta: float) -> void:
	_age += delta
	if not _hit and linear_velocity.y < -3.0:
		for body in _hitbox.get_overlapping_bodies():
			if body is Frog:
				_hit = true
				var away: Vector3 = body.global_position - global_position
				var push := (Vector3(away.x, 0.0, away.z).normalized() + Vector3.UP * 0.5).normalized() * 10.0
				body.take_hit(damage, push)
	if _age > lifetime:
		set_physics_process(false)
		collision_layer = 0
		collision_mask = 0
		freeze = true
		var tween := create_tween()
		tween.tween_property(self, "global_position:y", global_position.y - SIZE.y * 1.5, 1.0)
		tween.tween_callback(queue_free)
