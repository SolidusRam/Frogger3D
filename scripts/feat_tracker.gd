class_name FeatTracker
extends Node
## Guarda la run e riconosce le imprese (vedi Feats) nel momento in cui
## succedono: le salva subito e le annuncia nell'HUD, senza fermare il gioco.
## Una run di prova (modalità F1) non ne fa nessuna.

## Le soglie delle imprese (i testi stanno in Feats.ALL).
const RAFT_SECONDS := 3.0
const ROAD_LANES := 4
const MIN_CROSSING_SPEED := 1.0
const FLAME_SURVIVE_SECONDS := 1.5
const QUEUE_CARS := 5
const QUEUE_RADIUS := 60.0
const DEN_NEAR := 10.0
const DENS_FOR_FROG := 5
const GLIDE_METERS := 50.0
const SWIM_METERS := 100.0
const TOW_METERS := 40.0
const PACIFIST_DENS := 3
const EXPLOSION_WRECKS := 3
const SLAM_FLIPS := 5
const FIRE_CLOSE := 5.0
const MARATHON_SECONDS := 15.0 * 60.0
const FAR_METERS := 2000.0
const HOT_SECONDS := 120.0
const TRAIN_BELOW := 30.0
## Un colpo (fuoco, container) conta come causa della morte se è appena
## successo.
const CAUSE_SECONDS := 0.4

var game: Node
var frog: Frog
var course: Course
var hud: Hud
var fire: Wildfire

var _raft_time := 0.0
var _road_entry := INF
var _road_stopped := false
var _flame_at := -1.0
var _glide := 0.0
var _swim := 0.0
var _tow := 0.0
var _punches := 0
var _hot_time := 0.0
var _fire_gap := INF
var _queue_wait := 0.0
## Ultimo colpo con una causa che conta per le imprese ("fire", "container").
var _cause := ""
var _cause_at := -10.0
var _now := 0.0


func setup(the_game: Node) -> void:
	game = the_game
	frog = game.frog
	course = game.course
	hud = game.hud
	fire = game.get_node("Wildfire")
	Feats.tracker = self
	frog.punched.connect(func(_cars: Array[Car]) -> void:
		if not frog.is_on_floor() and not frog.is_swimming():
			award("acrobata"))
	frog.power_used.connect(func(power: StringName) -> void:
		if power == &"punch":
			_punches += 1)
	frog.died.connect(_on_died)
	# Prima che la tana respinga il fuoco: la distanza dell'ultimo passo.
	course.den_reached.connect(_on_den_reached)


func _exit_tree() -> void:
	if Feats.tracker == self:
		Feats.tracker = null


## Un'impresa fatta: si salva e si annuncia (una volta sola per sempre).
func award(id: String) -> void:
	if Feats.done(id) or game.test_run or game.attract:
		return
	Progress.feat_done(id)
	var feat: Dictionary = Feats.ALL[id]
	hud.show_feat(tr(feat.name), tr(feat.reward_name), Feats.reward_ready(id))


## Gli eventi passati da Feats.note().
func on_event(event: StringName, value: float) -> void:
	match event:
		&"car_hit":
			# value 1: l'auto l'aveva colpita la rana.
			if value > 0.0:
				award("boomerang")
		&"frog_hit":
			if frog.is_gliding():
				award("abbattuta")
		&"explosion":
			if value >= EXPLOSION_WRECKS:
				award("fuochi")
		&"slam":
			if value >= SLAM_FLIPS:
				award("scossa")
		&"container_on_car":
			award("consegna")
		&"container_hit":
			award("cantiere")
			_cause = "container"
			_cause_at = _now
		&"croc_bite":
			if frog.tongue_power.attached:
				award("esca")
		&"engine_flame":
			_flame_at = _now
		&"fire_burn":
			_cause = "fire"
			_cause_at = _now


func _physics_process(delta: float) -> void:
	_now += delta
	if frog.is_dead or game.attract:
		return
	_watch_raft(delta)
	_watch_road()
	_watch_flight(delta)
	_watch_queue(delta)
	if frog.super_jump_power.active and frog.is_on_floor() and frog.floor_body() is Car:
		award("tetto")
	if _flame_at >= 0.0 and _now - _flame_at > FLAME_SURVIVE_SECONDS:
		_flame_at = -1.0
		award("fiamma")
	if frog.is_swimming():
		_swim += Vector2(frog.velocity.x, frog.velocity.z).length() * delta
		if _swim >= SWIM_METERS:
			award("bracciate")
	if frog.tongue_power.is_towing():
		_tow += frog.velocity.length() * delta
		if _tow >= TOW_METERS:
			award("rimorchio")
	else:
		_tow = 0.0
	_hot_time = _hot_time + delta if Heat.level() >= Heat.LEVELS else 0.0
	if _hot_time >= HOT_SECONDS:
		award("incandescente")
	if game.run_time >= MARATHON_SECONDS:
		award("maratona")
	if course.distance() >= FAR_METERS:
		award("duemila")
	var airplane := frog.floor_body() as Airplane
	if airplane and absf(frog.global_position.x) > course.play_half_width - 2.0:
		award("copilota")
	_fire_gap = fire.distance()


## Ferma sopra un rottame che galleggia.
func _watch_raft(delta: float) -> void:
	var car := frog.floor_body() as Car
	if car and car.state == Car.State.WRECK and car.is_floating():
		_raft_time += delta
		if _raft_time >= RAFT_SECONDS:
			award("zattera")
	else:
		_raft_time = 0.0


## Una strada intera, di almeno 4 corsie, senza mai fermarsi.
func _watch_road() -> void:
	var z := frog.global_position.z
	var on_road := course.kind_at(z) == Course.Kind.ROAD
	if on_road:
		if _road_entry == INF:
			_road_entry = z
			_road_stopped = false
		if Vector2(frog.velocity.x, frog.velocity.z).length() < MIN_CROSSING_SPEED:
			_road_stopped = true
	elif _road_entry != INF:
		# Uscita in avanti (verso -Z) dopo tutta la strada.
		if z < _road_entry and not _road_stopped and _road_entry - z >= ROAD_LANES * course.road_lane_width:
			award("slalom")
		_road_entry = INF


## Le planate: la più lunga in un solo volo, e sopra un treno.
func _watch_flight(delta: float) -> void:
	if not frog.is_gliding():
		_glide = 0.0
		return
	_glide += Vector2(frog.velocity.x, frog.velocity.z).length() * delta
	if _glide >= GLIDE_METERS:
		award("planata")
	var from := frog.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * TRAIN_BELOW, 8)
	var hit := frog.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and _is_train(hit.collider):
		award("treno")


func _is_train(node: Node) -> bool:
	while node != null:
		if node is Train:
			return true
		node = node.get_parent()
	return false


## Una coda: almeno 5 auto ferme nella stessa corsia, vicino alla rana.
func _watch_queue(delta: float) -> void:
	_queue_wait -= delta
	if _queue_wait > 0.0:
		return
	_queue_wait = 0.5
	var stopped := {}
	for car: Car in get_tree().get_nodes_in_group("cars"):
		if car.state != Car.State.DRIVING or car.motion_velocity().length() > 0.3:
			continue
		if car.global_position.distance_to(frog.global_position) > QUEUE_RADIUS:
			continue
		var lane := car.get_parent()
		stopped[lane] = stopped.get(lane, 0) + 1
		if stopped[lane] >= QUEUE_CARS:
			award("coda")
			return


func _on_den_reached(count: int, _distance: float) -> void:
	if count >= DENS_FOR_FROG:
		award("tana5")
	if count >= PACIFIST_DENS and _punches == 0:
		award("pacifista")
	if _fire_gap < FIRE_CLOSE:
		award("pelo")


func _on_died() -> void:
	if course.next_den_distance() < DEN_NEAR:
		award("quasi")
	if _cause == "fire" and _now - _cause_at < CAUSE_SECONDS:
		award("arrosto")
