extends Node3D
## La partita: collega poteri, calore e stile, gestisce i tempi speciali
## (fermo-immagine e rallentatore), chiude la run alla morte della rana,
## salva il record e fa ricominciare.


@export var frog: Frog
@export var course: Course
@export var hud: Hud
@export var environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var post: ColorRect
## File del record; i test ne usano uno loro per non toccare quello vero.
@export var record_path := "user://record.cfg"

@export_group("Tempi speciali")
## Fermo-immagine quando il pugno colpisce un'auto.
@export var hitstop_seconds := 0.11
@export var hitstop_time_scale := 0.03
## Rallentatore sulle catene di rottami vicino alla rana.
@export var chain_size := 4
@export var chain_window_seconds := 1.5
@export var chain_radius := 30.0
@export var slowmo_seconds := 0.8
@export var slowmo_time_scale := 0.3
@export var slowmo_cooldown_seconds := 4.0

var run_time := 0.0
var max_heat_level := 0
var record_distance := 0.0

var _over := false
## Istanti (in ms reali) dei rottami recenti vicino alla rana.
var _recent_wrecks: Array[int] = []
var _hitstop_until := 0
var _slowmo_until := 0
var _slowmo_ready_at := 0


func _ready() -> void:
	Engine.time_scale = 1.0
	Heat.reset()
	Style.bind(environment.environment, sun, post)
	record_distance = _load_record()
	frog.power_used.connect(Heat.on_power_used)
	frog.punched.connect(_on_punched)
	frog.died.connect(_on_frog_died)
	Heat.wreck_created.connect(_on_wreck_created)
	course.den_reached.connect(_on_den_reached)
	hud.restart_requested.connect(restart)
	hud.set_record(record_distance)


func _process(delta: float) -> void:
	_update_time_scale()
	if not _over:
		run_time += delta
		max_heat_level = maxi(max_heat_level, Heat.level())


func _unhandled_input(event: InputEvent) -> void:
	if _over and event.is_action_pressed("ui_accept"):
		restart()


func restart() -> void:
	Engine.time_scale = 1.0
	Heat.reset()
	get_tree().reload_current_scene()


## Il fermo-immagine vince sul rallentatore; il tempo è misurato in ms reali,
## perché Engine.time_scale rallenta anche i timer normali.
func _update_time_scale() -> void:
	var now := Time.get_ticks_msec()
	var time_scale := 1.0
	if now < _slowmo_until:
		time_scale = slowmo_time_scale
	if now < _hitstop_until:
		time_scale = hitstop_time_scale
	Engine.time_scale = time_scale


func _on_punched(cars: Array[Car]) -> void:
	_hitstop_until = Time.get_ticks_msec() + roundi(hitstop_seconds * 1000.0)
	_update_time_scale()
	frog.camera_rig.shake(0.25, 0.25)
	for car in cars:
		_impact_burst(car.global_position.lerp(frog.global_position, 0.5) + Vector3.UP * 0.8)


## Lampo d'impatto: una stella low-poly che esplode e sparisce. Resta ferma
## durante il fermo-immagine, poi si apre: il colpo "scatta" quando riparte.
func _impact_burst(at: Vector3) -> void:
	var burst := MeshInstance3D.new()
	var star := SphereMesh.new()
	star.radius = 0.6
	star.height = 1.2
	star.radial_segments = 5
	star.rings = 2
	star.material = Style.material("spark")
	burst.mesh = star
	add_child(burst)
	burst.global_position = at
	burst.scale = Vector3.ONE * 0.3
	var tween := create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 2.2, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "scale", Vector3.ZERO, 0.12)
	tween.tween_callback(burst.queue_free)


func _on_wreck_created(car: Node3D) -> void:
	if _over or car.global_position.distance_to(frog.global_position) > chain_radius:
		return
	var now := Time.get_ticks_msec()
	_recent_wrecks.append(now)
	var window := roundi(chain_window_seconds * 1000.0)
	_recent_wrecks.assign(_recent_wrecks.filter(func(t: int) -> bool: return now - t <= window))
	var count := _recent_wrecks.size()
	if count < chain_size:
		return
	hud.show_chain(count)
	if now >= _slowmo_ready_at:
		_slowmo_until = now + roundi(slowmo_seconds * 1000.0)
		_slowmo_ready_at = now + roundi(slowmo_cooldown_seconds * 1000.0)
		frog.camera_rig.pull_back(4.0, slowmo_seconds + 0.6)


## La tana salva i progressi: il record viene scritto subito su disco.
func _on_den_reached(_count: int, distance: float) -> void:
	_save_record_if_better(distance)


func _on_frog_died() -> void:
	_over = true
	_slowmo_until = 0
	Heat.running = false
	var distance := course.distance()
	var new_record := _save_record_if_better(distance)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_game_over({
		"distance": distance,
		"dens": course.dens_reached,
		"time": run_time,
		"heat_level": max_heat_level,
		"record": record_distance,
		"new_record": new_record,
	})


func _save_record_if_better(distance: float) -> bool:
	if distance <= record_distance:
		return false
	record_distance = distance
	var config := ConfigFile.new()
	config.set_value("record", "distance", distance)
	config.save(record_path)
	hud.set_record(record_distance)
	return true


func _load_record() -> float:
	var config := ConfigFile.new()
	if config.load(record_path) != OK:
		return 0.0
	return config.get_value("record", "distance", 0.0)
