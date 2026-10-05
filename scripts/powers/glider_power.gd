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

@export_group("Getto dei motori")
## Quanto in fretta il getto degli aerei porta il deltaplano alla sua velocità.
@export var wind_acceleration := 45.0
## Nel getto si sale fino a questa velocità e la carica non si consuma: il
## getto è un ascensore che porta abbastanza in alto da superare l'aeroporto.
## Come nelle correnti calde, dentro si rallenta (wind_speed_factor) e il
## vento spinge meno (wind_push_factor): altrimenti se ne uscirebbe subito.
@export var wind_rise_speed := 10.0
@export var wind_speed_factor := 0.4
@export var wind_push_factor := 0.5

var charge := 0.0
var gliding := false
## Power-up "Correnti calde" equipaggiato.
var thermals := false
## Power-up "Ala a reazione": più veloce, ma scalda finché si vola.
var jet := false
@export var jet_speed := 16.0
@export var jet_acceleration := 35.0
@export var jet_heat_per_second := 1.5
## Napalm (fusione): le colonne di fumo sono più larghe.
var wide_thermals := false
## Miglioramenti speciali. Correnti calde: fenice (nel fumo si recupera
## vita) e camino (anche il fumo dell'incendio solleva). Ala a reazione:
## postbruciatore (una scia di fuoco ribalta le auto sotto) e raffreddata
## (in volo il calore non sale).
var phoenix := false
var chimney := false
var afterburner := false
var cooled := false
@export var phoenix_heal_per_second := 10.0
## Il fumo dell'incendio solleva fin dove arriva davanti al fronte.
@export var chimney_depth := 25.0
## Vero mentre il deltaplano sale in una colonna di fumo.
var in_thermal := false

var _frog: Frog
var _wing: Node3D
var _tween: Tween
var _folding := false
var _model: Node3D
## Il rottame la cui colonna di fumo solleva la rana (null nel fumo
## dell'incendio, che non attira verso un centro).
var _thermal_source: Car
var _thermal_time := 0.0
var _heal_owed := 0.0
## Metri volati in questo volo con l'ala a reazione.
var _flight := 0.0
var _afterburn_query := PhysicsShapeQueryParameters3D.new()


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
		if jet and not cooled:
			Heat.add(jet_heat_per_second * delta)
		# Nelle correnti calde e nel getto dei motori la carica non si consuma.
		_thermal_source = _smoke_below() if thermals else null
		in_thermal = _thermal_source != null or (thermals and chimney and _over_fire())
		_track_thermal(delta)
		if jet:
			_track_jet(delta)
		if not in_thermal and _frog.wind_lift() == 0.0:
			charge = maxf(charge - delta, 0.0)
		if not Input.is_action_pressed("jump") or charge == 0.0:
			close()
	elif Input.is_action_just_pressed("jump") and _frog.can_act() and _can_open():
		gliding = true
		_flight = 0.0
		_unfold()
		Sfx.play(&"glider_open")
		Sfx.loop(_frog, &"glide_wind")
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
	var target := heading.normalized() * (jet_speed if jet else speed)
	var vertical := maxf(velocity.y - _frog.gravity_down * delta, -fall_speed)
	# Il getto dei motori: spinge e, col deltaplano aperto, solleva.
	var lift := _frog.wind_lift()
	if lift > 0.0:
		vertical = minf(velocity.y + lift * delta, wind_rise_speed)
		target = target.limit_length(speed * wind_speed_factor)
	if in_thermal:
		vertical = minf(velocity.y + thermal_lift * delta, thermal_rise_speed)
		if direction.length_squared() < 0.01 and _thermal_source:
			var to_center := _thermal_source.global_position - _frog.global_position
			target = Vector3(to_center.x, 0.0, to_center.z) * thermal_centering
		target = target.limit_length(speed * thermal_speed_factor)
	# Nel getto dei motori la spinta arriva subito: il getto catapulta.
	var push := _frog.wind_push() * wind_push_factor
	var rate := acceleration if push == Vector3.ZERO else wind_acceleration
	if jet and push == Vector3.ZERO:
		rate = jet_acceleration
	horizontal = horizontal.move_toward(target + push, rate * delta)
	_frog.velocity = Vector3(horizontal.x, vertical, horizontal.z)


## Equipaggia o toglie le correnti calde; si vede: le strisce dell'ala
## diventano rosse.
func set_thermals(on: bool) -> void:
	thermals = on
	_refresh_wing()


## Ala a reazione; si vede: le strisce dell'ala diventano azzurre.
func set_jet(on: bool) -> void:
	jet = on
	_refresh_wing()


func _refresh_wing() -> void:
	var stripe := "wing_hot" if thermals else ("wing_jet" if jet else "")
	Style.apply_palette(_model, {"wing_stripe": stripe} if stripe != "" else {})


## Le prove di correnti calde e fenice: salita nel fumo, secondi di fila.
func _track_thermal(delta: float) -> void:
	if not in_thermal:
		_thermal_time = 0.0
		return
	_thermal_time += delta
	Progress.trial_add("thermals", 0, maxf(_frog.velocity.y, 0.0) * delta)
	Progress.trial_best("thermals", 1, _thermal_time)
	if phoenix:
		_heal_owed += phoenix_heal_per_second * delta
		if _heal_owed >= 1.0:
			_frog.heal(floori(_heal_owed))
			_heal_owed -= floori(_heal_owed)


## Le prove dell'ala a reazione e il postbruciatore.
func _track_jet(delta: float) -> void:
	var travelled := Vector2(_frog.velocity.x, _frog.velocity.z).length() * delta
	_flight += travelled
	Progress.trial_add("jet_wing", 0, travelled)
	Progress.trial_best("jet_wing", 1, _flight)
	if afterburner:
		_burn_below()


## Il postbruciatore: le auto sotto l'ala, fino a 8 m più in basso, diventano
## rottami.
func _burn_below() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 8.0, 4.0)
	_afterburn_query.shape = box
	_afterburn_query.collision_mask = 4
	_afterburn_query.transform = Transform3D(Basis(), _frog.global_position + Vector3.DOWN * 4.0)
	for result in _frog.get_world_3d().direct_space_state.intersect_shape(_afterburn_query, 8):
		var car := result.collider as Car
		if car and car.state == Car.State.DRIVING:
			car.become_wreck()


## Camino: davanti all'incendio, dove arriva il suo fumo, si sale come in una
## corrente calda. Premia chi resta vicino al fuoco, a suo rischio.
func _over_fire() -> bool:
	var fire := _frog.get_tree().get_first_node_in_group("wildfire") as Node3D
	if fire == null:
		return false
	var ahead: float = fire.front_z - _frog.global_position.z
	return ahead > 1.0 and ahead < chimney_depth and _frog.global_position.y < thermal_height


## Il rottame nella cui colonna di fumo si trova la rana (null se nessuno).
func _smoke_below() -> Car:
	var position := _frog.global_position
	for car in Car.smoking_wrecks():
		var offset := position - car.global_position
		if Vector2(offset.x, offset.z).length() < thermal_radius * (1.6 if wide_thermals else 1.0) and offset.y > -1.0 and offset.y < thermal_height:
			return car
	return null


func close() -> void:
	gliding = false
	in_thermal = false
	if Sfx.is_looping(_frog, &"glide_wind"):
		Sfx.unloop(_frog, &"glide_wind")
	if _wing and _wing.visible and not _folding:
		_folding = true
		Sfx.play(&"glider_close")
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
