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
## I suggerimenti del primo minuto (vedi Hints); i test li spengono.
@export var tutorial := true
## La rana (vedi Frogs): "" la scelta nel menu (Progress.frog).
var frog_kind := ""
## Gli attrezzi con cui parte la rana, se non quelli della rana (vedi
## Upgrades.equip_kit): i test partono coi tre attrezzi di prima.
var starting_kit := {}

@export_group("Mosche")
## Mosche date da ogni tana, e in più quando la tana non ha carte da offrire
## (con la vita piena).
@export var den_flies := 3
@export var empty_den_flies := 8
## Il gettone Salta: niente carta, queste mosche.
@export var skip_flies := 5
## L'arrivo in tana: secondi di festa (la rana alza i guantoni, i fiori si
## aprono) prima delle carte. 0: le carte subito, senza festa (i test).
@export var den_celebration_seconds := 0.9

@export_group("Mondi")
## Il mondo nuovo: la rana ci arriva cadendo da questa altezza.
@export var world_drop_height := 12.0
## Chi cade nel vuoto ricompare su una striscia almeno così davanti al fuoco.
@export var void_fire_margin := 3.0

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
## Il livello di Siccità di questa run.
var drought := 0
var record_distance := 0.0

var _over := false
## Istanti (in ms reali) dei rottami recenti vicino alla rana.
var _recent_wrecks: Array[int] = []
var _hitstop_until := 0
var _slowmo_until := 0
var _slowmo_ready_at := 0


func _ready() -> void:
	add_to_group("game")
	Sfx.muffle_world(attract)
	Engine.time_scale = 1.0
	Heat.reset()
	# Senza schermo (i test) mai i file veri del giocatore, anche quando un
	# test ricomincia la partita o cambia scena.
	if DisplayServer.get_name() == "headless":
		progress_path = "user://progressi_test.cfg"
		record_path = "user://record_test.cfg"
	Progress.load_from(progress_path)
	upgrades.reset_tokens()
	if frog_kind == "":
		frog_kind = Frogs.selected()
	preview_frog(frog_kind)
	# Nel menu la rana aspetta: pro, contro, stagno e Siccità valgono da quando
	# parte.
	if not attract:
		_apply_frog_mods()
		_apply_stats()
		_apply_drought()
	Style.bind(environment.environment, sun, post)
	# Ogni run parte dal primo mondo.
	Style.set_world(Worlds.id_of(0))
	_apply_world()
	record_distance = _load_record()
	frog.power_used.connect(Heat.on_power_used)
	frog.punched.connect(_on_punched)
	frog.died.connect(_on_frog_died)
	frog.fell_into_void.connect(_on_fell_into_void)
	Heat.wreck_created.connect(_on_wreck_created)
	course.den_reached.connect(_on_den_reached)
	course.portal_entered.connect(next_world, CONNECT_DEFERRED)
	hud.restart_requested.connect(restart)
	hud.menu_requested.connect(to_menu)
	hud.abandon_requested.connect(abandon)
	upgrades.equipped.connect(_on_equipped)
	upgrades.rarity_bonus.connect(_on_rarity_bonus)
	hud.token_used.connect(_on_token_used)
	frog.revived.connect(func() -> void: hud.announce(tr("Seconda vita!")))
	frog.insured.connect(func() -> void: hud.announce(tr("L'assicurazione paga!")))
	hud.set_record(record_distance)
	add_child(PerfOverlay.new())
	if attract:
		_enter_attract()
	else:
		add_child(TestMode.new())
		_mark_unlocked_test()
		start_hints()
		_start_feats()


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
	Sfx.muffle_world(false)
	Heat.reset()
	_apply_frog_mods()
	_apply_stats()
	_apply_drought()
	upgrades.reset_tokens()
	run_time = 0.0
	hud.visible = true
	frog.asleep = false
	var fire: Wildfire = $Wildfire
	fire.stopped = false
	fire.front_z = frog.global_position.z + fire.max_gap
	frog.camera_rig.end_orbit(start_seconds)
	add_child(TestMode.new())
	_mark_unlocked_test()
	start_hints()
	_start_feats()


## I suggerimenti, se le opzioni li vogliono. Una run di prova avviata da
## tools/prova.sh non li mostra.
## Con "Tutto sbloccato" la run è una prova: niente record, mosche né imprese.
func _mark_unlocked_test() -> void:
	if Settings.unlock_everything:
		test_run = true


func start_hints() -> void:
	if not tutorial or not Settings.hints or has_node("Hints") or not OS.get_cmdline_user_args().is_empty():
		return
	var hints := Hints.new()
	hints.name = "Hints"
	add_child(hints)
	hints.setup(self)


## Le imprese si guardano in ogni run vera (vedi FeatTracker).
func _start_feats() -> void:
	var tracker := FeatTracker.new()
	tracker.name = "Feats"
	add_child(tracker)
	tracker.setup(self)


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
	AudioServer.playback_speed_scale = 1.0
	Heat.reset()
	# Una run nuova parte subito, senza menu.
	get_tree().change_scene_to_file(GAME_SCENE)


func to_menu() -> void:
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
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
	# Nel rallentatore anche il suono si allunga e scende di tono; il
	# fermo-immagine no: il colpo del pugno deve arrivare secco.
	AudioServer.playback_speed_scale = 0.7 if now < _slowmo_until else 1.0


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


## La tana salva i progressi: il record viene scritto subito su disco. La
## rana fa festa per un attimo, poi il gioco si ferma e si sceglie un
## power-up, uno tra tre.
## Superato un livello di Siccità: si apre il prossimo, e forse una pelle.
func _announce_drought() -> void:
	if drought == 0:
		hud.announce(tr("Si apre la Siccità 1!"))
		return
	var text := tr("Siccità %d superata!") % drought
	var tier := Cosmetics.tier_for(drought)
	if tier != "":
		text += " " + tr("Nuova pelle: %s") % tr(Cosmetics.TIERS[tier].name)
	elif drought < Drought.LEVELS.size():
		text += " " + tr("Si apre il livello %d") % (drought + 1)
	hud.announce(text)


func _on_den_reached(count: int, distance: float) -> void:
	_save_record_if_better(distance)
	if _over:
		return
	add_flies(den_flies)
	# La tana 5: il livello di Siccità è superato con questa rana.
	if count == Drought.GOAL_DEN and not test_run and Drought.reached(frog_kind, drought):
		_announce_drought()
	# Una sezione nuova: la prova del guscio rapido ricomincia, e
	# l'assicurazione si rinnova (il premio: salvata e arrivata senza colpi).
	frog.shell_blocks_section = 0
	if frog.insured_clean:
		Progress.trial_best("insurance", 1, 1)
		frog.insured_clean = false
	frog.insurance_ready = frog.insurance
	if den_regen > 0.0:
		frog.health = mini(frog.health + roundi(frog.max_health * den_regen), frog.max_health)
		frog.health_changed.emit(frog.health, frog.max_health)
	if den_celebration_seconds <= 0.0:
		offer_upgrade()
		return
	frog.cheer()
	frog.camera_rig.pull_back(2.5, den_celebration_seconds + 0.6)
	# Un timer figlio della partita: se la partita se ne va prima, sparisce
	# con lei.
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = den_celebration_seconds
	timer.timeout.connect(_end_celebration)
	timer.timeout.connect(timer.queue_free)
	add_child(timer)
	timer.start()


## Il teletrasporto (vedi Worlds), anche dalla modalità prova: il calore
## torna a zero, il percorso ricomincia nel mondo nuovo, l'incendio resta
## indietro e l'inseguitore del mondo nuovo riparte, più veloce. La rana ci
## arriva dall'alto. Al giro nuovo la Siccità sale di un livello per questa
## run.
func next_world() -> void:
	if _over:
		return
	frog.tongue_power.release()
	Heat.new_world()
	course.next_world()
	var fire: Wildfire = $Wildfire
	fire.new_world(course.worlds_passed)
	if course.world == 0:
		_add_loop_drought(drought + course.loop)
	_apply_world()
	frog.respawn()
	frog.global_position.y = world_drop_height
	frog.reset_physics_interpolation()
	Sfx.play(&"portal_warp")
	var title := tr(Worlds.name_of(course.world))
	if course.loop > 0:
		title = tr("%s · giro %d") % [title, course.loop + 1]
	hud.announce(title)


## Quello che il mondo cambia fuori dal percorso: il vuoto per la rana, il
## paesaggio.
func _apply_world() -> void:
	var sky := Worlds.is_void(course.world)
	frog.void_world = sky
	$Backdrop.set_world(sky)
	$Wildfire.set_world(sky)


## Caduta nel vuoto del cielo: sull'ultima striscia sicura davanti al fuoco
## (deciso l'8 ottobre 2026).
func _on_fell_into_void() -> void:
	var fire: Wildfire = $Wildfire
	frog.respawn_at(course.safe_point(frog.global_position.z, fire.front_z - void_fire_margin, frog.global_position.x))


## Il giro nuovo aggiunge l'handicap del livello di Siccità successivo, e le
## mosche valgono come a quel livello. Oltre il quinto non si aggiunge niente.
func _add_loop_drought(level: int) -> void:
	if level < 1 or level > Drought.LEVELS.size():
		return
	Drought.apply_level(self, level)
	fly_value *= (1.0 + Drought.FLY_BONUS * level) / (1.0 + Drought.FLY_BONUS * (level - 1))


## Finita la festa, le carte. Senza carte da scegliere la rana riparte
## subito; altrimenti quando se ne sceglie una.
func _end_celebration() -> void:
	if _over:
		return
	offer_upgrade()
	if not hud.is_offer_open():
		frog.asleep = false


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
	_show_offer(upgrades.make_offer())


func _show_offer(options: Array[String]) -> void:
	if options.is_empty():
		_close_offer()
		frog.heal_full()
		add_flies(empty_den_flies)
		hud.announce(tr("Niente da scegliere: vita piena e %d mosche") % empty_den_flies)
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_offer(options, upgrades)


## I gettoni della tana (vedi Upgrades.TOKENS). index: la carta da esiliare.
func _on_token_used(kind: String, index: int) -> void:
	match kind:
		"reroll":
			Sfx.play(&"ui_card_in", 0.0, 0.8)
			_show_offer(upgrades.reroll())
		"banish":
			Sfx.play(&"ui_refund")
			_show_offer(upgrades.banish(index))
		"skip":
			upgrades.tokens.skip -= 1
			_close_offer()
			add_flies(skip_flies)
			hud.announce(tr("Saltata: +%d mosche") % skip_flies)


## Le carte se ne vanno senza sceglierne una: il gioco riparte.
func _close_offer() -> void:
	frog.asleep = false
	hud.hide_offer()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_equipped(id: String) -> void:
	Sfx.play(&"ui_card_pick")
	frog.asleep = false
	hud.hide_offer()
	hud.show_equipment(upgrades)
	hud.announce(tr("Equipaggiato: %s") % tr(Upgrades.CATALOG[id].name))
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_frog_died() -> void:
	var stats := _finish_run()
	Sfx.muffle_world(true)
	if stats.new_record:
		get_tree().create_timer(1.6, true, false, true).timeout.connect(Sfx.play.bind(&"ui_record"))
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
		# Il mercatino cambia a ogni run.
		Market.refresh()
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
		"drought": drought,
	}


## La rana: i suoi attrezzi iniziali e la sua pelle (anche nel menu, che la
## mostra mentre si sceglie).
func preview_frog(id: String, as_silhouette := false) -> void:
	frog_kind = id
	upgrades.equip_kit(starting_kit if not starting_kit.is_empty() else Frogs.ALL[id].kit)
	hud.show_equipment(upgrades)
	frog.set_look(Frogs.ALL[id])
	# Il guardaroba: il cappello e il colore scelti per questa rana.
	var pick := Cosmetics.chosen(id)
	frog.set_hat(pick.hat)
	frog.skin = Cosmetics.palette_of(pick.color) if pick.color != "" else Frogs.ALL[id].color
	frog.silhouette = as_silhouette


## Il pro e il contro della rana, all'inizio della run (prima dello stagno).
func _apply_frog_mods() -> void:
	var mods: Dictionary = Frogs.ALL[frog_kind].mods
	frog.max_health = mods.get("health", frog.max_health)
	frog.jump_height *= mods.get("jump", 1.0)
	frog.glider_power.duration *= mods.get("glide", 1.0)
	frog.swim_speed *= mods.get("swim", 1.0)
	frog.move_speed *= mods.get("speed", 1.0)
	frog.tongue_power.cooldown *= mods.get("tongue_cooldown", 1.0)


## La Siccità scelta per questa rana (vedi Drought).
func _apply_drought() -> void:
	drought = Drought.selected(frog_kind)
	Drought.apply(self, drought)
	upgrades.update_luck(Progress.level("eye"), drought)


## Una carta rara o epica con la maestria già completa: vita e mosche.
func _on_rarity_bonus(rarity: String) -> void:
	var epic := rarity == "epic"
	frog.heal(frog.max_health if epic else roundi(frog.max_health * 0.25))
	add_flies(10 if epic else 5)


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
