class_name Frog
extends CharacterBody3D
## La rana: movimento libero relativo alla telecamera, salto con coyote time e
## buffer, saltelli solo visivi mentre cammina, nuoto, vita e colpi subiti.
## I poteri sono nodi figli in Powers (pugno, super salto, deltaplano), ognuno
## con i suoi valori, il suo stato e il suo attrezzo: i potenziamenti li
## modificano lì. La rana legge i comandi e li passa ai poteri.

signal health_changed(health: int, max_health: int)
signal died
## La seconda vita (statistica dello stagno) ha appena salvato la rana.
signal revived
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

@export_group("Bordi")
## Mezza larghezza della zona di gioco (la imposta il percorso): lì ci sono i
## muri invisibili.
@export var play_half_width := 37.0
## Schiacciata contro il bordo da qualcosa che si muove: vita persa e velocità
## dello sbalzo di lato.
@export var pinch_damage := 25
@export var pinch_push := 10.0

## Salto parabolico definito da altezza e tempi: velocità e gravità derivano.
var jump_velocity: float
var gravity_up: float
var gravity_down: float
var is_dead := false
## Nel menu la rana aspetta sulla striscia di partenza: non risponde ai tasti.
var asleep := false

@onready var health := max_health
@onready var visual: Node3D = $Visual
## Il modello di Blender, a pezzi (vedi build_frog in build_models.py).
@onready var model: Node3D = $Visual/Model
@onready var _torso: Node3D = $Visual/Model/Torso
@onready var _arms: Array[Node3D] = [$Visual/Model/Torso/ArmL, $Visual/Model/Torso/ArmR]
@onready var _gloves: Array[Node3D] = [$Visual/Model/GloveL, $Visual/Model/GloveR]
@onready var _head: Node3D = $Visual/Model/Torso/Head
## Le animazioni dei pezzi del modello (vedi FrogAnimator).
var animator: FrogAnimator
@onready var glider: Node3D = $Visual/Glider
@onready var camera_rig: CameraRig = $CameraRig
@onready var punch_power: PunchPower = $Powers/Punch
@onready var super_jump_power: SuperJumpPower = $Powers/SuperJump
@onready var glider_power: GliderPower = $Powers/Glider
@onready var tongue_power: TonguePower = $Powers/Tongue
@onready var slam_power: SlamPower = $Powers/Slam

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
## Colori della tavolozza cambiati sul modello, per nome del materiale: i
## poteri e le carte ci mettono i loro ("glove" -> "glove_hot"...).
var _palette := {}
## Lunghezza a riposo delle braccia, dalla spalla al guantone.
var _arm_lengths: Array[float] = []
## Modalità prova: niente toglie vita.
var invincible := false
## Molle-trampolino (power-up): sui tetti delle auto si rimbalza da soli.
var trampoline := false
var trampoline_height := 2.6
## Miglioramenti speciali delle molle-trampolino: crescendo (ogni rimbalzo
## di fila più alto) e bombardiera (rimbalzando si ribalta l'auto sotto).
var trampoline_crescendo := false
var trampoline_wrecks := false
## Rimbalzi di fila sui tetti, senza toccare altro.
var bounce_streak := 0
## Statistica dello stagno "Ricarica": frazione dei tempi di ricarica.
var cooldown_factor := 1.0
## Pelle impermeabile (power-up): l'acqua non toglie vita.
var waterproof := false
## Miglioramenti speciali della pelle impermeabile: il tuffo (in acqua, con
## Ctrl, ci si immerge e si passa sotto tronchi e coccodrilli) e l'ondata
## (saltando fuori dall'acqua si spingono via auto e rottami vicini).
var can_dive := false
var splash_wave := false
## Vero mentre la rana è immersa col tuffo.
var submerged := false
@export var dive_depth := 2.0
@export var splash_radius := 5.0
## Secondi di fila in acqua (per la prova della pelle impermeabile).
var _water_time := 0.0
## Velocità di nuoto senza carte (la pelle impermeabile migliorata la
## moltiplica).
var base_swim_speed := 2.5
## Statistiche dello stagno: frazione del danno subito, vite in più.
var damage_factor := 1.0
var extra_lives := 0


func _ready() -> void:
	add_to_group("frog")
	_spawn_position = global_position
	compute_jump()
	for i in _arms.size():
		_arm_lengths.append(_arms[i].position.distance_to(_torso.transform.affine_inverse() * _gloves[i].position))
		# Le braccia si puntano a ogni fotogramma, non a ogni passo di fisica.
		_arms[i].physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for power in $Powers.get_children():
		power.setup(self)
	_apply_palette()
	animator = FrogAnimator.new(self)


func _process(delta: float) -> void:
	animator.update(delta)
	_aim_arms()


func _physics_process(delta: float) -> void:
	if is_dead:
		_fall_while_dead(delta)
		return
	_stun_time = maxf(_stun_time - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	punch_power.tick(delta)
	super_jump_power.tick(delta)
	tongue_power.tick(delta)
	slam_power.tick(delta)
	if not is_swimming():
		submerged = false
		_water_time = 0.0

	var input := Vector2.ZERO
	if can_act():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera_rig.flat_basis() * Vector3(input.x, 0.0, input.y)

	if can_act() and Input.is_action_just_pressed("super_jump") and super_jump_power.is_ready():
		glider_power.close()
		tongue_power.release()
		super_jump_power.use(direction)
	if can_act() and Input.is_action_just_pressed("tongue") and tongue_power.is_ready():
		glider_power.close()
		slam_power.stop()
		tongue_power.use()
	# La lingua resta agganciata finché si tiene premuto E.
	if tongue_power.attached and not Input.is_action_pressed("tongue"):
		tongue_power.release()
	if can_act() and Input.is_action_just_pressed("slam") and slam_power.is_ready() and slam_power.can_start():
		glider_power.close()
		tongue_power.stop()
		slam_power.use()
	glider_power.update(delta)

	# Un rottame agganciato viene tirato; la rana intanto si muove normalmente.
	if tongue_power.attached and not tongue_power.is_towing():
		tongue_power.pull_wreck(delta)
	# La lingua trascina anche fuori dall'acqua; lo schianto vince sul deltaplano.
	if tongue_power.is_towing():
		tongue_power.apply(delta)
	elif slam_power.diving:
		slam_power.apply(delta)
	elif is_swimming():
		_swim(direction, delta)
	elif glider_power.gliding:
		glider_power.apply(direction, delta)
	else:
		_apply_horizontal_movement(direction, delta)
		_apply_gravity_and_jump(delta)
	var was_on_floor := is_on_floor()
	var fall_speed := -velocity.y
	move_and_slide()
	_check_pinch()
	if slam_power.diving and is_on_floor():
		slam_power.apply(delta)
	if trampoline and is_on_floor() and floor_body() is Car and velocity.y <= 0.0:
		# Molle-trampolino: sui tetti delle auto si rimbalza da soli.
		if trampoline_wrecks and floor_body().state == Car.State.DRIVING:
			floor_body().become_wreck()
		bounce_streak += 1
		Progress.trial_add("trampoline", 0, 1)
		Progress.trial_best("trampoline", 1, bounce_streak)
		var height := trampoline_height + (0.6 * mini(bounce_streak - 1, 5) if trampoline_crescendo else 0.0)
		# Senza Spazio premuto si sale con la gravità di discesa.
		launch(Vector3(velocity.x, sqrt(2.0 * gravity_down * height), velocity.z))
		squash(Vector3(1.3, 0.7, 1.3), 0.2)
	elif is_on_floor() or is_swimming():
		bounce_streak = 0
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

## Falsa durante lo stordimento dopo un colpo, e nel menu (asleep).
func can_act() -> bool:
	return _stun_time == 0.0 and not asleep


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


## Il corpo su cui la rana sta in piedi (null se è in aria o in acqua).
func floor_body() -> Object:
	if not is_on_floor():
		return null
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().dot(Vector3.UP) > 0.7:
			return collision.get_collider()
	return null


## Lancia la rana con la velocità data, annullando salti in corso o anticipati.
func launch(new_velocity: Vector3) -> void:
	velocity = new_velocity
	_time_since_floor = INF
	_time_since_jump_pressed = INF


## Recupera vita, fino al massimo.
func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


## Velocità e gravità del salto da altezza e tempi (di nuovo quando le
## statistiche dello stagno cambiano l'altezza).
func compute_jump() -> void:
	jump_velocity = 2.0 * jump_height / jump_time_to_peak
	gravity_up = 2.0 * jump_height / pow(jump_time_to_peak, 2)
	gravity_down = 2.0 * jump_height / pow(jump_time_to_fall, 2)


## Pelle impermeabile (power-up): l'acqua non toglie vita; la rana diventa
## verde acqua.
func set_waterproof(on: bool) -> void:
	waterproof = on
	set_palette("frog", "frog_wet" if on else "")


## Cambia un colore del modello: le parti col materiale key prendono la voce
## value della tavolozza ("" torna al colore normale).
func set_palette(key: String, value: String) -> void:
	if value == "":
		_palette.erase(key)
	else:
		_palette[key] = value
	_apply_palette()


## A che punto è il saltello mentre cammina, da 0 a 1.
func hop_phase() -> float:
	return _hop_phase


## La bocca, da dove parte la lingua: segue la testa.
func mouth_position() -> Vector3:
	return _head.global_transform * Vector3(0.0, -0.07, -0.4)


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
	tongue_power.stop()
	slam_power.stop()
	_lose_health(damage)


func _lose_health(amount: int) -> void:
	if is_dead or invincible:
		return
	health = maxi(health - ceili(amount * damage_factor), 0)
	if health == 0 and extra_lives > 0:
		# La seconda vita: ci si rialza con metà vita e un attimo di respiro.
		extra_lives -= 1
		health = max_health / 2
		_invulnerable_time = 2.0
		revived.emit()
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


## Schiacciata contro il bordo: qualcosa che si muove (il ponte di comando di
## una nave, una prua, un tronco di lato) la spinge contro il muro invisibile.
## Senza questo la rana finirebbe dentro il corpo che spinge o oltre il muro;
## invece perde un po' di vita e viene sbalzata di lato, via dal corpo.
func _check_pinch() -> void:
	var side := signf(global_position.x)
	var outside := absf(global_position.x) > play_half_width + 0.2
	var pusher: Node3D = null
	if absf(global_position.x) > play_half_width - 0.8:
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			var body := collision.get_collider() as Node3D
			if body == null or body is StaticBody3D:
				continue
			# Di lato (non il pavimento) e in moto verso il bordo.
			if collision.get_normal().dot(Vector3.UP) < 0.7 and collision.get_collider_velocity().x * side > 0.5:
				pusher = body
	if pusher == null and not outside:
		return
	var away := 1.0
	if pusher and absf(global_position.z - pusher.global_position.z) > 0.1:
		away = signf(global_position.z - pusher.global_position.z)
	# Subito fuori dal corpo che spinge: il primo punto libero di lato.
	global_position = _free_spot(Vector3(side * (play_half_width - 1.0), global_position.y, global_position.z), away)
	var push := Vector3(0.0, 4.0, away * pinch_push)
	take_hit(pinch_damage, push)
	velocity = push


## Il primo punto in cui la rana non tocca niente, cercando di lato (prima
## nel verso away, poi nell'altro), fino a 8 m.
func _free_spot(from: Vector3, away: float) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ($CollisionShape3D as CollisionShape3D).shape
	query.collision_mask = 1 | 4 | 8
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	for step in range(0, 17):
		for sign in [away, -away]:
			var spot := from + Vector3(0.0, 0.0, sign * step * 0.5)
			query.transform = Transform3D(Basis(), spot + ($CollisionShape3D as CollisionShape3D).position)
			if space.intersect_shape(query, 1).is_empty():
				return spot
	return from


## L'ondata: saltando fuori dall'acqua, auto e rottami vicini vengono spinti
## via (le auto in marcia diventano rottami).
func _splash() -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = splash_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 4
	for result in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body := result.collider as RigidBody3D
		if body == null:
			continue
		if body is Car and body.state == Car.State.DRIVING:
			body.become_wreck()
		if body.freeze:
			continue
		var away := body.global_position - global_position
		body.linear_velocity = Vector3(away.x, 0.0, away.z).normalized() * 9.0 + Vector3.UP * 4.0


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

	# Il tuffo: con Ctrl tenuto la rana va sott'acqua.
	submerged = can_dive and Input.is_action_pressed("slam")
	var float_y := _river.surface_y() - (dive_depth if submerged else float_depth)
	var target_vertical := clampf((float_y - global_position.y) * 6.0, -4.0, 4.0)
	velocity.y = move_toward(velocity.y, target_vertical, 30.0 * delta)

	if waterproof:
		Progress.trial_add("waterproof", 0, Vector2(velocity.x, velocity.z).length() * delta)
		_water_time += delta
		Progress.trial_best("waterproof", 1, _water_time)

	if Input.is_action_just_pressed("jump") and can_act():
		velocity.y = jump_velocity * water_jump_factor
		squash(Vector3(0.8, 1.3, 0.8), 0.25)
		if splash_wave:
			_splash()

	if not waterproof:
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

## Il modello prende i colori dalla tavolozza dello stile, più quelli dei
## poteri e delle carte.
func _apply_palette() -> void:
	Style.apply_palette(model, _palette)


## Le braccia vanno dalla spalla al guantone: quando il pugno scatta si
## allungano come elastici.
func _aim_arms() -> void:
	for i in _arms.size():
		var arm := _arms[i]
		var target := _torso.transform.affine_inverse() * _gloves[i].position
		var reach := target - arm.position
		if reach.length() < 0.01:
			continue
		var basis := Basis.looking_at(reach, Vector3.UP).scaled_local(Vector3(1.0, 1.0, reach.length() / _arm_lengths[i]))
		arm.transform = Transform3D(basis, arm.position)


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
