extends Node
## Il suono del gioco (autoload Sfx). Gli effetti stanno in
## assets/audio/sfx, generati da tools/suoni/genera.py: nome_N.wav sono le
## varianti di un suono singolo (se ne sceglie una a caso), nome.ogg i loop.
##
## - play(nome): un suono senza posizione (la rana stessa, l'interfaccia).
## - play_at(nome, punto): un suono nel mondo, che si sente da dove viene.
## - loop(nodo, nome): un suono continuo che segue un nodo (motori, treni,
##   incendio). Di ogni loop si sentono solo le sorgenti più vicine: con
##   cento auto in strada suonano i motori delle sei più vicine.
##
## Ogni suono singolo ha un numero massimo di voci: oltre, il nuovo non
## parte. Così il caos resta caos, non poltiglia. L'ascoltatore sta sulla
## rana e guarda dove guarda la telecamera: "dietro" vuol dire dietro alla
## rana, ed è da lì che arriva l'incendio.

const DIR := "res://assets/audio/sfx/"

## Volume di partenza di ogni suono, in dB: il mix sta tutto qui.
const VOLUME := {
	"frog_hop": -16.0, "frog_swim": -10.0, "frog_land": -8.0, "frog_jump": -7.0,
	"frog_croak": -4.0, "frog_cheer": -3.0, "frog_hurt": -2.0, "frog_burn": -4.0,
	"punch_swing": -8.0, "punch_hit": 0.0, "super_jump": -4.0, "slam_dive": -10.0,
	"glider_open": -6.0, "glider_close": -8.0, "glide_wind": -6.0,
	"tongue_shoot": -8.0, "tongue_stick": -4.0, "tongue_reel": -8.0, "power_ready": -14.0,
	"car_engine": -4.0, "car_horn": -6.0, "car_skid": -6.0, "car_crash": -2.0,
	"wreck_hit": -8.0, "car_explode": 0.0,
	"fire_loop": 0.0, "fire_roar": 0.0, "fire_ignite": -6.0, "sizzle": -6.0, "storm_loop": 0.0, "storm_roar": 0.0, "thunder": -4.0,
	"river_loop": -4.0, "harbor_loop": -4.0, "log_creak": -8.0, "log_bubbles": -10.0,
	"croc_snap": -4.0, "croc_open": -10.0, "eagle_screech": -10.0,
	"rail_bell": -6.0, "train_horn": -2.0, "train_loop": 0.0,
	"jet_loop": 0.0, "plane_touchdown": 0.0, "plane_reverse": 0.0, "scrape_loop": -2.0,
	"baggage_hit": -6.0, "tug_loop": -6.0,
	"ship_horn": -2.0, "ship_engine": -4.0, "crane_warning": -8.0, "crane_release": -6.0,
	"container_land": 0.0,
	"den_arrive": -4.0, "flower_pop": -12.0, "fly_collect": -8.0, "fly_golden": -4.0,
	"fly_buzz": -10.0, "heat_up": -6.0, "chain_ding": -8.0, "portal_warp": -2.0,
	"ui_hover": -22.0, "ui_click": -8.0, "ui_back": -8.0, "ui_card_in": -10.0,
	"ui_card_pick": -4.0, "ui_buy": -6.0, "ui_refund": -6.0,
	"ui_pause": -8.0, "ui_resume": -8.0, "ui_record": -4.0,
}
## Voci contemporanee per suono singolo (le altre: DEFAULT_VOICES).
const VOICES := {
	"frog_hop": 1, "frog_swim": 1, "car_crash": 5, "wreck_hit": 4, "car_explode": 4,
	"car_horn": 2, "car_skid": 2, "croc_snap": 2, "croc_open": 2, "eagle_screech": 2, "flower_pop": 3,
	"fly_collect": 3, "ui_hover": 1, "chain_ding": 2, "baggage_hit": 3,
}
const DEFAULT_VOICES := 3
## Sorgenti che si sentono insieme per ogni loop (le altre: 2).
const LOOP_VOICES := {
	"car_engine": 6, "jet_loop": 2, "train_loop": 2, "fly_buzz": 2, "river_loop": 2,
	"harbor_loop": 1, "tug_loop": 2, "ship_engine": 2, "scrape_loop": 1, "fire_loop": 1,
	"fire_roar": 1, "storm_loop": 1, "storm_roar": 1, "rail_bell": 2, "crane_warning": 2, "glide_wind": 1, "sizzle": 1,
}
## Variazione casuale del tono a ogni colpo: dieci pugni di fila non suonano
## mai uguali. L'interfaccia no: deve essere sempre la stessa voce.
const PITCH_JITTER := 0.05
## Distanza a cui un suono si sente al volume pieno (unit_size) e oltre cui
## non si sente più, moltiplicate per il "reach" di chi suona.
const UNIT_SIZE := 7.0
const MAX_DISTANCE := 90.0
## Velocità del suono per l'effetto Doppler, più bassa del vero: esagerato,
## da cartone.
const DOPPLER_SPEED := 200.0
## Ogni quanto si scelgono le sorgenti più vicine dei loop.
const LOOP_REASSIGN_SECONDS := 0.2
## Il mondo dietro i menu: quanto più piano e quanto ovattato.
const MUFFLED_DB := -16.0
const MUFFLED_CUTOFF := 700.0

## Quante volte è partito ogni suono (per i test).
var played := {}
## Senza schermo (i test headless) non suona niente: si contano solo i suoni.
## Il server audio finto dei test non finisce mai di suonare e alla chiusura
## lamenterebbe i suoni ancora vivi.
var silent := DisplayServer.get_name() == "headless"

var _files := {}
var _streams := {}
var _last_variant := {}
var _voices := {}
var _loops := {}
var _listener: AudioListener3D
var _listener_velocity := Vector3.ZERO
var _listener_last := Vector3.ZERO
var _reassign_wait := 0.0
var _one_shots: Array[Node] = []
var _last_tick := 0
## Quanto il mondo è attutito, da 0 a 1 (vedi muffle_world).
var _muffle := 0.0
var _muffle_target := 0.0
## Il volume degli effetti scelto nelle opzioni, in dB (vedi set_volumes).
var _effects_db := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan()
	_setup_buses()
	_listener = AudioListener3D.new()
	add_child(_listener)
	_listener.make_current()
	get_tree().node_added.connect(_on_node_added)
	Style.style_changed.connect(_apply_style.unbind(1))
	_apply_style()


## Alla chiusura i lettori ancora in corsa vanno fermati, o il server audio
## tiene vivi i loro suoni oltre la fine del programma.
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null
	_streams.clear()
	_loops.clear()


## Dietro i menu (quello iniziale, la fine della corsa, lo stagno) il mondo
## si sente lontano e ovattato: si capisce che è vivo, ma non disturba.
## L'interfaccia resta piena.
func muffle_world(on: bool) -> void:
	_muffle_target = 1.0 if on else 0.0


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := (now - _last_tick) / 1000000.0 if _last_tick > 0 else 0.0
	_age_one_shots(real_delta)
	_last_tick = now
	_update_muffle(real_delta)
	_place_listener(delta)
	_reassign_wait -= delta
	var reassign := _reassign_wait <= 0.0
	if reassign:
		_reassign_wait = LOOP_REASSIGN_SECONDS
	for sound in _loops:
		_update_loop(sound, reassign, delta)


# --- Suoni singoli -------------------------------------------------------------

## Un suono senza posizione: la rana stessa, l'interfaccia. I suoni ui_*
## suonano anche a gioco fermo, e così quelli con always (la festa in tana,
## che continua mentre si scelgono le carte, e la morte della rana): passano
## dal bus dell'interfaccia, che non si attutisce dietro i menu.
func play(sound: StringName, volume_db := 0.0, pitch := 1.0, always := false) -> void:
	if _silenced(sound):
		return
	var stream := _pick(sound)
	if stream == null or not _take_voice(sound):
		return
	var ui := String(sound).begins_with("ui_")
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Interfaccia" if ui or always else &"Effetti"
	player.process_mode = Node.PROCESS_MODE_ALWAYS if ui or always else Node.PROCESS_MODE_PAUSABLE
	player.volume_db = VOLUME.get(sound, 0.0) + volume_db
	player.pitch_scale = pitch * _jitter(sound)
	_start(player, sound)


## Un suono nel mondo, nel punto dato. reach allarga la distanza a cui si
## sente (2: il doppio).
func play_at(sound: StringName, at: Vector3, volume_db := 0.0, pitch := 1.0, reach := 1.0) -> void:
	if _silenced(sound):
		return
	var stream := _pick(sound)
	if stream == null or not _take_voice(sound):
		return
	var player := _new_3d(reach)
	player.stream = stream
	player.volume_db = VOLUME.get(sound, 0.0) + volume_db
	player.pitch_scale = pitch * _jitter(sound)
	player.position = at
	_start(player, sound)


func _silenced(sound: StringName) -> bool:
	if not silent:
		return false
	if not _files.has(sound):
		push_warning("Sfx: suono sconosciuto %s" % sound)
	played[sound] = played.get(sound, 0) + 1
	return true


func _start(player: Node, sound: StringName) -> void:
	add_child(player)
	# Secondi che restano: alla fine il lettore se ne va. Non basta il segnale
	# finished, che senza scheda audio (i test) non arriva mai.
	player.set_meta("sound", sound)
	player.set_meta("left", player.stream.get_length() / player.pitch_scale + 0.05)
	player.finished.connect(_finish.bind(player))
	player.play()
	_one_shots.append(player)
	played[sound] = played.get(sound, 0) + 1


func _finish(player: Node) -> void:
	if not is_instance_valid(player) or player.get_meta("done", false):
		return
	player.set_meta("done", true)
	var sound: StringName = player.get_meta("sound")
	_voices[sound] = maxi(_voices.get(sound, 1) - 1, 0)
	_one_shots.erase(player)
	player.stop()
	player.queue_free()


## Il tempo dei suoni singoli passa in tempo reale (il fermo-immagine non
## rallenta l'audio), ma non a gioco fermo per quelli del mondo.
func _age_one_shots(real_delta: float) -> void:
	var paused := get_tree().paused
	for player: Node in _one_shots.duplicate():
		if paused and player.process_mode != Node.PROCESS_MODE_ALWAYS:
			continue
		var left: float = player.get_meta("left") - real_delta
		player.set_meta("left", left)
		if left <= 0.0:
			_finish(player)


func _take_voice(sound: StringName) -> bool:
	var used: int = _voices.get(sound, 0)
	if used >= VOICES.get(sound, DEFAULT_VOICES):
		return false
	_voices[sound] = used + 1
	return true


func _jitter(sound: StringName) -> float:
	if String(sound).begins_with("ui_"):
		return 1.0
	return 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)


func _new_3d(reach: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = &"Effetti"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.unit_size = UNIT_SIZE * reach
	player.max_distance = MAX_DISTANCE * reach
	player.attenuation_filter_cutoff_hz = 9000.0
	player.attenuation_filter_db = -12.0
	return player


# --- Loop ---------------------------------------------------------------------

## Un suono continuo che segue node finché non lo si toglie (unloop) o il
## nodo sparisce. doppler: il tono sale quando si avvicina e scende quando se
## ne va (treni, aerei).
func loop(node: Node3D, sound: StringName, volume_db := 0.0, pitch := 1.0, reach := 1.0, doppler := false) -> void:
	if not _files.has(sound):
		push_warning("Sfx: loop sconosciuto %s" % sound)
		return
	if not _loops.has(sound):
		_loops[sound] = {"emitters": {}, "players": []}
	var id := node.get_instance_id()
	_loops[sound].emitters[id] = {
		"node": node, "volume_db": volume_db, "pitch": pitch, "reach": reach,
		"doppler": doppler, "last": node.global_position if node.is_inside_tree() else Vector3.ZERO,
		"velocity": Vector3.ZERO,
	}


## Cambia volume e tono di un loop già acceso (per esempio il motore che va
## più forte, il fuoco che si avvicina).
func set_loop(node: Node3D, sound: StringName, volume_db: float, pitch := 1.0) -> void:
	if not _loops.has(sound):
		return
	var emitter: Dictionary = _loops[sound].emitters.get(node.get_instance_id(), {})
	if emitter.is_empty():
		return
	emitter.volume_db = volume_db
	emitter.pitch = pitch


func unloop(node: Node3D, sound: StringName) -> void:
	if _loops.has(sound):
		_loops[sound].emitters.erase(node.get_instance_id())


## Quante sorgenti ha un loop in questo momento (per i test).
func loop_count(sound: StringName) -> int:
	return _loops[sound].emitters.size() if _loops.has(sound) else 0


func is_looping(node: Node3D, sound: StringName) -> bool:
	return _loops.has(sound) and _loops[sound].emitters.has(node.get_instance_id())


func _update_loop(sound: StringName, reassign: bool, delta: float) -> void:
	var data: Dictionary = _loops[sound]
	var all: Dictionary = data.emitters
	# Chi è stato registrato prima di entrare nella scena (o ne è uscito per
	# un po') aspetta: suona solo chi c'è.
	var emitters := {}
	for id in all.keys():
		var emitter: Dictionary = all[id]
		if not is_instance_valid(emitter.node):
			all.erase(id)
			continue
		if not emitter.node.is_inside_tree():
			continue
		emitters[id] = emitter
		var at: Vector3 = emitter.node.global_position
		if delta > 0.0:
			emitter.velocity = (at - emitter.last) / delta
		emitter.last = at
	var players: Array = data.players
	if silent:
		return
	if reassign:
		_assign(sound, emitters, players)
	for player: AudioStreamPlayer3D in players:
		var id: int = player.get_meta("emitter", 0)
		if not emitters.has(id):
			if player.playing:
				player.stop()
			player.set_meta("emitter", 0)
			continue
		var emitter: Dictionary = emitters[id]
		player.global_position = emitter.node.global_position
		player.volume_db = VOLUME.get(sound, 0.0) + emitter.volume_db
		var pitch: float = emitter.pitch
		if emitter.doppler:
			pitch *= _doppler(player.global_position, emitter.velocity)
		player.pitch_scale = clampf(pitch, 0.1, 4.0)
		player.unit_size = UNIT_SIZE * emitter.reach
		player.max_distance = MAX_DISTANCE * emitter.reach
		# A gioco fermo il mondo tace (le carte della tana, la pausa).
		player.stream_paused = get_tree().paused


## Le sorgenti più vicine prendono i lettori; chi aveva già un lettore e resta
## fra le più vicine se lo tiene (niente scatti).
func _assign(sound: StringName, emitters: Dictionary, players: Array) -> void:
	var ear := _listener.global_position
	var ranked := emitters.keys()
	ranked.sort_custom(func(a: int, b: int) -> bool:
		return ear.distance_squared_to(emitters[a].node.global_position) < ear.distance_squared_to(emitters[b].node.global_position))
	var wanted := ranked.slice(0, LOOP_VOICES.get(sound, 2))
	wanted = wanted.filter(func(id: int) -> bool:
		return ear.distance_to(emitters[id].node.global_position) < MAX_DISTANCE * emitters[id].reach)
	var free: Array = []
	for player: AudioStreamPlayer3D in players:
		var id: int = player.get_meta("emitter", 0)
		if wanted.has(id):
			wanted.erase(id)
		else:
			free.append(player)
	for id in wanted:
		var player: AudioStreamPlayer3D
		if free.is_empty():
			player = _new_3d(1.0)
			player.bus = &"Ambiente"
			player.stream = _pick(sound)
			add_child(player)
			players.append(player)
		else:
			player = free.pop_back()
		player.set_meta("emitter", id)
		player.global_position = emitters[id].node.global_position
		# Ogni sorgente parte da un punto diverso del loop: due motori uguali
		# non suonano all'unisono.
		player.play(randf() * player.stream.get_length())
	for player: AudioStreamPlayer3D in free:
		player.set_meta("emitter", 0)
		player.stop()


func _doppler(at: Vector3, velocity: Vector3) -> float:
	var to_source := at - _listener.global_position
	if to_source.length_squared() < 0.01:
		return 1.0
	var radial := (velocity - _listener_velocity).dot(to_source.normalized())
	return DOPPLER_SPEED / maxf(DOPPLER_SPEED + radial, 20.0)


# --- Ascoltatore, file, bus ---------------------------------------------------

func _place_listener(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var frog := get_tree().get_first_node_in_group("frog") as Node3D
	var basis := camera.global_basis if camera else Basis()
	var at := frog.global_position + Vector3.UP if frog else (camera.global_position if camera else Vector3.ZERO)
	_listener.global_transform = Transform3D(basis, at)
	if delta > 0.0:
		_listener_velocity = (at - _listener_last) / delta
	_listener_last = at


## I file degli effetti, raggruppati per nome (nome_3.wav -> nome).
func _scan() -> void:
	var pattern := RegEx.create_from_string("^(.+?)(_\\d+)?\\.(wav|ogg)$")
	for file in ResourceLoader.list_directory(DIR):
		var found := pattern.search(file)
		if found == null:
			continue
		var sound := found.get_string(1)
		if not _files.has(sound):
			_files[sound] = []
		_files[sound].append(DIR + file)
	for sound in _files:
		_files[sound].sort()


## Una variante a caso, mai la stessa due volte di fila.
func _pick(sound: StringName) -> AudioStream:
	if not _files.has(sound):
		push_warning("Sfx: suono sconosciuto %s" % sound)
		return null
	if not _streams.has(sound):
		var streams: Array[AudioStream] = []
		for path in _files[sound]:
			var stream: AudioStream = load(path)
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			streams.append(stream)
		_streams[sound] = streams
	var streams: Array = _streams[sound]
	var index := randi() % streams.size()
	if streams.size() > 1 and index == _last_variant.get(sound, -1):
		index = (index + 1) % streams.size()
	_last_variant[sound] = index
	return streams[index]


## I bus: Effetti (il mondo), Ambiente (i loop), Interfaccia, Musica. Effetti
## e Ambiente hanno un filtro e un riverbero che lo stile accende (PS1) o
## spegne; Arcade comprime un po' tutto.
func _setup_buses() -> void:
	for bus_name in ["Effetti", "Ambiente", "Interfaccia", "Musica"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
		if bus_name in ["Effetti", "Ambiente"]:
			var low := AudioEffectLowPassFilter.new()
			low.cutoff_hz = 7500.0
			AudioServer.add_bus_effect(index, low)
			var room := AudioEffectReverb.new()
			room.room_size = 0.3
			room.damping = 0.6
			room.wet = 0.12
			room.dry = 1.0
			AudioServer.add_bus_effect(index, room)
			var squeeze := AudioEffectCompressor.new()
			squeeze.threshold = -16.0
			squeeze.ratio = 3.0
			AudioServer.add_bus_effect(index, squeeze)
			# Il quarto: il mondo ovattato dietro i menu (muffle_world).
			var muffler := AudioEffectLowPassFilter.new()
			muffler.cutoff_hz = 20000.0
			AudioServer.add_bus_effect(index, muffler)


## I volumi delle opzioni, da 0 a 1: generale (Master), effetti (il mondo,
## i loop e l'interfaccia) e musica. A zero il bus tace del tutto. Il
## cursore va al quadrato: a metà corsa il suono è a metà per l'orecchio
## (-12 dB), non quasi pieno.
func set_volumes(master: float, effects: float, music: float) -> void:
	_set_bus_volume(&"Master", master)
	_set_bus_volume(&"Interfaccia", effects)
	_set_bus_volume(&"Musica", music)
	_effects_db = _to_db(effects)
	for bus_name in ["Effetti", "Ambiente"]:
		var index := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_mute(index, effects <= 0.0)
		AudioServer.set_bus_volume_db(index, _effects_db + lerpf(0.0, MUFFLED_DB, _muffle))


func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, _to_db(volume))


func _to_db(volume: float) -> float:
	return linear_to_db(maxf(volume * volume, 0.0001))


func _update_muffle(real_delta: float) -> void:
	if _muffle == _muffle_target:
		return
	# Si attutisce in 0,8 s, si riapre in 0,4.
	_muffle = move_toward(_muffle, _muffle_target, real_delta / (0.8 if _muffle_target > _muffle else 0.4))
	for bus_name in ["Effetti", "Ambiente"]:
		var index := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(index, _effects_db + lerpf(0.0, MUFFLED_DB, _muffle))
		var muffler := AudioServer.get_bus_effect(index, 3) as AudioEffectLowPassFilter
		muffler.cutoff_hz = lerpf(20000.0, MUFFLED_CUTOFF, pow(_muffle, 0.3))


func _apply_style() -> void:
	var style := Style.style_name()
	for bus_name in ["Effetti", "Ambiente"]:
		var index := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_effect_enabled(index, 0, style == "PS1")
		AudioServer.set_bus_effect_enabled(index, 1, style == "PS1")
		AudioServer.set_bus_effect_enabled(index, 2, style == "Arcade")


## Ogni pulsante fa "clic" quando lo si preme e un "tic" quando il mouse ci
## passa sopra. Chi vuole un suono suo (le carte, lo stagno) lo mette nel
## meta "sfx" del pulsante; "" lo zittisce.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(func() -> void:
			var sound: String = node.get_meta("sfx", "ui_click")
			if sound != "":
				play(sound))
		node.mouse_entered.connect(func() -> void:
			if not (node as BaseButton).disabled:
				play(&"ui_hover"))
