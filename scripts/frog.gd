class_name Frog
extends CharacterBody3D
## La rana: movimento libero relativo alla telecamera, salto con coyote time e
## buffer, saltelli solo visivi mentre cammina, nuoto, vita e colpi subiti.
## I poteri sono nodi figli in Powers (pugno, super salto, deltaplano), ognuno
## con i suoi valori, il suo stato e il suo attrezzo: i potenziamenti li
## modificano lì. La rana legge i comandi e li passa ai poteri.

signal health_changed(health: int, max_health: int)
signal died
## Emesso a ogni pugno andato a segno, con i veicoli colpiti.
signal punched(cars: Array[Car])
## Emesso a ogni uso di un potere (&"punch", &"super_jump", &"glide"): fa
## salire il calore.
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

## Salto parabolico definito da altezza e tempi: velocità e gravità derivano.
var jump_velocity: float
var gravity_up: float
var gravity_down: float
var is_dead := false

@onready var health := max_health
@onready var visual: Node3D = $Visual
@onready var glider: Node3D = $Visual/Glider
@onready var camera_rig: CameraRig = $CameraRig
@onready var punch_power: PunchPower = $Powers/Punch
@onready var super_jump_power: SuperJumpPower = $Powers/SuperJump
@onready var glider_power: GliderPower = $Powers/Glider

var _time_since_floor := 0.0
var _time_since_jump_pressed := INF
var _hop_phase := 0.0
var _spawn_position: Vector3
var _stun_time := 0.0
var _invulnerable_time := 0.0
var _river: River
var _water_damage_owed := 0.0
var _squash_tween: Tween
## Vento di questo passo (il getto dei motori degli aerei): una velocità che
## si somma al movimento, come la corrente del fiume, e una spinta verso
## l'alto che conta solo col deltaplano aperto.
var _wind_push := Vector3.ZERO
var _wind_lift := 0.0
var _burn_owed := 0.0


func _ready() -> void:
	add_to_group("frog")
	_spawn_position = global_position
	jump_velocity = 2.0 * jump_height / jump_time_to_peak
	gravity_up = 2.0 * jump_height / pow(jump_time_to_peak, 2)
	gravity_down = 2.0 * jump_height / pow(jump_time_to_fall, 2)
	for power in $Powers.get_children():
		power.setup(self)
	_apply_palette()


func _physics_process(delta: float) -> void:
	if is_dead:
		_fall_while_dead(delta)
		return
	_stun_time = maxf(_stun_time - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	punch_power.tick(delta)
	super_jump_power.tick(delta)

	var input := Vector2.ZERO
	if can_act():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)

	if can_act() and Input.is_action_just_pressed("super_jump") and super_jump_power.is_ready():
		glider_power.close()
		super_jump_power.use(direction)
	glider_power.update(delta)

	if is_swimming():
		_swim(direction, delta)
	elif glider_power.gliding:
		glider_power.apply(direction, delta)
	else:
		_apply_horizontal_movement(direction, delta)
		_apply_gravity_and_jump(delta)
	var was_on_floor := is_on_floor()
	var fall_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor and fall_speed > 4.0:
		# Si spiaccica all'atterraggio, tanto più quanto cadeva veloce.
		var amount := clampf(fall_speed / 25.0, 0.1, 0.4)
		squash(Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount), 0.3)

	if can_act() and Input.is_action_just_pressed("punch") and punch_power.is_ready():
		punch()

	_update_visual(direction, delta)
	# Il vento lo rimettono ogni passo gli aerei: se ci si allontana, cessa.
	_wind_push = Vector3.ZERO
	_wind_lift = 0.0
	if global_position.y < fall_limit:
		respawn()


# --- Usati dai poteri ---------------------------------------------------------

## Falsa durante lo stordimento dopo un colpo.
func can_act() -> bool:
	return _stun_time == 0.0


## Vento per il prossimo passo di fisica, come il getto dei motori: conta il
## più forte tra quelli che investono la rana.
func apply_wind(push: Vector3, lift: float) -> void:
	if push.length() > _wind_push.length():
		_wind_push = Vector3(push.x, 0.0, push.z)
	_wind_lift = maxf(_wind_lift, lift)


## Danno continuo, come la fiamma dei motori: non stordisce e non dà
## invulnerabilità, toglie vita a ogni passo finché la rana ci resta dentro.
func burn(damage_per_second: float, delta: float) -> void:
	_burn_owed += damage_per_second * delta
	if _burn_owed >= 1.0:
		var damage := floori(_burn_owed)
		_burn_owed -= damage
		_lose_health(damage)


func wind_push() -> Vector3:
	return _wind_push


func wind_lift() -> float:
	return _wind_lift


## Lancia la rana con la velocità data, annullando salti in corso o anticipati.
func launch(new_velocity: Vector3) -> void:
	velocity = new_velocity
	_time_since_floor = INF
	_time_since_jump_pressed = INF


func time_since_floor() -> float:
	return _time_since_floor


func forget_jump_press() -> void:
	_time_since_jump_pressed = INF


## Imposta subito la forma data e la riporta a quella normale con un rimbalzo.
func squash(shape: Vector3, duration: float) -> void:
	var tween := new_squash_tween()
	visual.scale = shape
	tween.tween_property(visual, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Un tween per la forma della rana, che interrompe quello precedente.
func new_squash_tween() -> Tween:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	return _squash_tween


# --- Scorciatoie verso i poteri (HUD, partita, test) -------------------------

func punch() -> void:
	punch_power.use()


func is_gliding() -> bool:
	return glider_power.gliding


## Carica del deltaplano, da 0 a 1.
func glide_charge_ratio() -> float:
	return glider_power.charge_ratio()


func super_jump_cooldown_left() -> float:
	return super_jump_power.cooldown_left


# --- Acqua, vita, ripartenza -------------------------------------------------

func enter_water(river: River) -> void:
	_river = river


func exit_water(river: River) -> void:
	if _river == river:
		_river = null


## In acqua solo finché i piedi sono sotto la superficie e la rana non sta
## salendo in fretta: altrimenti il galleggiamento annullerebbe il salto.
func is_swimming() -> bool:
	return _river != null and global_position.y < _river.surface_y() - 0.1 and velocity.y <= 2.0


## Vita piena, per esempio quando un power-up alza la vita massima.
func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)


## Il punto in cui la rana ricompare se cade fuori dal mondo (una tana).
func set_respawn_point(point: Vector3) -> void:
	_spawn_position = point


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_stun_time = 0.0
	_river = null
	super_jump_power.active = false
	glider_power.close()
	reset_physics_interpolation()


## Un colpo da un veicolo o da un pericolo: toglie vita e sbalza la rana.
func take_hit(damage: int, knockback: Vector3) -> void:
	if _invulnerable_time > 0.0 or is_dead:
		return
	velocity = knockback
	_stun_time = stun_duration
	_invulnerable_time = invulnerability_duration
	super_jump_power.active = false
	glider_power.close()
	_lose_health(damage)


func _lose_health(amount: int) -> void:
	if is_dead:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()


## La morte chiude la run: la rana non risponde più e si gira a pancia in su.
func _die() -> void:
	is_dead = true
	glider_power.close()
	super_jump_power.active = false
	var tween := create_tween()
	tween.tween_property(visual, "rotation:z", PI, 0.4)
	died.emit()


## Da morta la rana cade o galleggia, senza controlli né poteri.
func _fall_while_dead(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, air_acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, air_acceleration * delta)
	if _river != null and global_position.y < _river.surface_y() - float_depth:
		velocity.y = move_toward(velocity.y, 1.0, 30.0 * delta)
	else:
		velocity.y -= gravity_down * delta
	move_and_slide()


# --- Movimento ---------------------------------------------------------------

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

	if Input.is_action_just_pressed("jump") and can_act():
		velocity.y = jump_velocity * water_jump_factor
		squash(Vector3(0.8, 1.3, 0.8), 0.25)

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
	elif super_jump_power.active and not is_on_floor():
		# In volo si sterza senza frenare: senza tasti lo slancio resta tutto.
		if direction.length_squared() < 0.01 and _wind_push == Vector3.ZERO:
			return
		acceleration = super_jump_power.air_acceleration
		target_speed = maxf(move_speed, horizontal.length())
	horizontal = horizontal.move_toward(direction * target_speed + _wind_push, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _apply_gravity_and_jump(delta: float) -> void:
	_time_since_floor = 0.0 if is_on_floor() else _time_since_floor + delta
	_time_since_jump_pressed += delta
	if Input.is_action_just_pressed("jump") and can_act():
		_time_since_jump_pressed = 0.0

	if _time_since_jump_pressed <= jump_buffer_time and _time_since_floor <= coyote_time:
		velocity.y = jump_velocity
		squash(Vector3(0.8, 1.3, 0.8), 0.25)
		_time_since_jump_pressed = INF
		_time_since_floor = INF

	# Rilasciare Spazio mentre sale accorcia il salto; il super salto no.
	var rising := velocity.y > 0.0 and (Input.is_action_pressed("jump") or super_jump_power.active)
	velocity.y -= (gravity_up if rising else gravity_down) * delta


# --- Aspetto -----------------------------------------------------------------

## Le parti fatte nella scena prendono i colori dalla tavolozza dello stile.
func _apply_palette() -> void:
	$Visual/Body.material_override = Style.material("frog")
	for eye: MeshInstance3D in [$Visual/EyeLeft, $Visual/EyeRight]:
		eye.material_override = Style.material("eye")
		(eye.get_child(0) as MeshInstance3D).material_override = Style.material("pupil")


func _update_visual(direction: Vector3, delta: float) -> void:
	visual.visible = _invulnerable_time == 0.0 or fmod(_invulnerable_time, 0.2) > 0.1

	var heading := direction
	if glider_power.gliding:
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
