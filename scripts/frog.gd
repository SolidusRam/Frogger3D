class_name Frog
extends CharacterBody3D
## La rana: movimento libero relativo alla telecamera, salto con coyote time e
## buffer, saltelli solo visivi mentre cammina, vita e colpi subiti, nuoto.
## Poteri: pugno, super salto e deltaplano.

signal health_changed(health: int, max_health: int)
signal died
## Emesso a ogni pugno andato a segno, con i veicoli colpiti.
signal punched(cars: Array[Car])
## Emesso a ogni uso di un potere (&"punch", &"super_jump", &"glide"): servirà
## al calore.
signal power_used(power: StringName)

@export_group("Movimento")
@export var move_speed := 7.0
@export var ground_acceleration := 45.0
@export var air_acceleration := 15.0
@export var turn_speed := 14.0

@export_group("Salto")
## Altezza massima del salto normale, in metri.
@export var jump_height := 1.8
@export var jump_time_to_peak := 0.35
@export var jump_time_to_fall := 0.28
## Tempo dopo aver lasciato il bordo in cui si può ancora saltare.
@export var coyote_time := 0.1
## Tempo in cui un salto premuto troppo presto viene ricordato.
@export var jump_buffer_time := 0.12

@export_group("Saltelli")
@export var hop_height := 0.25
@export var hops_per_second := 3.0

@export_group("Pugno")
## Distanza e raggio della zona colpita davanti alla rana.
@export var punch_reach := 1.3
@export var punch_radius := 1.2
## Spinta del pugno in N·s: un'auto (2400 kg) parte a circa 12 m/s, un camion
## (5760 kg) a circa 5.
@export var punch_impulse := 30000.0
## Quanto il pugno solleva il veicolo, rispetto alla spinta orizzontale.
@export var punch_lift := 0.35
@export var punch_cooldown := 0.4

@export_group("Super salto")
@export var super_jump_height := 5.0
## Velocità orizzontale data dal super salto.
@export var super_jump_boost := 9.0
@export var super_jump_cooldown := 2.5
## Controllo in aria durante il super salto: si sterza senza perdere slancio.
@export var super_air_acceleration := 6.0

@export_group("Deltaplano")
@export var glide_speed := 10.0
@export var glide_acceleration := 12.0
## Velocità massima di discesa col deltaplano aperto.
@export var glide_fall_speed := 2.0
## Secondi di volo con la carica piena; si ricarica stando a terra.
@export var glide_duration := 2.5
@export var glide_recharge_per_second := 1.0
## Sotto questa altezza dal suolo, Spazio in aria resta un salto anticipato e
## non apre il deltaplano.
@export var glide_min_height := 1.2

@export_group("Acqua")
@export var swim_speed := 2.5
@export var swim_acceleration := 10.0
## Vita persa per ogni secondo in acqua.
@export var water_damage_per_second := 20.0
## Altezza del salto fuori dall'acqua, rispetto al salto normale.
@export var water_jump_factor := 0.85
## Quanto la rana resta immersa quando galleggia.
@export var float_depth := 0.45

@export_group("Vita")
@export var max_health := 100
## Secondi senza controllo dopo un colpo.
@export var stun_duration := 0.4
## Secondi di invulnerabilità dopo un colpo; la rana lampeggia.
@export var invulnerability_duration := 1.0

## Sotto questa quota la rana torna al punto di partenza.
@export var fall_limit := -20.0

@onready var visual: Node3D = $Visual
@onready var glider: Node3D = $Visual/Glider
@onready var camera_rig: CameraRig = $CameraRig

var _jump_velocity: float
var _gravity_up: float
var _gravity_down: float
var _time_since_floor := 0.0
var _time_since_jump_pressed := INF
var _hop_phase := 0.0
var _spawn_position: Vector3
var _stun_time := 0.0
var _invulnerable_time := 0.0
var _punch_cooldown_left := 0.0
var _super_jump_cooldown_left := 0.0
var _super_jumping := false
var _gliding := false
var _glide_charge := 0.0
var _river: River
var _water_damage_owed := 0.0
var _punch_query := PhysicsShapeQueryParameters3D.new()

@onready var health := max_health


func _ready() -> void:
	_spawn_position = global_position
	# Salto parabolico definito da altezza e tempi, non da gravità e velocità.
	_jump_velocity = 2.0 * jump_height / jump_time_to_peak
	_gravity_up = 2.0 * jump_height / pow(jump_time_to_peak, 2)
	_gravity_down = 2.0 * jump_height / pow(jump_time_to_fall, 2)
	_glide_charge = glide_duration
	var sphere := SphereShape3D.new()
	sphere.radius = punch_radius
	_punch_query.shape = sphere
	_punch_query.collision_mask = 4 # veicoli
	glider.visible = false


func _physics_process(delta: float) -> void:
	_stun_time = maxf(_stun_time - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	_punch_cooldown_left = maxf(_punch_cooldown_left - delta, 0.0)
	_super_jump_cooldown_left = maxf(_super_jump_cooldown_left - delta, 0.0)

	var input := Vector2.ZERO
	if _stun_time == 0.0:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)

	var can_act := _stun_time == 0.0
	if can_act and Input.is_action_just_pressed("super_jump") and _super_jump_cooldown_left == 0.0:
		super_jump(direction)
	_update_glider(delta)

	if is_swimming():
		_swim(direction, delta)
	elif _gliding:
		_glide(direction, delta)
	else:
		_apply_horizontal_movement(direction, delta)
		_apply_gravity_and_jump(delta)
	move_and_slide()

	if is_on_floor() and velocity.y <= 0.0:
		_super_jumping = false
	if can_act and Input.is_action_just_pressed("punch") and _punch_cooldown_left == 0.0:
		punch()

	_update_visual(direction, delta)
	if global_position.y < fall_limit:
		respawn()


func enter_water(river: River) -> void:
	_river = river


func exit_water(river: River) -> void:
	if _river == river:
		_river = null


## In acqua solo finché i piedi sono sotto la superficie e la rana non sta
## salendo in fretta: altrimenti il galleggiamento annullerebbe il salto.
func is_swimming() -> bool:
	return _river != null and global_position.y < _river.surface_y() - 0.1 and velocity.y <= 2.0


func is_gliding() -> bool:
	return _gliding


## Carica del deltaplano, da 0 a 1.
func glide_charge_ratio() -> float:
	return _glide_charge / glide_duration


func super_jump_cooldown_left() -> float:
	return _super_jump_cooldown_left


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_stun_time = 0.0
	_river = null
	_super_jumping = false
	_close_glider()
	reset_physics_interpolation()


## Colpisce i veicoli davanti a sé, nella direzione in cui guarda la telecamera.
func punch() -> void:
	_punch_cooldown_left = punch_cooldown
	var forward := -camera_rig.flat_basis().z
	visual.rotation.y = atan2(-forward.x, -forward.z)
	var tween := create_tween()
	visual.scale = Vector3(0.8, 0.8, 1.4)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.15)

	var center := global_position + Vector3.UP * 0.6 + forward * punch_reach
	_punch_query.transform = Transform3D(Basis(), center)
	var hits: Array[Car] = []
	for result in get_world_3d().direct_space_state.intersect_shape(_punch_query, 8):
		var car := result.collider as Car
		if car and not hits.has(car):
			hits.append(car)
			car.receive_punch((forward + Vector3.UP * punch_lift) * punch_impulse)
	power_used.emit(&"punch")
	if not hits.is_empty():
		punched.emit(hits)


## Un balzo alto con slancio in avanti: nella direzione dei tasti o, da fermi,
## in quella della telecamera. Funziona anche dall'acqua.
func super_jump(direction: Vector3) -> void:
	_super_jump_cooldown_left = super_jump_cooldown
	_close_glider()
	if direction.length_squared() < 0.01:
		direction = -camera_rig.flat_basis().z
	var boost := direction.normalized() * super_jump_boost
	velocity = Vector3(boost.x, sqrt(2.0 * _gravity_up * super_jump_height), boost.z)
	_super_jumping = true
	_time_since_floor = INF
	_time_since_jump_pressed = INF
	var tween := create_tween()
	visual.scale = Vector3(1.3, 0.6, 1.3)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.25)
	power_used.emit(&"super_jump")


## Un colpo da un veicolo o da un pericolo: toglie vita e sbalza la rana.
func take_hit(damage: int, knockback: Vector3) -> void:
	if _invulnerable_time > 0.0:
		return
	velocity = knockback
	_stun_time = stun_duration
	_invulnerable_time = invulnerability_duration
	_super_jumping = false
	_close_glider()
	_lose_health(damage)


func _lose_health(amount: int) -> void:
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()
		# Provvisorio: la morte con fine della run arriva al punto 8.
		health = max_health
		health_changed.emit(health, max_health)
		respawn()


## Apre, tiene aperto e chiude il deltaplano; a terra lo ricarica.
func _update_glider(delta: float) -> void:
	var grounded := is_on_floor() or is_swimming()
	if grounded:
		_close_glider()
		_glide_charge = minf(_glide_charge + glide_recharge_per_second * delta, glide_duration)
		return

	if _gliding:
		_glide_charge = maxf(_glide_charge - delta, 0.0)
		if not Input.is_action_pressed("jump") or _glide_charge == 0.0:
			_close_glider()
	elif Input.is_action_just_pressed("jump") and _stun_time == 0.0 and _can_open_glider():
		_gliding = true
		glider.visible = true
		# La pressione ha aperto il deltaplano: non va ricordata come salto.
		_time_since_jump_pressed = INF
		power_used.emit(&"glide")


## Serve una nuova pressione in aria, lontano dal suolo e fuori dal coyote time;
## vicino al suolo la stessa pressione resta un salto anticipato.
func _can_open_glider() -> bool:
	if _glide_charge <= 0.0 or _time_since_floor <= coyote_time:
		return false
	var from := global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (glide_min_height + 0.1), 1 | 4 | 8)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _close_glider() -> void:
	_gliding = false
	if glider:
		glider.visible = false


## Scende lenta e plana in avanti; si sterza con i tasti, e da fermi prosegue
## nella direzione in cui stava andando.
func _glide(direction: Vector3, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var heading := direction
	if heading.length_squared() < 0.01:
		heading = horizontal if horizontal.length_squared() > 0.01 else -camera_rig.flat_basis().z
	horizontal = horizontal.move_toward(heading.normalized() * glide_speed, glide_acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = maxf(velocity.y - _gravity_down * delta, -glide_fall_speed)


## Galleggia, nuota lenta, segue la corrente e perde vita. Spazio fa un salto
## più debole per risalire su un tronco o sulla sponda.
func _swim(direction: Vector3, delta: float) -> void:
	var target := direction * swim_speed + _river.current_at(global_position)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(target, swim_acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var float_y := _river.surface_y() - float_depth
	var target_vertical := clampf((float_y - global_position.y) * 6.0, -4.0, 4.0)
	velocity.y = move_toward(velocity.y, target_vertical, 30.0 * delta)

	if Input.is_action_just_pressed("jump") and _stun_time == 0.0:
		velocity.y = _jump_velocity * water_jump_factor

	_water_damage_owed += water_damage_per_second * delta
	if _water_damage_owed >= 1.0:
		var damage := floori(_water_damage_owed)
		_water_damage_owed -= damage
		_lose_health(damage)


func _apply_horizontal_movement(direction: Vector3, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	var target_speed := move_speed
	if _stun_time > 0.0:
		# Lo sbalzo si esaurisce piano, invece di essere annullato subito.
		acceleration = air_acceleration
	elif _super_jumping and not is_on_floor():
		# In volo si sterza senza frenare: senza tasti lo slancio resta tutto.
		if direction.length_squared() < 0.01:
			return
		acceleration = super_air_acceleration
		target_speed = maxf(move_speed, horizontal.length())
	horizontal = horizontal.move_toward(direction * target_speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _apply_gravity_and_jump(delta: float) -> void:
	_time_since_floor = 0.0 if is_on_floor() else _time_since_floor + delta
	_time_since_jump_pressed += delta
	if Input.is_action_just_pressed("jump") and _stun_time == 0.0 and not _gliding:
		_time_since_jump_pressed = 0.0

	if _time_since_jump_pressed <= jump_buffer_time and _time_since_floor <= coyote_time:
		velocity.y = _jump_velocity
		_time_since_jump_pressed = INF
		_time_since_floor = INF

	# Rilasciare Spazio mentre sale accorcia il salto; il super salto no.
	var rising := velocity.y > 0.0 and (Input.is_action_pressed("jump") or _super_jumping)
	velocity.y -= (_gravity_up if rising else _gravity_down) * delta


func _update_visual(direction: Vector3, delta: float) -> void:
	visual.visible = _invulnerable_time == 0.0 or fmod(_invulnerable_time, 0.2) > 0.1

	var heading := direction
	if _gliding:
		heading = Vector3(velocity.x, 0.0, velocity.z)
	if heading.length_squared() > 0.01:
		var target_yaw := atan2(-heading.x, -heading.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, turn_speed * delta)

	var moving_on_floor := is_on_floor() and not is_swimming() and direction.length_squared() > 0.01
	if moving_on_floor:
		_hop_phase = fmod(_hop_phase + hops_per_second * delta, 1.0)
		visual.position.y = sin(_hop_phase * PI) * hop_height
	else:
		_hop_phase = 0.0
		visual.position.y = move_toward(visual.position.y, 0.0, 2.0 * delta)
