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

@export_group("Correnti calde")
## Con le correnti calde, sopra un rottame che fuma si sale: accelerazione e
## velocità massima di salita, raggio e altezza della colonna di fumo.
@export var thermal_lift := 18.0
@export var thermal_rise_speed := 4.0
@export var thermal_radius := 4.5
@export var thermal_height := 30.0
## Nella colonna il deltaplano rallenta a questa frazione della velocità e,
## senza tasti, viene attirato verso il centro: un ascensore da cui si esce
## sterzando.
@export var thermal_speed_factor := 0.4
@export var thermal_centering := 2.0

var charge := 0.0
var gliding := false
## Power-up "Correnti calde" equipaggiato.
var thermals := false
## Vero mentre il deltaplano sale in una colonna di fumo.
var in_thermal := false

var _frog: Frog
var _wing: Node3D
var _tween: Tween
var _folding := false
var _model: Node3D
## Il rottame la cui colonna di fumo solleva la rana.
var _thermal_source: Car


func setup(frog: Frog) -> void:
	_frog = frog
	charge = duration
	_wing = frog.glider
	_model = MODEL.instantiate()
	_wing.add_child(_model)
	Style.apply_palette(_model)
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
		# Nelle correnti calde la carica non si consuma.
		_thermal_source = _smoke_below() if thermals else null
		in_thermal = _thermal_source != null
		if not in_thermal:
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
	var target := heading.normalized() * speed
	var vertical := maxf(velocity.y - _frog.gravity_down * delta, -fall_speed)
	if in_thermal:
		vertical = minf(velocity.y + thermal_lift * delta, thermal_rise_speed)
		if direction.length_squared() < 0.01:
			var to_center := _thermal_source.global_position - _frog.global_position
			target = Vector3(to_center.x, 0.0, to_center.z) * thermal_centering
		target = target.limit_length(speed * thermal_speed_factor)
	horizontal = horizontal.move_toward(target, acceleration * delta)
	_frog.velocity = Vector3(horizontal.x, vertical, horizontal.z)


## Equipaggia o toglie le correnti calde; si vede: le strisce dell'ala
## diventano rosse.
func set_thermals(on: bool) -> void:
	thermals = on
	Style.apply_palette(_model, {"wing_stripe": "wing_hot"} if on else {})


## Il rottame nella cui colonna di fumo si trova la rana (null se nessuno).
func _smoke_below() -> Car:
	var position := _frog.global_position
	for car in Car.smoking_wrecks():
		var offset := position - car.global_position
		if Vector2(offset.x, offset.z).length() < thermal_radius and offset.y > -1.0 and offset.y < thermal_height:
			return car
	return null


func close() -> void:
	gliding = false
	in_thermal = false
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
