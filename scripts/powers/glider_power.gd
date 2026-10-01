class_name GliderPower
extends Node
## Il deltaplano: in aria una nuova pressione di Spazio, tenuta, lo apre. Si
## scende lenti e si plana in avanti, sterzando con i tasti. La carica si
## consuma in volo e si ricarica a terra. L'attrezzo è il modello di Blender
## in assets/models/glider.blend. I potenziamenti cambiano questi valori.

const MODEL := preload("res://assets/models/glider.glb")

@export var speed := 10.0
@export var acceleration := 12.0
## Velocità massima di discesa col deltaplano aperto.
@export var fall_speed := 2.0
## Secondi di volo con la carica piena.
@export var duration := 2.5
@export var recharge_per_second := 1.0
## Sotto questa altezza dal suolo, Spazio in aria resta un salto anticipato e
## non apre il deltaplano.
@export var min_height := 1.2

var charge := 0.0
var gliding := false

var _frog: Frog
var _wing: Node3D
var _tween: Tween
var _folding := false


func setup(frog: Frog) -> void:
	_frog = frog
	charge = duration
	_wing = frog.glider
	var model: Node3D = MODEL.instantiate()
	_wing.add_child(model)
	Style.apply_palette(model)
	_wing.visible = false


## Da 0 a 1.
func charge_ratio() -> float:
	return charge / duration


## Apre, tiene aperto e chiude il deltaplano; a terra lo ricarica.
func update(delta: float) -> void:
	if _frog.is_on_floor() or _frog.is_swimming():
		close()
		charge = minf(charge + recharge_per_second * delta, duration)
		return
	if gliding:
		charge = maxf(charge - delta, 0.0)
		if not Input.is_action_pressed("jump") or charge == 0.0:
			close()
	elif Input.is_action_just_pressed("jump") and _frog.can_act() and _can_open():
		gliding = true
		_unfold()
		# La pressione ha aperto il deltaplano: non va ricordata come salto.
		_frog.forget_jump_press()
		_frog.power_used.emit(&"glide")


## Scende lenta e plana in avanti; da fermi prosegue nella direzione in cui
## stava andando.
func apply(direction: Vector3, delta: float) -> void:
	var velocity := _frog.velocity
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var heading := direction
	if heading.length_squared() < 0.01:
		heading = horizontal if horizontal.length_squared() > 0.01 else -_frog.camera_rig.flat_basis().z
	horizontal = horizontal.move_toward(heading.normalized() * speed, acceleration * delta)
	_frog.velocity = Vector3(horizontal.x, maxf(velocity.y - _frog.gravity_down * delta, -fall_speed), horizontal.z)


func close() -> void:
	gliding = false
	if _wing and _wing.visible and not _folding:
		_folding = true
		var tween := _new_tween()
		tween.tween_property(_wing, "scale", Vector3(0.05, 1.0, 0.6), 0.12).set_ease(Tween.EASE_IN)
		tween.tween_callback(_hide_wing)


## Serve una nuova pressione in aria, lontano dal suolo e fuori dal coyote
## time; vicino al suolo la stessa pressione resta un salto anticipato.
func _can_open() -> bool:
	if charge <= 0.0 or _frog.time_since_floor() <= _frog.coyote_time:
		return false
	var from := _frog.global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (min_height + 0.1), 1 | 4 | 8)
	query.exclude = [_frog.get_rid()]
	return _frog.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Le ali si aprono di lato con un piccolo rimbalzo.
func _unfold() -> void:
	_folding = false
	_wing.visible = true
	_wing.scale = Vector3(0.05, 1.0, 0.6)
	var tween := _new_tween()
	tween.tween_property(_wing, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_wing() -> void:
	_wing.visible = false
	_folding = false


func _new_tween() -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	return _tween
