extends SceneTree
## Misura delle prestazioni, non fa parte del gioco (vedi tools/bench.sh).
## Senza grafica: misura quanto costa alla CPU ogni fotogramma (script e
## fisica), che è il collo di bottiglia probabile con tanti rottami. Un
## fotogramma a 60 fps ha 16,7 ms in tutto, grafica compresa.
## SCENARIO: corsa (calore 0, la rana avanza a 8 m/s) | caos (calore 100) |
## ingorgo (calore 100, la rana ferma su una strada, rottami fino al massimo).
## SECONDS: secondi simulati (60).

const Lib := preload("res://tests/lib.gd")

var scenario := OS.get_environment("SCENARIO")
var seconds := float(OS.get_environment("SECONDS")) if OS.get_environment("SECONDS") != "" else 60.0
var main: Node
var frog: Node3D
var frame := 0
var last_usec := 0
var times: Array[float] = []
var physics: Array[float] = []
var peak := {}
var draws: Array[float] = []
var objects: Array[float] = []
var primitives: Array[float] = []


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	frog.invincible = true


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if last_usec > 0 and frame > 120:
		times.append((now - last_usec) / 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	last_usec = now
	frame += 1
	if paused:
		main.get_node("Upgrades").choose(0)
	var heat: Node = root.get_node("Heat")
	if frame == 2:
		heat.running = false
		heat.set_value(0.0 if scenario == "corsa" else 100.0)
	match scenario:
		"corsa", "caos":
			frog.global_position = Vector3(0, 30, -8.0 / 60.0 * frame)
			frog.velocity = Vector3.ZERO
		"ingorgo":
			if frame == 3:
				main.get_node("Course").jump_to(2) # strada
			# Ogni mezzo secondo le auto in marcia più vicine diventano rottami.
			if frame % 30 == 0:
				for car in Lib.cars(main):
					if car.state == 0 and car.global_position.distance_to(frog.global_position) < 40.0:
						car.become_wreck()
						car.apply_central_impulse(Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)) * car.mass * 6.0)
						break
	_track_peak()
	if frame > 120:
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if frame >= 120 + int(seconds * 60.0):
		_report()
		quit()
	return false


func _track_peak() -> void:
	var cars := Lib.cars(main)
	var wrecks := cars.filter(func(car): return car.state == 1).size()
	var counts := {
		"nodi": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"veicoli": cars.size(),
		"rottami": wrecks,
		"corpi fisici attivi": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"coppie di collisione": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"mosche": get_nodes_in_group("flies").size(),
	}
	for key in counts:
		peak[key] = maxf(peak.get(key, 0.0), counts[key])


func _report() -> void:
	var sorted := times.duplicate()
	sorted.sort()
	var sorted_physics := physics.duplicate()
	sorted_physics.sort()
	var avg := 0.0
	for t in times:
		avg += t
	avg /= times.size()
	var p := func(list: Array, q: float) -> float: return list[mini(int(list.size() * q), list.size() - 1)]
	print("SCENARIO %s, %d s simulati, %d fotogrammi" % [scenario, seconds, times.size()])
	print("  CPU per fotogramma: media %.2f ms, 95%% %.2f ms, 99%% %.2f ms, peggiore %.2f ms" % [avg, p.call(sorted, 0.95), p.call(sorted, 0.99), sorted[-1]])
	print("  di cui fisica:      95%% %.2f ms, peggiore %.2f ms" % [p.call(sorted_physics, 0.95), sorted_physics[-1]])
	print("  sopra 8 ms (metà del fotogramma): %d fotogrammi" % times.filter(func(t): return t > 8.0).size())
	if draws.max() > 0:
		var mean := func(list: Array) -> float: return list.reduce(func(a, b): return a + b, 0.0) / list.size()
		print("  grafica: chiamate di disegno media %d (max %d), oggetti %d (max %d), triangoli %d (max %d)" % [
			mean.call(draws), draws.max(), mean.call(objects), objects.max(), mean.call(primitives), primitives.max()])
	for key in peak:
		print("  massimo %s: %d" % [key, peak[key]])
