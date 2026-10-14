extends SceneTree
## Una clip del gioco per README e post, non fa parte del gioco (vedi
## tools/clip.sh): la rana sul bordo di una strada prende a pugni le auto che
## le passano davanti, e i rottami volano sulle altre corsie. Con
## --write-movie e --fixed-fps Godot registra un fotogramma alla volta, quindi
## la clip è fluida anche se il pc disegna lento.
## CALORE: il calore della scena (65: auto veloci, che dal 60 sbandano da sole). SEED: il seme del traffico.
## YAW, PITCH: la telecamera, in gradi (20 e -18). SECONDI: quanto dura la
## scena dopo il riscaldamento (12). HUD=1 lascia l'interfaccia.
## Nei -s non si nominano i tipi del gioco: Course.Kind.ROAD è 2.

const Lib := preload("res://tests/lib.gd")
const ROAD := 2
const FPS := 30
## Secondi di gioco prima della scena: il traffico riempie la strada.
const WARMUP := 4.0

var main: Node
var frog: Node3D
var rig: Node3D
var frame := 0
var start := -1
var lane_z := 0.0
var spot := Vector3.ZERO


func _initialize() -> void:
	main = Lib.load_main(self)
	if OS.get_environment("SEED") != "":
		seed(int(OS.get_environment("SEED")))
	frog = main.get_node("Frog")
	frog.invincible = true
	rig = Lib.by_script(frog, "camera_rig.gd")[0]


func _env(name: String, default: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else default


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		var heat: Node = root.get_node("Heat")
		heat.running = false
		heat.set_value(_env("CALORE", 65.0))
		main.get_node("Course").jump_to(ROAD)
	# Interfaccia nascosta: la clip è il gioco, non l'HUD né la scritta della
	# modalità prova.
	if OS.get_environment("HUD") != "1":
		main.get_node("Hud").visible = false
		for test_mode in Lib.by_script(main, "test_mode.gd"):
			for layer in test_mode.find_children("*", "CanvasItem", true, false):
				layer.visible = false
	if start < 0:
		if frame < int(WARMUP * FPS):
			return false
		# La corsia più vicina davanti alla rana, dalle auto in marcia.
		var ahead := Lib.cars(main).filter(func(c): return c.state == 0 and c.global_position.z < frog.global_position.z - 1.0)
		if ahead.is_empty():
			return false
		ahead.sort_custom(func(a, b): return a.global_position.z > b.global_position.z)
		lane_z = ahead[0].global_position.z
		spot = Vector3(0.0, 0.1, lane_z + 1.8)
		Lib.place(frog, spot)
		start = frame
		print("CLIP inizio %d" % frame)
	# La rana resta al suo posto, anche se un rottame la sbalza.
	if frog.global_position.distance_to(spot) > 1.5:
		Lib.place(frog, spot)
	# La telecamera di tre quarti, ferma.
	rig.rotation.y = deg_to_rad(_env("YAW", 20.0))
	rig.get_node("Pitch").rotation.x = deg_to_rad(_env("PITCH", -18.0))
	# Pugno all'auto della corsia che passa davanti alla rana.
	for car in Lib.cars(main):
		if car.state == 0 and absf(car.global_position.z - lane_z) < 0.8 and absf(car.global_position.x - frog.global_position.x) < 1.0:
			frog.punch()
			print("CLIP pugno %d" % frame)
			break
	if frame - start >= int(_env("SECONDI", 12.0) * FPS):
		print("CLIP fine %d" % frame)
		quit()
	return false
