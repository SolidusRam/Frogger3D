class_name FrogAnimator
extends RefCounted
## Le animazioni della rana, fatte da codice sui pezzi del modello (vedi
## build_frog): niente animazioni registrate, tutto segue quello che succede
## nel gioco. Accompagnano i gesti, non li anticipano mai: pugno e salto
## partono nel fotogramma del tasto.
##
## - Il corpo segue la traiettoria: in salto si inclina col volo e le zampe
##   spingono indietro salendo e si raccolgono scendendo; col deltaplano si
##   piega in curva e le zampe penzolano; in acqua scalcia a rana.
## - Quando l'incendio è vicino la rana si gira a guardarlo, sempre più spesso.
## - Da ferma la gola pulsa e le palpebre sbattono; dopo qualche secondo fa a
##   pugni con l'aria.
##
## Le pose si possono aggiornare a scatti (pose_fps), come nei giochi PS1;
## 0 vuol dire fluide.

## Pose al secondo: 0 fluide, 12-15 a scatti come sulla PS1. Si prova dalla
## modalità prova (F1).
static var pose_fps := 0.0

## Il fuoco sotto questa distanza fa girare la testa; sotto la metà, spesso.
const FIRE_GLANCE := 22.0
const GLANCE_YAW := 1.25
const IDLE_BOXING := 4.0
## Punto attorno a cui si inclina tutto il corpo (in coordinate del modello).
const TILT_PIVOT := Vector3(0.0, 0.35, 0.0)

var _frog: Frog
var _model: Node3D
var _head: Node3D
var _throat: Node3D
var _eyes: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _rest := {}
## Un generatore tutto suo: le animazioni non devono cambiare la sequenza
## casuale del gioco.
var _rng := RandomNumberGenerator.new()

var _time := 0.0
var _pose_wait := 0.0
var _pitch := 0.0
var _bank := 0.0
var _leg_swing := 0.0
var _last_yaw := 0.0
var _glance := 0.0
var _glance_target := 0.0
var _glance_left := 0.0
var _next_glance := 0.0
var _blink_left := 0.0
var _next_blink := 2.0
var _idle_time := 0.0
var _boxing := false


func _init(frog: Frog) -> void:
	_frog = frog
	_model = frog.model
	var torso := _model.get_node("Torso")
	_head = torso.get_node("Head")
	_throat = _head.get_node("Throat")
	for side in ["L", "R"]:
		_eyes.append(_head.get_node("Eye" + side))
		_legs.append(torso.get_node("Leg" + side))
		_feet.append(torso.get_node("Leg%s/Foot%s" % [side, side]))
	for node: Node3D in [_model, _head, _throat] + _eyes + _legs + _feet:
		_rest[node] = node.transform
		# Si muovono a ogni fotogramma, non a ogni passo di fisica.
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_last_yaw = frog.visual.rotation.y
	_rng.randomize()


func update(delta: float) -> void:
	if _frog.is_dead:
		return
	_time += delta
	var velocity := _frog.velocity
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var on_floor := _frog.is_on_floor()
	var swimming := _frog.is_swimming()
	var gliding := _frog.is_gliding()
	var smooth := 1.0 - exp(-10.0 * delta)

	# Il corpo segue la traiettoria.
	var pitch := 0.0
	var leg := 0.0
	if gliding:
		pitch = -0.2
		leg = 0.5 + 0.15 * sin(_time * 3.0)
	elif swimming:
		leg = 0.45 + 0.45 * sin(_time * 6.0)
	elif not on_floor:
		pitch = clampf(velocity.y * 0.045, -0.45, 0.45)
		# Salendo le zampe spingono indietro, scendendo si raccolgono.
		leg = clampf(velocity.y * 0.12, -0.35, 0.9)
	elif horizontal > 0.5:
		leg = 0.5 * sin(_frog.hop_phase() * PI)
	_pitch = lerpf(_pitch, pitch, smooth)
	_leg_swing = lerpf(_leg_swing, leg, smooth)
	# In curva col deltaplano si piega dalla parte della curva.
	var yaw := _frog.visual.rotation.y
	var turn := angle_difference(_last_yaw, yaw) / maxf(delta, 0.001)
	_last_yaw = yaw
	_bank = lerpf(_bank, clampf(-turn * 0.3, -0.6, 0.6) if gliding else 0.0, 1.0 - exp(-5.0 * delta))

	_update_glance(delta)
	_update_blink(delta)
	var idle := on_floor and not swimming and horizontal < 0.5 and _frog.punch_power.cooldown_left == 0.0
	_idle_time = _idle_time + delta if idle else 0.0

	# A scatti: le pose si scrivono solo pose_fps volte al secondo.
	if pose_fps > 0.0:
		_pose_wait -= delta
		if _pose_wait > 0.0:
			return
		_pose_wait += 1.0 / pose_fps
		_pose_wait = maxf(_pose_wait, 0.0)
	_pose()


func _pose() -> void:
	# Il corpo intero: inclinazione, piega in curva e, in guardia, il
	# dondolio del pugile.
	var basis := Basis.from_euler(Vector3(_pitch, 0.0, _bank))
	var sway := Vector3.ZERO
	var boxing := _idle_time > IDLE_BOXING
	if boxing:
		sway = Vector3(sin(_time * 4.0) * 0.05, absf(sin(_time * 8.0)) * 0.04, 0.0)
	_model.transform = Transform3D(basis, TILT_PIVOT - basis * TILT_PIVOT + sway) * _rest[_model]
	for i in _legs.size():
		_legs[i].transform = _rest[_legs[i]] * Transform3D(Basis(Vector3.RIGHT, _leg_swing), Vector3.ZERO)
		_feet[i].transform = _rest[_feet[i]] * Transform3D(Basis(Vector3.RIGHT, _leg_swing * 0.8), Vector3.ZERO)
	_head.transform = _rest[_head] * Transform3D(Basis(Vector3.UP, _glance), Vector3.ZERO)
	# La gola pulsa sempre, di più da ferma.
	var beat := pow(maxf(sin(_time * TAU * 1.3), 0.0), 2.0) * (0.45 if _idle_time > 0.5 else 0.2)
	_throat.transform = _rest[_throat] * Transform3D(Basis.from_scale(Vector3(1.0 + beat * 0.3, 1.0 + beat, 1.0 + beat * 0.2)), Vector3.ZERO)
	var lid := 0.12 if _blink_left > 0.0 else (1.15 if absf(_glance) > 0.3 else 1.0)
	for eye in _eyes:
		eye.transform = _rest[eye] * Transform3D(Basis.from_scale(Vector3(lid if lid > 1.0 else 1.0, lid, lid if lid > 1.0 else 1.0)), Vector3.ZERO)
	_pose_gloves(boxing)


## In guardia, da ferma: un diretto alla volta, sinistro e destro, nell'aria.
## Quando la rana si muove i guantoni tornano a posto (il pugno vero li
## muove da sé).
func _pose_gloves(boxing: bool) -> void:
	var gloves: Array[Node3D] = [_model.get_node("GloveL"), _model.get_node("GloveR")]
	if not boxing:
		if _boxing and _frog.punch_power.cooldown_left == 0.0:
			for glove in gloves:
				glove.position = glove.get_meta("rest")
		_boxing = false
		return
	_boxing = true
	for i in gloves.size():
		var rest: Vector3 = gloves[i].get_meta("rest")
		var phase := fmod(_time + i * 0.7, 1.4) / 1.4
		var out := sin(phase / 0.18 * PI) * 0.45 if phase < 0.18 else 0.0
		var guard := sin(_time * 4.0 + i * PI) * 0.03
		gloves[i].position = rest + Vector3(-signf(rest.x) * 0.15 * out, 0.06 * out + guard, -out)


## Quando l'incendio si avvicina, la rana si gira a guardarlo: un'occhiata ogni
## tanto, sempre più spesso man mano che il fuoco arriva.
func _update_glance(delta: float) -> void:
	var fire := _frog.get_tree().get_first_node_in_group("wildfire") as Wildfire
	var gap := fire.distance() if fire and not fire.stopped else INF
	_next_glance -= delta
	_glance_left -= delta
	if _glance_left <= 0.0:
		_glance_target = 0.0
	if gap < FIRE_GLANCE and _next_glance <= 0.0:
		# Il fuoco è dietro, verso +Z: si gira dalla parte più corta.
		var behind := _frog.visual.global_basis.inverse() * Vector3.BACK
		var side := signf(behind.x) if absf(behind.x) > 0.05 else (1.0 if _rng.randf() < 0.5 else -1.0)
		_glance_target = side * GLANCE_YAW
		_glance_left = 0.55
		var closeness := clampf(gap / FIRE_GLANCE, 0.0, 1.0)
		_next_glance = lerpf(0.9, 3.0, closeness) + _rng.randf_range(0.0, 0.6)
	_glance = lerpf(_glance, _glance_target, 1.0 - exp(-14.0 * delta))


func _update_blink(delta: float) -> void:
	_blink_left -= delta
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_left = 0.12
		_next_blink = _rng.randf_range(1.8, 5.0)
