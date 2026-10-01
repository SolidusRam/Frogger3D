extends Node3D
## La partita: collega i poteri al calore, chiude la run alla morte della rana,
## salva il record e fa ricominciare.

const RECORD_PATH := "user://record.cfg"

@export var frog: Frog
@export var course: Course
@export var hud: Hud

var run_time := 0.0
var max_heat_level := 0
var record_distance := 0.0

var _over := false


func _ready() -> void:
	Heat.reset()
	record_distance = _load_record()
	frog.power_used.connect(Heat.on_power_used)
	frog.died.connect(_on_frog_died)
	course.den_reached.connect(_on_den_reached)
	hud.restart_requested.connect(restart)
	hud.set_record(record_distance)


func _process(delta: float) -> void:
	if not _over:
		run_time += delta
		max_heat_level = maxi(max_heat_level, Heat.level())


func _unhandled_input(event: InputEvent) -> void:
	if _over and event.is_action_pressed("ui_accept"):
		restart()


func restart() -> void:
	Heat.reset()
	get_tree().reload_current_scene()


## La tana salva i progressi: il record viene scritto subito su disco.
func _on_den_reached(_count: int, distance: float) -> void:
	_save_record_if_better(distance)


func _on_frog_died() -> void:
	_over = true
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
	config.save(RECORD_PATH)
	hud.set_record(record_distance)
	return true


func _load_record() -> float:
	var config := ConfigFile.new()
	if config.load(RECORD_PATH) != OK:
		return 0.0
	return config.get_value("record", "distance", 0.0)
