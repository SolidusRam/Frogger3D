class_name Car
extends RigidBody3D
## Un veicolo del modello ibrido.
## DRIVING: RigidBody3D bloccato in modalità cinematica; guida lungo la corsia e
## frena se vede un altro veicolo davanti.
## WRECK: rottame fisico, libero. Se urta forte un veicolo che guida lo
## trasforma a sua volta in rottame: da questa sola regola nascono le catene.

signal wrecked(car: Car)

enum State { DRIVING, WRECK }

const COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2), Color(0.95, 0.75, 0.15), Color(0.2, 0.45, 0.85),
	Color(0.9, 0.5, 0.15), Color(0.6, 0.3, 0.75), Color(0.9, 0.9, 0.9),
]

## Larghezza, altezza e lunghezza. Il muso guarda verso -Z locale.
var size := Vector3(2.0, 1.4, 4.0)
## Direzione di marcia nel mondo e velocità di crociera, impostate dalla corsia.
var drive_direction := Vector3.RIGHT
var cruise_speed := 8.0
var state := State.DRIVING

## Frenata e accelerazione in m/s². Con meno frenata ci sono più incidenti.
var braking := 12.0
var acceleration := 6.0
## Distanza a cui si ferma dietro un ostacolo.
var safe_gap := 2.0

## Danno inflitto alla rana e velocità con cui viene sbalzata.
var hit_damage := 25
var knockback_speed := 12.0
## Sotto questa velocità il veicolo non fa danno.
var min_harmful_speed := 2.0
## Velocità relativa oltre la quale un urto trasforma un veicolo in rottame.
var crash_speed := 4.0
## Secondi dopo i quali un rottame sprofonda e sparisce.
var wreck_lifetime := 25.0

var _speed := 0.0
var _hitbox: Area3D
var _look_ahead: ShapeCast3D
var _paint: StandardMaterial3D
## Tempo in cui il rottame appena colpito dalla rana non può ferirla.
var _frog_grace := 0.0
var _wreck_age := 0.0


func _ready() -> void:
	collision_layer = 4 # veicoli
	collision_mask = 1 | 4 | 8 # terreno, veicoli, piattaforme
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	continuous_cd = true
	mass = 300.0 * size.x * size.z
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	physics_material_override.bounce = 0.1
	_speed = cruise_speed
	_build_collision()
	_build_visual()
	_build_hitbox()
	_build_look_ahead()


func _physics_process(delta: float) -> void:
	match state:
		State.DRIVING:
			_drive(delta)
		State.WRECK:
			_frog_grace = maxf(_frog_grace - delta, 0.0)
			_wreck_age += delta
			if _wreck_age > wreck_lifetime or global_position.y < -10.0:
				_sink_and_free()
	_hit_overlapping_frogs()


## Velocità reale del veicolo, sia che guidi sia che sia un rottame.
func motion_velocity() -> Vector3:
	return drive_direction * _speed if state == State.DRIVING else linear_velocity


func become_wreck() -> void:
	if state == State.WRECK:
		return
	state = State.WRECK
	var velocity_before := motion_velocity()
	_look_ahead.enabled = false
	freeze = false
	linear_velocity = velocity_before
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_wreck_body_entered)
	_paint.albedo_color = _paint.albedo_color.darkened(0.45)
	wrecked.emit(self)


## Il pugno della rana: il veicolo diventa un rottame e vola via.
func receive_punch(impulse: Vector3) -> void:
	become_wreck()
	_frog_grace = 0.5
	# Colpito un po' sopra il centro, così oltre a volare gira su se stesso.
	apply_impulse(impulse, Vector3.UP * size.y * 0.3)


func _drive(delta: float) -> void:
	var target_speed := cruise_speed
	if _look_ahead.is_colliding():
		var distance := _look_ahead.get_closest_collision_safe_fraction() * _look_ahead.target_position.length()
		var stop_speed := sqrt(2.0 * braking * maxf(distance - safe_gap, 0.0))
		var ahead_speed := 0.0
		var ahead := _look_ahead.get_collider(0) as Car
		if ahead:
			ahead_speed = maxf(ahead.motion_velocity().dot(drive_direction), 0.0)
		target_speed = minf(cruise_speed, maxf(ahead_speed, stop_speed))
	var rate := braking if target_speed < _speed else acceleration
	_speed = move_toward(_speed, target_speed, rate * delta)
	global_position += drive_direction * _speed * delta


func _on_wreck_body_entered(body: Node) -> void:
	var other := body as Car
	if other and other.state == State.DRIVING:
		if (linear_velocity - other.motion_velocity()).length() > crash_speed:
			other.become_wreck()


## Conta la velocità rispetto alla rana: chi viaggia insieme al veicolo, sopra
## o accanto, non si fa male. Fa male solo se si avvicina, non se si allontana.
func _hit_overlapping_frogs() -> void:
	if _frog_grace > 0.0:
		return
	for body in _hitbox.get_overlapping_bodies():
		var frog := body as Frog
		if frog == null:
			continue
		var relative := motion_velocity() - frog.velocity
		if relative.length() >= min_harmful_speed and relative.dot(frog.global_position - global_position) > 0.0:
			frog.take_hit(hit_damage, _knockback_for(frog, relative))


## Sbalza la rana soprattutto di lato, fuori dalla corsia: se venisse spinta solo
## in avanti il veicolo la raggiungerebbe e la colpirebbe di nuovo.
func _knockback_for(frog: Node3D, velocity: Vector3) -> Vector3:
	var forward := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var side_sign := signf((frog.global_position - global_position).dot(side))
	if side_sign == 0.0:
		side_sign = 1.0 if randf() < 0.5 else -1.0
	var direction := (forward * 0.5 + side * side_sign).normalized()
	return direction * knockback_speed + Vector3.UP * 5.0


func _sink_and_free() -> void:
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	freeze = true
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - size.y * 1.5, 1.0)
	tween.tween_callback(queue_free)


func _build_collision() -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	_paint = StandardMaterial3D.new()
	_paint.albedo_color = COLORS.pick_random()
	var body := MeshInstance3D.new()
	body.mesh = _box_mesh(size, _paint)
	add_child(body)

	# Parabrezza scuro sul muso, per capire da che parte va il veicolo.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.12, 0.15)
	var windshield := MeshInstance3D.new()
	windshield.mesh = _box_mesh(Vector3(size.x * 0.9, size.y * 0.35, 0.1), glass)
	windshield.position = Vector3(0.0, size.y * 0.2, -size.z / 2.0 - 0.02)
	add_child(windshield)


## Area che rileva la rana ai lati e davanti, ma non sul tetto: stare sopra un
## veicolo non fa danno.
func _build_hitbox() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x + 0.3, size.y - 0.3, size.z + 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.15
	_hitbox = Area3D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2 # rana
	_hitbox.add_child(collision)
	add_child(_hitbox)


## Sensore davanti al muso, lungo quanto serve per fermarsi da velocità di
## crociera. Vede solo i veicoli: per la rana non si frena.
func _build_look_ahead() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x * 0.8, size.y * 0.5, 0.5)
	_look_ahead = ShapeCast3D.new()
	_look_ahead.shape = shape
	_look_ahead.collision_mask = 4 # veicoli
	_look_ahead.position = Vector3(0.0, 0.0, -size.z / 2.0 - 0.3)
	var length := cruise_speed * cruise_speed / (2.0 * braking) + safe_gap + 1.0
	_look_ahead.target_position = Vector3(0.0, 0.0, -length)
	add_child(_look_ahead)


static func _box_mesh(box_size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	return mesh
