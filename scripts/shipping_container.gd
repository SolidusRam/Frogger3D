class_name ShippingContainer
extends RigidBody3D
## Un container lasciato cadere da una gru. Mentre cade fa molto male alla
## rana. Se tocca una nave ci resta, nella casella più vicina (vedi
## Ship.attach); se cade in acqua affonda; a terra diventa un ostacolo e una
## piattaforma, poi sprofonda e sparisce, come i rottami.

const MODEL := preload("res://assets/models/container.glb")
const COLORS := 4
const SIZE := Vector3(2.44, 2.6, 6.1)

var damage := 50
var lifetime := 20.0
## Colore nella tavolozza (container_N); -1 lo sceglie a caso.
var color_index := -1
## Sotto questa quota il centro è in acqua: il container affonda.
var sink_y := -0.9

var _age := 0.0
var _hitbox: Area3D
var _hit := false
var _gone := false
## La nave che il container sta toccando (sotto o di lato).
var _ship: Ship


var _landed := false


func _ready() -> void:
	collision_layer = 4 # come i veicoli: la rana ci sbatte e ci sale sopra
	collision_mask = 1 | 4 | 8
	mass = 2500.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if color_index < 0:
		color_index = randi() % COLORS
	var shape := BoxShape3D.new()
	# Un filo più stretto del modello: cadendo fra due colonne di container
	# (a 6 cm l'una dall'altra) non le sfrega.
	shape.size = SIZE - Vector3(0.2, 0.0, 0.2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	Style.apply_palette(model, {"paint": "container_%d" % color_index})

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
	if _gone:
		return
	_check_frog_hit()
	# Appoggiato sulla nave: diventa parte della nave (Ship.attach dice di no
	# finché non è davvero sopra la sua casella).
	if is_instance_valid(_ship) and _ship.attach(self):
		_gone = true
		queue_free()
		return
	if global_position.y < sink_y or _age > lifetime:
		_sink()


## Mentre cade, chi sta sotto viene colpito e sbalzato di lato.
func _check_frog_hit() -> void:
	if _hit or linear_velocity.y >= -3.0:
		return
	for body in _hitbox.get_overlapping_bodies():
		if body is Frog:
			_hit = true
			var away: Vector3 = body.global_position - global_position
			var push := (Vector3(away.x, 0.0, away.z).normalized() + Vector3.UP * 0.5).normalized() * 10.0
			body.take_hit(damage, push)


func _on_body_entered(body: Node) -> void:
	# Il primo urto è il gong: la lamiera che cade sulla nave o sul molo.
	if not _landed:
		_landed = true
		Sfx.play_at(&"container_land", global_position, 0.0, 1.0, 2.5)
	if body is Ship:
		_ship = body


func _on_body_exited(body: Node) -> void:
	if body == _ship:
		_ship = null


func _sink() -> void:
	_gone = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	freeze = true
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - SIZE.y * 1.5, 1.0)
	tween.tween_callback(queue_free)
