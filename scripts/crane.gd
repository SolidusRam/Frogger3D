class_name Crane
extends AnimatableBody3D
## Una gru a portale del porto: scavalca una corsia d'acqua con le gambe sulle
## due banchine, scorre lungo X, e il suo carrello scorre lungo il braccio (Z).
## Carica le navi che passano: sceglie una casella, la insegue mentre la nave
## avanza e lascia cadere il container. L'ombra lampeggia mentre la gru
## insegue, poi resta accesa fissa per lock_time secondi, quando la gru si è
## bloccata e il container sta per cadere.
## Sotto il livello Heat.STEP_LEVEL di calore la gru carica seguendo lo
## schema: mai dove sta la rana, e lasciando sempre un passaggio tra le
## caselle vuote. Da quel livello (il gradino del porto) la gru più vicina dà
## la caccia alla rana quando è su una nave, e prevede dove la nave la porterà.
## Le gambe sono solide e spingono via chi è in mezzo.

const MODEL := preload("res://assets/models/crane.glb")
const TROLLEY_MODEL := preload("res://assets/models/crane_trolley.glb")
## Quota del centro del container appeso sotto lo spreader.
const HANG_Y := 11.5
## Fin dove arriva il carrello, dal centro della corsia.
const TROLLEY_RANGE := 4.5
## Il container non cade e basta: lo spreader lo spinge giù, e pesa.
const DROP_SPEED := 6.0
const DROP_GRAVITY_SCALE := 2.5

enum Phase { IDLE, MOVING, WARNING, RELOADING }

## La corsia d'acqua della gru e la metà in cui lavora (in coordinate della
## corsia).
var lane: ShipLane
var min_x := -33.0
var max_x := 33.0
## Valori a calore zero e al calore massimo.
var speed := 6.0
var max_heat_speed := 11.0
var trolley_speed := 6.0
var warning_time := 1.5
var max_heat_warning_time := 1.1
## Gli ultimi secondi dell'avviso, quando la gru non insegue più.
var lock_time := 0.6
var max_heat_lock_time := 0.45
var reload_time := 2.5
var max_heat_reload_time := 1.5
## Inseguendo, l'avviso comincia quando la gru è a questa distanza dal punto
## in cui cadrà il container.
var chase_margin := 3.0

var phase := Phase.IDLE
var target_x := 0.0
var target_z := 0.0
## Vero se questo container è per la rana.
var aimed := false

var _timer := 0.0
var _ship: Ship
var _cell := Vector2i(-1, -1)
var _trolley: Node3D
var _hanging: Node3D
var _hanging_color := 0
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
	for z in [7.0, -7.0]:
		for x in [2.2, -2.2]:
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.6, 15.0, 0.6)
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = Vector3(x, 7.5, z)
			add_child(collision)
	_trolley = TROLLEY_MODEL.instantiate()
	add_child(_trolley)
	Style.apply_palette(_trolley)

	_shadow = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	# Come il container sulla nave: lungo X.
	mesh.size = Vector3(ShippingContainer.SIZE.z + 0.4, 0.04, ShippingContainer.SIZE.x + 0.4)
	mesh.material = Style.material("drop_warning")
	_shadow.mesh = mesh
	_shadow.visible = false
	add_child(_shadow)
	_frog = get_tree().get_first_node_in_group("frog")
	_reload()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_choose_target()
		Phase.MOVING:
			if not _update_target(_warning_time() + fall_time(_target_level())):
				_give_up()
			else:
				_move(delta)
				if absf(position.x - target_x) <= chase_margin and absf(_trolley.position.z - target_z) <= 1.0:
					phase = Phase.WARNING
					_timer = _warning_time()
					Sfx.loop(_trolley, &"crane_warning", 0.0, 1.0, 1.5)
		Phase.WARNING:
			if not is_locked():
				if _update_target(_timer + fall_time(_target_level())):
					_move(delta)
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
	if _shadow.visible:
		_place_shadow()


## Vero mentre l'ombra è a terra, prima della caduta.
func is_warning() -> bool:
	return phase == Phase.WARNING


## Vero negli ultimi istanti dell'avviso: la gru non si muove più e l'ombra
## resta accesa fissa.
func is_locked() -> bool:
	return phase == Phase.WARNING and _timer <= lerpf(lock_time, max_heat_lock_time, Heat.ratio())


## Quanto ci mette il container a cadere da sotto lo spreader al piano dato
## di una nave.
static func fall_time(level := 0) -> float:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * DROP_GRAVITY_SCALE
	var height := HANG_Y - Ship.cell_position(Vector2i.ZERO, level).y
	return (-DROP_SPEED + sqrt(DROP_SPEED * DROP_SPEED + 2.0 * gravity * height)) / gravity


## Il punto della corsia in cui la gru lascerebbe cadere ora il container.
func drop_point() -> Vector3:
	return Vector3(position.x, 0.0, _trolley.position.z)


func _warning_time() -> float:
	return lerpf(warning_time, max_heat_warning_time, Heat.ratio())


func _target_level() -> int:
	return _ship.level(_cell) if is_instance_valid(_ship) else 0


func _choose_target() -> void:
	_release()
	aimed = _should_hunt()
	if aimed:
		_ship = lane.ship_under(_frog.global_position)
		_cell = Ship.cell_at(_ship.to_local(_frog.global_position))
		if _update_target(_warning_time() + fall_time(_target_level())):
			phase = Phase.MOVING
			return
		aimed = false
	if not _pick_cell():
		phase = Phase.IDLE
		_timer = 0.5
		return
	_ship.reserve(_cell)
	phase = Phase.MOVING


## Dal livello Heat.STEP_LEVEL, se la rana è su una nave di questa corsia e questa
## è la gru più vicina a dove la rana sarà fra poco.
func _should_hunt() -> bool:
	if Heat.level() < Heat.STEP_LEVEL or _frog == null or lane == null:
		return false
	if lane.ship_under(_frog.global_position) == null:
		return false
	# Caccia la gru più vicina a dove sarà la rana, non a dove è adesso.
	var velocity: Vector3 = _frog.get_real_velocity() if _frog is CharacterBody3D else Vector3.ZERO
	return lane.nearest_crane(_frog.global_position + velocity * 2.0) == self


## Sceglie una casella da caricare seguendo lo schema, su una nave che fra
## poco sarà nella metà della gru.
func _pick_cell() -> bool:
	var frog_ship: Ship = lane.ship_under(_frog.global_position) if _frog else null
	var options := []
	for ship in lane.ships():
		var avoid := Vector2i(-1, -1)
		if ship == frog_ship:
			avoid = Ship.cell_at(ship.to_local(_frog.global_position))
		for cell in ship.loading_candidates(lane.loading_cap, avoid):
			var later := ship.to_global(Ship.cell_position(cell, ship.level(cell))) + ship.motion_velocity() * 3.0
			var x := lane.to_local(later).x
			if x > min_x + 1.0 and x < max_x - 1.0:
				options.append([ship, cell, absf(x - position.x)])
	if options.is_empty():
		return false
	# Tra le più vicine, a caso: la gru non fa avanti e indietro.
	options.sort_custom(func(a, b): return a[2] < b[2])
	var pick: Array = options[randi() % mini(3, options.size())]
	_ship = pick[0]
	_cell = pick[1]
	return true


## Aggiorna il punto da inseguire: dove sarà la casella fra seconds secondi.
## Se la gru caccia la rana, la casella è quella in cui sarà la rana. Falso se
## la nave non c'è più o la casella esce dalla metà della gru.
func _update_target(seconds: float) -> bool:
	if not is_instance_valid(_ship) or _ship.is_queued_for_deletion():
		return false
	if aimed and lane.ship_under(_frog.global_position) == _ship:
		var frog_velocity: Vector3 = _frog.get_real_velocity() if _frog is CharacterBody3D else Vector3.ZERO
		var later := _frog.global_position + (frog_velocity - _ship.motion_velocity()) * seconds
		var cell := Ship.cell_at(_ship.to_local(later))
		if _ship.level(cell) < Ship.MAX_STACK:
			_cell = cell
	var landing := _ship.to_global(Ship.cell_position(_cell, _ship.level(_cell))) + _ship.motion_velocity() * seconds
	var local := lane.to_local(landing)
	target_x = clampf(local.x, min_x, max_x)
	target_z = clampf(local.z, -TROLLEY_RANGE, TROLLEY_RANGE)
	return absf(local.x - target_x) < 0.5


func _move(delta: float) -> void:
	position.x = move_toward(position.x, target_x, lerpf(speed, max_heat_speed, Heat.ratio()) * delta)
	_trolley.position.z = move_toward(_trolley.position.z, target_z, trolley_speed * delta)


func _give_up() -> void:
	_release()
	phase = Phase.IDLE
	_timer = 0.3


func _release() -> void:
	if is_instance_valid(_ship) and _cell.x >= 0:
		_ship.release(_cell)
	_ship = null
	_cell = Vector2i(-1, -1)


## L'ombra sta sulla casella della nave che verrà colpita e viaggia con lei:
## dice "qui sta per cadere", anche se il container è ancora più avanti.
## Senza nave, sotto il container appeso.
func _place_shadow() -> void:
	if is_instance_valid(_ship) and _cell.x >= 0:
		var top := Ship.cell_position(_cell, _ship.level(_cell)) - Vector3(0.0, ShippingContainer.SIZE.y / 2.0 - 0.03, 0.0)
		_shadow.global_position = _ship.to_global(top)
		_shadow.global_rotation = _ship.global_rotation
		return
	var from := _hanging.global_position + Vector3.DOWN * (ShippingContainer.SIZE.y / 2.0 + 0.1)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0, 1 | 8)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var y: float = hit.position.y if not hit.is_empty() else -0.35
	_shadow.global_position = Vector3(_hanging.global_position.x, y + 0.03, _hanging.global_position.z)
	_shadow.global_rotation = Vector3.ZERO


func _drop() -> void:
	Sfx.unloop(_trolley, &"crane_warning")
	Sfx.play_at(&"crane_release", _hanging.global_position, 0.0, 1.0, 1.5)
	var drop := ShippingContainer.new()
	drop.color_index = _hanging_color
	get_parent().add_child(drop)
	drop.global_transform = _hanging.global_transform
	drop.gravity_scale = DROP_GRAVITY_SCALE
	drop.linear_velocity = Vector3.DOWN * DROP_SPEED
	_hanging.queue_free()
	_hanging = null
	# La prenotazione della casella resta finché il container non arriva.
	_ship = null
	_cell = Vector2i(-1, -1)
	phase = Phase.RELOADING
	_timer = lerpf(reload_time, max_heat_reload_time, Heat.ratio())


## Un nuovo container appeso: per ora solo da vedere, cade come corpo fisico.
func _reload() -> void:
	_hanging_color = randi() % ShippingContainer.COLORS
	_hanging = ShippingContainer.MODEL.instantiate()
	_hanging.position.y = HANG_Y
	_hanging.rotation.y = PI / 2.0
	_trolley.add_child(_hanging)
	Style.apply_palette(_hanging, {"paint": "container_%d" % _hanging_color})
