class_name Course
extends Node3D
## Il percorso infinito. Crea blocchi davanti alla rana (verso -Z) e cancella
## quelli rimasti dietro. Una sezione è una serie di ostacoli (strade e fiumi,
## separati da strisce sicure) che finisce con una tana; ogni sezione è più
## difficile della precedente.

signal den_reached(count: int, distance: float)
## La rana è entrata nel teletrasporto (vedi Worlds): la partita cambia mondo.
signal portal_entered

enum Kind { START, SAFE, ROAD, RIVER, RAIL, DEN, AIRPORT, PORT }

const TREE := preload("res://assets/models/tree.glb")
const HOUSE := preload("res://assets/models/house.glb")
const LAMP := preload("res://assets/models/lamp.glb")
const DEN := preload("res://assets/models/den.glb")


@export var frog: Frog
## Larghezza del terreno e mezza larghezza della zona di gioco (muri invisibili).
@export var ground_width := 120.0
@export var play_half_width := 37.0
## Quanti metri di percorso tenere pronti davanti e dietro la rana.
@export var look_ahead := 160.0
## Dietro deve restare terreno almeno fin dove arriva l'incendio.
@export var keep_behind := 75.0

@export_group("Blocchi")
@export var start_depth := 30.0
@export var safe_depth := 6.0
@export var den_depth := 12.0
## Il traguardo della tana comincia qualche metro dentro lo stagno, poco prima
## dell'arco delle tife: la rana ci entra prima di fermarsi.
@export var den_trigger_inset := 4.0
@export var road_lane_width := 4.0
@export var river_lane_width := 3.5
@export var rail_track_spacing := 4.5
## Massicciata e binari arrivano fino all'orizzonte: il treno si vede arrivare.
@export var rail_ground_width := 400.0

@export_group("Sezioni")
## Ostacoli fra una tana e l'altra: si parte da qui (più 0 o 1 a caso)...
@export var section_obstacles := 4
## ...e se ne aggiunge uno a sezione, fino a questo massimo di aggiunte.
## Con 4 e 4: circa 75 m alla prima tana, 100 alla seconda, 270 dalla quinta.
## Ogni mondo passato alza il tetto (Worlds.GROWTH_STEP).
@export var section_growth_cap := 4

@export_group("Mondi")
## Il teletrasporto sta su una striscia sicura spostato di lato, fino a qui
## dal centro: andarci costa strada.
@export var portal_max_offset := 26.0
## Quando si apre, il primo teletrasporto va sulla prima striscia sicura
## almeno così avanti.
@export var portal_min_ahead := 40.0

var dens_reached := 0
var best_distance := 0.0
## Il mondo in cui si è (indice in Worlds.ALL), i mondi passati in tutta la
## run e il giro (0 il primo; dal secondo si ricomincia dal primo mondo).
var world := 0
var worlds_passed := 0
var loop := 0

## Sezione per cui si stanno creando i blocchi: decide la difficoltà.
var _planning_section := 0
var _plan: Array[Kind] = []
## Bordo verso cui si costruisce: il prossimo blocco parte da qui e va verso -Z.
var _front_z := 0.0
var _start_z := 0.0
var _chunks_created := 0
## La sezione che ha già il suo teletrasporto: uno per sezione, al più.
var _portal_section := -1
var _portal_open := false


func _ready() -> void:
	frog.play_half_width = play_half_width
	_start_z = frog.global_position.z
	_front_z = _start_z + 10.0
	_add_chunk(Kind.START)


func _physics_process(_delta: float) -> void:
	while _front_z > frog.global_position.z - look_ahead:
		if _plan.is_empty():
			_plan_section()
		_add_chunk(_plan.pop_front())

	for chunk in get_children():
		var far_edge: float = chunk.get_meta("near_z") - chunk.get_meta("depth")
		if far_edge > frog.global_position.z + keep_behind:
			chunk.queue_free()

	best_distance = maxf(best_distance, _start_z - frog.global_position.z)

	# Al livello 5 di calore si apre l'uscita: il primo teletrasporto compare
	# sulla prima striscia sicura abbastanza avanti; poi uno per sezione.
	var open := Heat.level() >= Heat.LEVELS
	if open and not _portal_open:
		_open_portal()
	_portal_open = open


## Il calore è appena arrivato al livello 5: un teletrasporto sulla striscia
## sicura già pronta più vicina, se non ce n'è già uno davanti.
func _open_portal() -> void:
	var best: Node3D = null
	for chunk in get_children():
		if not chunk.has_meta("kind") or chunk.get_meta("kind") != Kind.SAFE:
			continue
		if chunk.get_meta("near_z") > frog.global_position.z - portal_min_ahead:
			continue
		if chunk.has_meta("portal"):
			return
		if best == null or chunk.get_meta("near_z") > best.get_meta("near_z"):
			best = chunk
	if best:
		_add_portal(best)


func _add_portal(chunk: Node3D) -> void:
	var portal := Portal.new()
	portal.name = "Portal"
	portal.position.x = randf_range(-portal_max_offset, portal_max_offset)
	portal.entered.connect(func(_body: Node3D) -> void: portal_entered.emit())
	chunk.add_child(portal)
	chunk.set_meta("portal", portal)
	_portal_section = chunk.get_meta("section")


## Il tetto delle aggiunte per sezione: cresce a ogni mondo passato.
func growth_cap() -> int:
	return section_growth_cap + Worlds.GROWTH_STEP * worlds_passed


## Il passaggio al mondo successivo: il percorso davanti e dietro sparisce e
## ricomincia, nel mondo nuovo, da una partenza sotto la rana. La distanza e
## le sezioni continuano: la quantità non riparte.
func next_world() -> void:
	worlds_passed += 1
	world = (world + 1) % Worlds.ALL.size()
	if world == 0:
		loop += 1
	Style.set_world(Worlds.id_of(world))
	for chunk in get_children():
		remove_child(chunk)
		chunk.queue_free()
	_plan.clear()
	_portal_open = Heat.level() >= Heat.LEVELS
	_front_z = frog.global_position.z + 10.0
	_add_chunk(Kind.START)
	frog.set_respawn_point(Vector3(frog.global_position.x, 0.5, frog.global_position.z))


## Modalità prova: crea subito, in fondo al percorso pronto, una striscia
## sicura, un blocco del tipo dato e un'altra striscia, e ci porta la rana.
## Il percorso poi continua come previsto.
func jump_to(kind: Kind) -> void:
	_add_chunk(Kind.SAFE)
	var landing := Vector3(0.0, 0.5, _front_z + safe_depth / 2.0)
	_add_chunk(kind)
	_add_chunk(Kind.SAFE)
	frog.global_position = landing
	frog.velocity = Vector3.ZERO
	frog.reset_physics_interpolation()
	frog.set_respawn_point(landing)


## Il tipo del blocco che contiene la quota z (START se non ce n'è).
func kind_at(z: float) -> Kind:
	for chunk in get_children():
		if chunk.has_meta("near_z"):
			var near_z: float = chunk.get_meta("near_z")
			if z <= near_z and z > near_z - chunk.get_meta("depth"):
				return chunk.get_meta("kind")
	return Kind.START


## Metri fra la rana e l'inizio della prossima tana davanti (INF se non c'è
## ancora).
func next_den_distance() -> float:
	var best := INF
	for chunk in get_children():
		if chunk.has_meta("near_z") and chunk.get_meta("kind") == Kind.DEN:
			var gap: float = frog.global_position.z - chunk.get_meta("near_z")
			if gap >= 0.0:
				best = minf(best, gap)
	return best


## Dove ricompare chi cade nel vuoto: l'ultima striscia sicura passata
## (partenza, striscia o tana) che sta ancora davanti al fuoco, cioè a quote
## più basse di limit_z; se il fuoco se le è già prese tutte, la prima davanti
## a lui. Alla x della rana, dentro la zona di gioco.
func safe_point(frog_z: float, limit_z: float, x := 0.0) -> Vector3:
	var behind := INF
	var ahead := -INF
	for chunk in get_children():
		if not chunk.has_meta("kind") or chunk.get_meta("kind") not in [Kind.START, Kind.SAFE, Kind.DEN]:
			continue
		var z: float = chunk.get_meta("near_z") - chunk.get_meta("depth") / 2.0
		if z >= limit_z:
			continue
		if z >= frog_z:
			behind = minf(behind, z)
		else:
			ahead = maxf(ahead, z)
	var z := behind if behind < INF else ahead
	if z == -INF:
		z = frog_z
	return Vector3(clampf(x, -play_half_width + 1.0, play_half_width - 1.0), 0.5, z)


## Distanza percorsa dall'inizio, in metri.
func distance() -> float:
	return best_distance


func _plan_section() -> void:
	var obstacles := section_obstacles + mini(_planning_section, growth_cap()) + randi_range(0, 1)
	for i in obstacles:
		_plan.append(_random_obstacle())
		_plan.append(Kind.SAFE)
	# L'ultima striscia sicura lascia il posto alla tana.
	_plan[_plan.size() - 1] = Kind.DEN
	_planning_section += 1


## Strada o fiume; dalla seconda sezione anche ferrovia, dalla terza anche
## aeroporto e porto. Una lotteria pesata.
func _random_obstacle() -> Kind:
	var weights := {Kind.ROAD: 45.0, Kind.RIVER: 35.0}
	if _planning_section >= 1:
		weights[Kind.RAIL] = 18.0
	if _planning_section >= 2:
		weights[Kind.AIRPORT] = 12.0
		weights[Kind.PORT] = 12.0
	var total := 0.0
	for kind in weights:
		total += weights[kind]
	var roll := randf() * total
	for kind in weights:
		roll -= weights[kind]
		if roll < 0.0:
			return kind
	return Kind.ROAD


func _add_chunk(kind: Kind) -> void:
	var difficulty := _planning_section - 1 if kind != Kind.START else 0
	var chunk := Node3D.new()
	var depth := 0.0
	match kind:
		Kind.START:
			depth = start_depth
			_add_ground(chunk, depth, "grass")
		Kind.SAFE:
			depth = safe_depth
			_add_ground(chunk, depth, "grass")
			chunk.set_meta("section", _planning_section)
			if _portal_open and _portal_section != _planning_section:
				_add_portal(chunk)
		Kind.ROAD:
			var lanes := clampi(3 + difficulty + randi_range(-1, 1), 2, 7)
			depth = lanes * road_lane_width + 1.0
			_add_ground(chunk, depth, "sidewalk")
			var road := Road.new()
			road.lane_count = lanes
			road.lane_width = road_lane_width
			# Le corsie continuano dentro le gallerie del bordo: le auto nascono lì.
			road.length = (play_half_width + Edges.TUNNEL_DEPTH * 0.65) * 2.0
			road.min_speed = minf(6.0 + difficulty * 0.7, 14.0)
			road.max_speed = minf(12.0 + difficulty * 0.9, 20.0)
			chunk.add_child(road)
			chunk.set_meta("lanes", lanes)
		Kind.RIVER:
			var currents := clampi(3 + floori(difficulty / 2.0) + randi_range(-1, 1), 2, 6)
			depth = currents * river_lane_width
			var river := River.new()
			river.lane_count = currents
			river.lane_width = river_lane_width
			river.length = ground_width
			river.min_speed = minf(2.0 + difficulty * 0.3, 5.0) * Heat.river_speed_factor()
			river.max_speed = minf(5.0 + difficulty * 0.4, 8.0) * Heat.river_speed_factor()
			river.crocodile_chance = minf(0.2 + difficulty * 0.05, 0.5)
			river.sky = Worlds.is_void(world)
			chunk.add_child(river)
		Kind.RAIL:
			var tracks := clampi(1 + floori(difficulty / 2.0) + randi_range(0, 1), 1, 3)
			depth = tracks * rail_track_spacing + 2.0
			_add_ground(chunk, depth, "gravel", rail_ground_width)
			for i in tracks:
				var track := RailTrack.new()
				track.position.z = (i - (tracks - 1) / 2.0) * rail_track_spacing
				track.direction = 1.0 if randf() < 0.5 else -1.0
				track.length = rail_ground_width
				track.play_half_width = play_half_width
				chunk.add_child(track)
		Kind.AIRPORT:
			# Un raccordo con gli aerei: le ali coprono quasi 26 m.
			depth = 30.0
			_add_ground(chunk, depth, "tarmac", rail_ground_width)
			var taxiway := Taxiway.new()
			taxiway.direction = 1.0 if randf() < 0.5 else -1.0
			taxiway.length = rail_ground_width
			taxiway.play_half_width = play_half_width
			taxiway.difficulty = difficulty
			chunk.add_child(taxiway)
		Kind.PORT:
			# Una corsia d'acqua con le navi, due nelle sezioni avanzate.
			var lanes := 1 if difficulty < 3 else 2
			depth = Port.depth_for(lanes)
			var port := Port.new()
			port.lanes = lanes
			port.difficulty = difficulty
			port.length = rail_ground_width
			port.play_half_width = play_half_width
			port.sky = Worlds.is_void(world)
			chunk.add_child(port)
		Kind.DEN:
			depth = den_depth
			_add_ground(chunk, depth, "den_grass")
			_add_den(chunk, depth)

	_add_side_walls(chunk, depth)
	var edges := Edges.new()
	edges.name = "Edges"
	edges.kind = kind
	edges.depth = depth
	edges.edge_x = play_half_width + 0.5
	if kind == Kind.ROAD:
		edges.lanes = chunk.get_meta("lanes")
		edges.lane_width = road_lane_width
	chunk.add_child(edges)
	_add_props(chunk, kind, depth)
	chunk.position.z = _front_z - depth / 2.0
	chunk.set_meta("near_z", _front_z)
	chunk.set_meta("kind", kind)
	chunk.set_meta("depth", depth)
	chunk.name = "%s_%d" % [Kind.keys()[kind], _chunks_created]
	_chunks_created += 1
	add_child(chunk)
	_front_z -= depth


func _add_ground(chunk: Node3D, depth: float, palette_key: String, width := -1.0) -> void:
	var size := Vector3(ground_width if width < 0.0 else width, 4.0, depth)
	var ground := StaticBody3D.new()
	ground.collision_mask = 0
	ground.position.y = -2.0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ground.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_mesh(size, palette_key)
	ground.add_child(mesh)
	chunk.add_child(ground)


## Muri invisibili ai lati: fermano la rana e i rottami, non i veicoli che
## guidano (sono cinematici e li attraversano).
func _add_side_walls(chunk: Node3D, depth: float) -> void:
	var walls := StaticBody3D.new()
	walls.collision_mask = 0
	for side in [-1.0, 1.0]:
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 40.0, depth)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(side * (play_half_width + 0.5), 16.0, 0.0)
		walls.add_child(collision)
	chunk.add_child(walls)


## Lo scenario ai lati, fuori dai muri invisibili: alberi sull'erba, case alla
## partenza e ogni tanto lungo il percorso, lampioni lungo le strade.
func _add_props(chunk: Node3D, kind: Kind, depth: float) -> void:
	var outside := play_half_width + 4.0
	var edge := ground_width / 2.0 - 3.0
	if Worlds.is_void(world):
		_add_sky_props(chunk, kind, depth, outside, edge)
		return
	match kind:
		Kind.START, Kind.SAFE, Kind.DEN:
			for side in [-1.0, 1.0]:
				for i in maxi(1, floori(depth / 6.0)):
					var tree := _prop(chunk, TREE, Vector3(side * randf_range(outside, edge), 0.0, randf_range(-depth, depth) * 0.4))
					tree.rotation.y = randf() * TAU
					tree.scale = Vector3.ONE * randf_range(0.8, 1.3)
				if kind == Kind.START or randf() < 0.25:
					# Le case guardano verso il percorso.
					var house := _prop(chunk, HOUSE, Vector3(side * 50.0, 0.0, randf_range(-depth, depth) * 0.25))
					house.rotation.y = -PI / 2.0 * side
		Kind.ROAD:
			for side in [-1.0, 1.0]:
				var z := -depth / 2.0 + 2.0
				while z < depth / 2.0:
					# Il braccio del lampione punta verso la strada.
					var lamp := _prop(chunk, LAMP, Vector3(side * (play_half_width + 1.2), 0.0, z))
					lamp.rotation.y = 0.0 if side < 0.0 else PI
					z += 12.0


## Nel cielo, ai lati, ammassi di nuvole al posto di alberi e case; i
## lampioni lungo le strade restano (è il cielo degli uomini).
func _add_sky_props(chunk: Node3D, kind: Kind, depth: float, outside: float, edge: float) -> void:
	match kind:
		Kind.START, Kind.SAFE, Kind.DEN:
			for side in [-1.0, 1.0]:
				for i in maxi(1, floori(depth / 8.0)):
					var heap := Cloud.heap(randf_range(1.5, 3.0), _chunks_created * 7 + i * 2 + int(side))
					heap.position = Vector3(side * randf_range(outside, edge), 0.5, randf_range(-depth, depth) * 0.4)
					chunk.add_child(heap)
		Kind.ROAD:
			for side in [-1.0, 1.0]:
				var z := -depth / 2.0 + 2.0
				while z < depth / 2.0:
					var lamp := _prop(chunk, LAMP, Vector3(side * (play_half_width + 1.2), 0.0, z))
					lamp.rotation.y = 0.0 if side < 0.0 else PI
					z += 12.0


func _prop(chunk: Node3D, scene: PackedScene, at: Vector3) -> Node3D:
	var prop: Node3D = scene.instantiate()
	prop.position = at
	chunk.add_child(prop)
	Style.apply_palette(prop)
	return prop


## La tana: uno stagno sul prato, coi laghetti ai lati e l'arco delle tife
## sopra il passaggio (modello di Blender, solo da vedere). Entrarci registra
## il checkpoint.
func _add_den(chunk: Node3D, depth: float) -> void:
	var den := _prop(chunk, DEN, Vector3.ZERO)
	chunk.set_meta("den", den)
	# I fiori sono boccioli chiusi finché la rana non arriva.
	for flower: Node3D in den.find_children("Flower_*", "", false, false):
		flower.scale = Vector3(0.35, 0.5, 0.35)
	# Le increspature attorno alle ninfee si allargano piano, sfasate.
	# (Sfasate a indice, non a caso: la sequenza casuale è del percorso.)
	var ripples := den.find_children("Ripple_*", "", false, false)
	for i in ripples.size():
		var ripple: Node3D = ripples[i]
		var tween := ripple.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tween.tween_interval((i % 5) * 0.35)
		tween.tween_property(ripple, "scale", Vector3(1.25, 1.0, 1.25), 1.6)
		tween.tween_property(ripple, "scale", Vector3.ONE, 1.6)

	var trigger := Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2 # rana
	var shape := BoxShape3D.new()
	shape.size = Vector3(play_half_width * 2.0, 20.0, depth - den_trigger_inset)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 10.0, -den_trigger_inset / 2.0)
	trigger.add_child(collision)
	trigger.body_entered.connect(_on_den_entered.bind(chunk), CONNECT_ONE_SHOT)
	chunk.add_child(trigger)


func _on_den_entered(body: Node3D, chunk: Node3D) -> void:
	if body is Frog:
		dens_reached += 1
		frog.set_respawn_point(Vector3(0.0, 0.1, chunk.global_position.z))
		den_reached.emit(dens_reached, distance())
		_celebrate(chunk)


## L'arrivo in tana: i fiori si aprono uno dopo l'altro e dai laghetti si alza
## uno sciame di lucciole. Va avanti anche a gioco fermo, mentre si sceglie
## la carta.
func _celebrate(chunk: Node3D) -> void:
	var den: Node3D = chunk.get_meta("den", null)
	if den == null:
		return
	Sfx.play(&"den_arrive", 0.0, 1.0, true)
	var flowers := den.find_children("Flower_*", "", false, false)
	for i in flowers.size():
		var flower: Node3D = flowers[i]
		flower.process_mode = Node.PROCESS_MODE_ALWAYS
		var tween := flower.create_tween().set_ignore_time_scale(true)
		tween.tween_interval(0.08 * i)
		tween.tween_callback(Sfx.play.bind(&"flower_pop", 0.0, 1.0 + 0.05 * i, true))
		tween.tween_property(flower, "scale", Vector3(1.5, 1.5, 1.5), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(flower, "scale", Vector3.ONE, 0.25)
	for side in [-1.0, 1.0]:
		var fireflies := CPUParticles3D.new()
		fireflies.process_mode = Node.PROCESS_MODE_ALWAYS
		var dot := SphereMesh.new()
		dot.radius = 0.07
		dot.height = 0.14
		dot.radial_segments = 4
		dot.rings = 2
		dot.material = Style.material("lamp_light")
		fireflies.mesh = dot
		fireflies.amount = 36
		fireflies.lifetime = 2.6
		fireflies.explosiveness = 0.6
		fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		fireflies.emission_box_extents = Vector3(7.0, 0.2, 3.0)
		fireflies.direction = Vector3.UP
		fireflies.spread = 35.0
		fireflies.gravity = Vector3(0.0, 0.4, 0.0)
		fireflies.initial_velocity_min = 0.8
		fireflies.initial_velocity_max = 2.2
		fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fireflies.position = Vector3(side * 21.0, 0.3, 0.0)
		den.add_child(fireflies)
		fireflies.emitting = true
		# Dopo qualche secondo lo sciame si dirada (il timer va anche in pausa).
		get_tree().create_timer(4.0, true, false, true).timeout.connect(fireflies.set_emitting.bind(false))


static func _box_mesh(size: Vector3, palette_key: String) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Style.material(palette_key)
	return mesh
