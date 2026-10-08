class_name Taxiway
extends Node3D
## La pista dell'aeroporto: asfalto con le linee gialle e gli aerei che
## atterrano, uno dopo l'altro: scendono dal cielo, toccano terra in un punto
## diverso ogni volta, frenano e rullano via (vedi Airplane). Accanto alla
## pista corrono due strade di servizio con i trenini bagagli: il getto porta
## via valigie e pacchi e li scaglia. Dal livello Heat.STEP_LEVEL di calore
## metà degli aerei atterra di pancia. Con la distanza gli aerei arrivano più
## spesso. Corre lungo l'asse X locale.

var direction := 1.0
var length := 400.0
var play_half_width := 37.0
## Secondi tra un aereo e l'altro: con la distanza (difficulty) scendono fino
## a 6-10.
var min_interval := 9.0
var max_interval := 15.0
var difficulty := 0
## Il cielo (vedi Worlds): l'aereo a eliche.
var sky := false
## Quanti aerei atterrano di pancia dal livello dei gradini.
var belly_chance := 0.5
## Metri di rampa prima del punto di contatto: l'aereo parte da lì, alto
## APPROACH * Airplane.GLIDE_SLOPE (14 m).
const APPROACH := 70.0
## Velocità base; il calore la alza fino al +30%.
var base_speed := 7.0
var max_heat_bonus := 0.3
## Strade di servizio: sotto le ali, fuori dai motori e dalla fiamma, dove il
## getto si è già allargato. Velocità dei trenini e spazio tra l'uno e l'altro.
const SERVICE_ROAD_Z := Airplane.ENGINE_X + 3.0
var service_min_speed := 5.0
var service_max_speed := 8.0
## Trenini fitti (5 ottobre 2026): più carico da scagliare.
var service_min_gap := 10.0
var service_max_gap := 22.0

var _timer := 0.0


func _ready() -> void:
	min_interval = maxf(9.0 - 0.75 * difficulty, 6.0)
	max_interval = maxf(15.0 - 1.25 * difficulty, 10.0)
	_build_markings()
	for side in [-1.0, 1.0]:
		_add_service_road(side * SERVICE_ROAD_Z)
	# All'inizio un aereo è già in arrivo.
	_send_plane()
	_timer = randf_range(min_interval, max_interval)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_send_plane()
		_timer = randf_range(min_interval, max_interval)
	for child in get_children():
		var plane := child as Airplane
		if plane and plane.tail_x() * direction > play_half_width + 60.0:
			plane.queue_free()


## Un aereo in arrivo dal cielo. Tocca terra fra 8 e 50 m dentro la zona di
## gioco; di pancia appena entrato, così scivola su tutta la pista.
func _send_plane() -> void:
	var plane := Airplane.create(direction, base_speed * (1.0 + max_heat_bonus * Heat.ratio()))
	plane.play_half_width = play_half_width
	plane.sky = sky
	var belly := Heat.level() >= Heat.STEP_LEVEL and randf() < belly_chance
	var into := randf_range(0.0, 6.0) if belly else randf_range(8.0, 50.0)
	plane.land(-direction * (play_half_width - into), APPROACH, belly)
	add_child(plane)
	# Una mosca su un aereo su 2, su un'ala; può essere d'oro.
	Fly.maybe_add(plane, 0.5, Vector3(8.0 * (1.0 if Fly.rng().randf() < 0.5 else -1.0), 3.4, 0.5), true)


func _add_service_road(z: float) -> void:
	var road := ServiceRoad.new()
	road.position.z = z
	road.direction = 1.0 if randf() < 0.5 else -1.0
	road.speed = randf_range(service_min_speed, service_max_speed)
	road.length = length
	road.play_half_width = play_half_width
	road.min_gap = service_min_gap
	road.max_gap = service_max_gap
	road.home = self
	add_child(road)


func _build_markings() -> void:
	var line := MeshInstance3D.new()
	line.mesh = _box(Vector3(length, 0.02, 0.35), "taxi_line")
	line.position.y = 0.02
	add_child(line)
	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		edge.mesh = _box(Vector3(length, 0.02, 0.2), "taxi_line")
		edge.position = Vector3(0.0, 0.02, side * 14.0)
		add_child(edge)


static func _box(size: Vector3, palette_key: String) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Style.material(palette_key)
	return mesh
