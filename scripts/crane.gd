class_name Crane
extends AnimatableBody3D
## Una gru a portale del porto: scorre lungo X sopra il blocco e lascia
## cadere container. Quando mira alla rana la insegue, e calcola dove sarà
## (i nastri la portano di lato): l'ombra a terra lampeggia mentre la gru
## insegue, poi resta accesa fissa per lock_time secondi, quando la gru si è
## bloccata e il container sta per cadere. Più sale il calore, più spesso la
## gru mira alla rana, più è veloce e meno avvisa: il mondo reagisce. Le gambe
## sono solide e spingono via chi è in mezzo.

const MODEL := preload("res://assets/models/crane.glb")
const HALF_SPAN := 7.0
## Quota del centro del container appeso sotto lo spreader.
const HANG_Y := 11.5

enum Phase { MOVING, WARNING, RELOADING }

## Il container non cade e basta: lo spreader lo spinge giù, e pesa.
const DROP_SPEED := 6.0
const DROP_GRAVITY_SCALE := 2.5

var play_half_width := 37.0
## Valori a calore zero e al calore massimo.
var speed := 6.0
var max_heat_speed := 11.0
var warning_time := 1.5
var max_heat_warning_time := 1.1
## Gli ultimi secondi dell'avviso, quando la gru non insegue più.
var lock_time := 0.6
var max_heat_lock_time := 0.45
var reload_time := 2.5
var max_heat_reload_time := 1.5
## Probabilità che miri alla rana: base e in più al calore massimo.
var aim_chance := 0.25
var max_heat_aim_bonus := 0.6
## Inseguendo, la gru inizia l'avviso quando è a questa distanza dal punto
## in cui sarà la rana.
var chase_margin := 3.0

var phase := Phase.MOVING
var target_x := 0.0
## Vero se questo container è per la rana.
var aimed := false

var _timer := 0.0
var _hanging: Node3D
var _shadow: MeshInstance3D
var _blink := 0.0
var _frog: Node3D


func _init() -> void:
	# Da impostare prima che il corpo entri nella scena (vedi Airplane.create).
	sync_to_physics = true


func _ready() -> void:
	collision_layer = 1 # come il terreno: le gambe sono muri che si muovono
	collision_mask = 0
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	Style.apply_palette(model)
	for z in [HALF_SPAN, -HALF_SPAN]:
		for x in [2.2, -2.2]:
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.6, 15.0, 0.6)
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = Vector3(x, 7.5, z)
			add_child(collision)

	_shadow = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ShippingContainer.SIZE.x + 0.4, 0.04, ShippingContainer.SIZE.z + 0.4)
	mesh.material = Style.material("drop_warning")
	_shadow.mesh = mesh
	_shadow.visible = false
	add_child(_shadow)
	_frog = get_tree().get_first_node_in_group("frog")
	_reload()
	_choose_target()


func _physics_process(delta: float) -> void:
	var move_speed := lerpf(speed, max_heat_speed, Heat.ratio())
	match phase:
		Phase.MOVING:
			if aimed:
				_predict_target(_warning_time() + fall_time())
			position.x = move_toward(position.x, target_x, move_speed * delta)
			var margin := chase_margin if aimed else 0.0
			if absf(position.x - target_x) <= margin + 0.001:
				phase = Phase.WARNING
				_timer = _warning_time()
		Phase.WARNING:
			if not is_locked():
				if aimed:
					_predict_target(_timer + fall_time())
				position.x = move_toward(position.x, target_x, move_speed * delta)
			_timer -= delta
			if _timer <= 0.0:
				_drop()
		Phase.RELOADING:
			_timer -= delta
			if _timer <= 0.0:
				_reload()
				_choose_target()
	_blink = fmod(_blink + delta, 0.3)
	_shadow.visible = phase == Phase.WARNING and (is_locked() or _blink < 0.18)
	_shadow.global_position = Vector3(global_position.x, 0.33, global_position.z)


## Vero mentre l'ombra è a terra, prima della caduta.
func is_warning() -> bool:
	return phase == Phase.WARNING


## Vero negli ultimi istanti dell'avviso: la gru non si muove più e l'ombra
## resta accesa fissa.
func is_locked() -> bool:
	return phase == Phase.WARNING and _timer <= lerpf(lock_time, max_heat_lock_time, Heat.ratio())


## Quanto ci mette il container a toccare terra.
static func fall_time() -> float:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * DROP_GRAVITY_SCALE
	var height := HANG_Y - ShippingContainer.SIZE.y / 2.0
	return (-DROP_SPEED + sqrt(DROP_SPEED * DROP_SPEED + 2.0 * gravity * height)) / gravity


func _warning_time() -> float:
	return lerpf(warning_time, max_heat_warning_time, Heat.ratio())


func _choose_target() -> void:
	var chance := aim_chance + max_heat_aim_bonus * Heat.ratio()
	aimed = _frog != null and randf() < chance
	if aimed:
		_predict_target(_warning_time() + fall_time())
	else:
		var limit := play_half_width - 6.0
		target_x = randf_range(-limit, limit)
	phase = Phase.MOVING


## Dove sarà la rana fra seconds secondi, se continua così: la sua velocità
## comprende quella del nastro su cui sta.
func _predict_target(seconds: float) -> void:
	var limit := play_half_width - 6.0
	var velocity: Vector3 = _frog.get_real_velocity() if _frog is CharacterBody3D else Vector3.ZERO
	var x: float = _frog.global_position.x + velocity.x * seconds - get_parent().global_position.x
	target_x = clampf(x, -limit, limit)


func _drop() -> void:
	var drop := ShippingContainer.new()
	get_parent().add_child(drop)
	drop.global_transform = _hanging.global_transform
	drop.gravity_scale = DROP_GRAVITY_SCALE
	drop.linear_velocity = Vector3.DOWN * DROP_SPEED
	_hanging.queue_free()
	_hanging = null
	phase = Phase.RELOADING
	_timer = lerpf(reload_time, max_heat_reload_time, Heat.ratio())


## Un nuovo container appeso: per ora solo da vedere, cade come corpo fisico.
func _reload() -> void:
	_hanging = ShippingContainer.MODEL.instantiate()
	_hanging.position.y = HANG_Y
	add_child(_hanging)
	Style.apply_palette(_hanging, {"paint": "container_%d" % (randi() % ShippingContainer.COLORS)})
