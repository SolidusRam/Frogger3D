class_name Baggage
extends RigidBody3D
## Una valigia o un pacco. Viaggia ferma sul carrello di un trenino bagagli
## finché il getto di un aereo o un pugno non la porta via: da lì è un corpo
## fisico che vola. Fa male solo se arriva addosso alla rana veloce; a terra
## è un ostacolo leggero. Dopo un po' sparisce.

const KINDS := {
	"suitcase": {"model": preload("res://assets/models/suitcase.glb"), "size": Vector3(0.5, 0.3, 0.75), "mass": 20.0},
	"parcel": {"model": preload("res://assets/models/parcel.glb"), "size": Vector3(0.6, 0.5, 0.6), "mass": 14.0},
}
const LUGGAGE_COLORS := 4
## Oltre questo numero di bagagli liberi sparisce il più vecchio.
const MAX_LOOSE := 120
## Velocità data dal pugno base (30000 N·s): cresce coi potenziamenti.
const PUNCH_SPEED := 18.0
const PUNCH_IMPULSE := 30000.0

static var _loose: Array[Baggage] = []

var kind := "parcel"
var size := Vector3.ONE
## Dove finisce il bagaglio quando lascia il carrello (il raccordo): sparisce
## con lui quando il percorso lo elimina.
var home: Node
## Il trenino che la porta: lasciandolo ne tiene la velocità.
var carrier: BaggageTrain
## Vero finché sta sul carrello.
var loaded := true
var damage := 10
var knockback_speed := 8.0
## Fa male solo se va verso la rana almeno così veloce.
var min_harmful_speed := 6.0
var lifetime := 12.0

var _age := 0.0
var _model: Node3D
var _hitbox: Area3D
var _hit_cooldown := 0.0


static func random_kind() -> String:
	return "suitcase" if randf() < 0.55 else "parcel"


func _ready() -> void:
	var info: Dictionary = KINDS[kind]
	size = info.size
	mass = info.mass
	collision_layer = 4 # come i veicoli: il getto la vede, la rana ci sbatte
	collision_mask = 1 | 4 | 8
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = loaded
	continuous_cd = true
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	_model = info.model.instantiate()
	add_child(_model)
	Style.apply_palette(_model, {"paint": "luggage_%d" % (randi() % LUGGAGE_COLORS)})

	var hit_shape := BoxShape3D.new()
	hit_shape.size = size + Vector3.ONE * 0.3
	var hit_collision := CollisionShape3D.new()
	hit_collision.shape = hit_shape
	_hitbox = Area3D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2 # rana
	_hitbox.add_child(hit_collision)
	add_child(_hitbox)


func _physics_process(delta: float) -> void:
	if loaded:
		return
	_age += delta
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	if _hit_cooldown == 0.0:
		_hit_overlapping_frogs()
	if _age > lifetime or global_position.y < -10.0:
		_vanish()


## Il bagaglio lascia il carrello: diventa un corpo fisico libero con la
## velocità del trenino, un po' di sbandamento e di rotazione.
func release() -> void:
	if not loaded:
		return
	loaded = false
	reparent(home if is_instance_valid(home) else get_tree().current_scene)
	freeze = false
	var carried := carrier.velocity() if is_instance_valid(carrier) else Vector3.ZERO
	linear_velocity = carried + Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 3.0), randf_range(-2.5, 2.5))
	angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	_loose.append(self)
	tree_exiting.connect(_loose.erase.bind(self))
	if _loose.size() > MAX_LOOSE:
		_loose.pop_front()._vanish()


## Il pugno della rana: anche dal carrello, il bagaglio vola via.
func receive_punch(impulse: Vector3) -> void:
	release()
	linear_velocity = impulse.normalized() * PUNCH_SPEED * impulse.length() / PUNCH_IMPULSE
	# Chi l'ha appena preso a pugni non se lo vede tornare addosso.
	_hit_cooldown = 0.5


## Come per i veicoli: fa male solo se è il bagaglio ad andare addosso alla
## rana, e più in fretta di lei.
func _hit_overlapping_frogs() -> void:
	if linear_velocity.length() < min_harmful_speed:
		return
	for body in _hitbox.get_overlapping_bodies():
		var frog := body as Frog
		if frog == null:
			continue
		var toward_frog := (frog.global_position - global_position).normalized()
		var own_speed := linear_velocity.dot(toward_frog)
		var closing_speed := (linear_velocity - frog.velocity).dot(toward_frog)
		if own_speed >= min_harmful_speed and closing_speed >= min_harmful_speed:
			var push := Vector3(linear_velocity.x, 0.0, linear_velocity.z).normalized() * knockback_speed + Vector3.UP * 4.0
			Sfx.play_at(&"baggage_hit", global_position)
			frog.take_hit(damage, push)
			_hit_cooldown = 1.0


func _vanish() -> void:
	_loose.erase(self)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	freeze = true
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * 0.05, 0.4)
	tween.tween_callback(queue_free)
