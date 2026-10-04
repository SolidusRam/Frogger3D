extends Node3D
## La partita: collega poteri, calore e stile, gestisce i tempi speciali
## (fermo-immagine e rallentatore), chiude la run alla morte della rana,
## salva il record e fa ricominciare.
## Fa anche da sfondo al menu (attract): il mondo vive, ma la rana aspetta,
## calore e incendio sono fermi e l'HUD è nascosto; start_run() fa partire
## la run sul posto.

const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"


@export var frog: Frog
@export var course: Course
@export var hud: Hud
@export var environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var post: ColorRect
@export var upgrades: Upgrades
## File del record e dei progressi (mosche, stagno); i test ne usano di loro
## per non toccare quelli veri.
@export var record_path := "user://record.cfg"
@export var progress_path := "user://progressi.cfg"
## Vero quando la partita fa da sfondo al menu (lo imposta il menu).
@export var attract := false
## Secondi in cui la telecamera torna dietro la rana quando parte la run.
@export var start_seconds := 0.9

@export_group("Mosche")
## Mosche date da ogni tana, e in più quando la tana non ha carte da offrire
## (con la vita piena).
@export var den_flies := 3
@export var empty_den_flies := 8

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
## Run di prova (vedi TestMode): il record non si salva.
var test_run := false
## Mosche raccolte in questa run, normali e d'oro (si sommano al totale a
## fine run).
var run_flies := 0
var run_golden := 0
## Statistiche dello stagno che servono durante la run.
var fly_magnet := 0.0
var fly_value := 1.0
var den_regen := 0.0
var max_heat_level := 0
var record_distance := 0.0

var _over := false
## Istanti (in ms reali) dei rottami recenti vicino alla rana.
var _recent_wrecks: Array[int] = []
var _hitstop_until := 0
var _slowmo_until := 0
var _slowmo_ready_at := 0


func _ready() -> void:
	add_to_group("game")
	Engine.time_scale = 1.0
	Heat.reset()
	Progress.load_from(progress_path)
	_apply_stats()
	Style.bind(environment.environment, sun, post)
	record_distance = _load_record()
	frog.power_used.connect(Heat.on_power_used)
	frog.punched.connect(_on_punched)
	frog.died.connect(_on_frog_died)
	Heat.wreck_created.connect(_on_wreck_created)
	course.den_reached.connect(_on_den_reached)
	hud.restart_requested.connect(restart)
	hud.menu_requested.connect(to_menu)
	hud.abandon_requested.connect(abandon)
	upgrades.equipped.connect(_on_equipped)
	frog.revived.connect(hud.announce.bind("Seconda vita!"))
	hud.set_record(record_distance)
	add_child(PerfOverlay.new())
	if attract:
		_enter_attract()
	else:
		add_child(TestMode.new())


## Lo sfondo del menu: il traffico passa, la telecamera gira attorno alla
## rana che aspetta, l'incendio è fermo all'orizzonte.
func _enter_attract() -> void:
	Heat.running = false
	hud.visible = false
	frog.asleep = true
	$Wildfire.stopped = true
	frog.camera_rig.start_orbit()


## Dal menu alla run, senza cambiare scena: la telecamera torna dietro la
## rana, l'HUD compare, calore e incendio partono.
func start_run() -> void:
	if not attract:
		return
	attract = false
	Heat.reset()
	run_time = 0.0
	hud.visible = true
	frog.asleep = false
	var fire: Wildfire = $Wildfire
	fire.stopped = false
	fire.front_z = frog.global_position.z + fire.max_gap
	frog.camera_rig.end_orbit(start_seconds)
	add_child(TestMode.new())


func _process(delta: float) -> void:
	_update_time_scale()
	if not _over and not attract:
		run_time += delta
		max_heat_level = maxi(max_heat_level, Heat.level())


func _unhandled_input(event: InputEvent) -> void:
	if _over and event.is_action_pressed("ui_accept"):
		restart()


func restart() -> void:
	Engine.time_scale = 1.0
	Heat.reset()
	# Una run nuova parte subito, senza menu.
	get_tree().change_scene_to_file(GAME_SCENE)


func to_menu() -> void:
	Engine.time_scale = 1.0
	Heat.reset()
	# Nel menu il calore non sale: la run nuova lo fa ripartire.
	Heat.running = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


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
	# I rottami dell'incendio non fanno catena: il fuoco che passa su una strada
	# non deve far scattare il rallentatore.
	if _over or car.has_meta("burnt") or car.global_position.distance_to(frog.global_position) > chain_radius:
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


## La tana salva i progressi: il record viene scritto subito su disco. Poi il
## gioco si ferma e si sceglie un power-up, uno tra tre.
func _on_den_reached(_count: int, distance: float) -> void:
	_save_record_if_better(distance)
	if _over:
		return
	add_flies(den_flies)
	if den_regen > 0.0:
		frog.health = mini(frog.health + roundi(frog.max_health * den_regen), frog.max_health)
		frog.health_changed.emit(frog.health, frog.max_health)
	offer_upgrade()


## Mosche raccolte (la statistica "Golosa" ne aggiunge, con l'arrotondamento
## a caso). A run finita non si raccoglie più niente: il totale è già salvato.
func add_flies(amount: int) -> void:
	if _over:
		return
	var value := amount * fly_value
	var whole := floori(value)
	if randf() < value - whole:
		whole += 1
	run_flies += whole
	hud.set_flies(run_flies, run_golden)


## Una mosca d'oro: serve ad attivare i miglioramenti delle carte.
func add_golden(amount: int) -> void:
	if _over:
		return
	run_golden += amount
	hud.set_flies(run_flies, run_golden)


## Ferma il gioco e offre tre power-up (anche dalla modalità prova). Se la
## tana non ha più carte da offrire, dà vita piena e mosche.
func offer_upgrade() -> void:
	var options := upgrades.make_offer()
	if options.is_empty():
		frog.heal_full()
		add_flies(empty_den_flies)
		hud.announce("Niente da scegliere: vita piena e %d mosche" % empty_den_flies)
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_offer(options, upgrades)


func _on_equipped(id: String) -> void:
	hud.hide_offer()
	hud.show_equipment(upgrades)
	hud.announce("Equipaggiato: %s" % Upgrades.CATALOG[id].name)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_frog_died() -> void:
	var stats := _finish_run()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_game_over(stats)


## Dalla pausa: la run finisce come se la rana fosse morta (record, mosche e
## prove delle carte contano) e si torna al menu.
func abandon() -> void:
	if not _over:
		_finish_run()
	to_menu()


## Chiude la run: salva record, mosche e prove, e restituisce i numeri per la
## schermata di fine.
func _finish_run() -> Dictionary:
	_over = true
	_slowmo_until = 0
	Heat.running = false
	var distance := course.distance()
	var new_record := _save_record_if_better(distance)
	# Come il record: una run di prova non conta, né per le mosche né per le
	# prove delle carte.
	if test_run:
		Progress.run_trials = {}
	else:
		Progress.add_flies(run_flies, run_golden)
		Progress.commit_run()
	return {
		"distance": distance,
		"dens": course.dens_reached,
		"time": run_time,
		"heat_level": max_heat_level,
		"record": record_distance,
		"new_record": new_record,
		"flies": run_flies,
		"golden": run_golden,
		"total_flies": Progress.flies,
		"total_golden": Progress.golden,
		"test_run": test_run,
	}


## Le statistiche comprate allo stagno, all'inizio di ogni run.
func _apply_stats() -> void:
	frog.max_health += 10 * Progress.level("health")
	frog.heal_full()
	frog.damage_factor = 1.0 - 0.05 * Progress.level("armor")
	den_regen = 0.15 * Progress.level("regen")
	frog.invulnerability_duration += 0.25 * Progress.level("invuln")
	frog.move_speed *= 1.0 + 0.04 * Progress.level("speed")
	frog.jump_height *= 1.0 + 0.08 * Progress.level("jump")
	frog.compute_jump()
	frog.swim_speed *= 1.0 + 0.15 * Progress.level("swim")
	frog.base_swim_speed = frog.swim_speed
	frog.water_damage_per_second *= 1.0 - 0.15 * Progress.level("swim")
	frog.super_jump_power.height += 0.5 * Progress.level("super_jump")
	frog.cooldown_factor = 1.0 - 0.06 * Progress.level("cooldown")
	for power in [frog.super_jump_power, frog.punch_power, frog.tongue_power, frog.slam_power]:
		power.cooldown *= frog.cooldown_factor
	frog.punch_power.impulse *= 1.0 + 0.1 * Progress.level("punch")
	frog.glider_power.duration += 0.3 * Progress.level("glide")
	frog.glider_power.charge = frog.glider_power.duration
	var fire: Wildfire = get_node("Wildfire")
	fire.max_gap += 5.0 * Progress.level("fire")
	fire.front_z = frog.global_position.z + fire.max_gap
	Heat.power_heat_factor = 1.0 - 0.06 * Progress.level("calm")
	fly_magnet = 0.7 * Progress.level("magnet")
	fly_value = 1.0 + 0.1 * Progress.level("greed")
	Fly.golden_factor = 1.0 + 0.5 * Progress.level("luck")
	upgrades.offer_size = 3 + Progress.level("choice")
	frog.extra_lives = Progress.level("revival")


func _save_record_if_better(distance: float) -> bool:
	if test_run or distance <= record_distance:
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
