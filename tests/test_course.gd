extends SceneTree
## Percorso infinito: 2 km di volo. Blocchi creati e cancellati, fiumi sempre
## tra due blocchi di terra, tane registrate, ripartenza dall'ultima tana.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var course: Node3D
var frame := 0
var z := 0.0
var max_chunks := 0
var order: Array[String] = []
var seen := {}
var dens := 0
var lane_lengths: Array[float] = []


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	course = main.get_node("Course")
	# Le sezioni vere, non quelle corte che gli altri test tengono fisse.
	for property in ["section_obstacles", "section_growth_cap"]:
		course.set(property, course.get_script().get_property_default_value(property))
	course.den_reached.connect(func(count, _distance): dens = count)


func _physics_process(_delta: float) -> bool:
	frame += 1
	# Nelle tane il gioco si ferma per le carte dei power-up: se ne sceglie una.
	if paused:
		current_scene.get_node("Upgrades").choose(0)
	if frame > 5 and z > -2000.0:
		z -= 1.5
		frog.global_position = Vector3(0, 5, z)
		frog.velocity = Vector3.ZERO
	for chunk in course.get_children():
		if not seen.has(chunk.name):
			seen[chunk.name] = true
			order.append(String(chunk.name).get_slice("_", 0))
			# Le corsie di ogni strada incontrata (alla fine, nel tratto rimasto,
			# potrebbe non esserci nessuna strada).
			for lane in Lib.by_script(chunk, "lane.gd"):
				lane_lengths.append(lane.half_length)
	max_chunks = maxi(max_chunks, course.get_child_count())
	if z <= -2000.0 and not seen.has("_fallen"):
		seen["_fallen"] = frame
		frog.global_position = Vector3(0, -30, z)
	if seen.has("_fallen") and frame == seen["_fallen"] + 3:
		var bad := 0
		for i in range(1, order.size() - 1):
			if order[i] == "RIVER" and (order[i - 1] in ["RIVER", "ROAD"] or order[i + 1] in ["RIVER", "ROAD"]):
				bad += 1
		t.check(max_chunks <= 25, "i blocchi non si accumulano (al massimo %d insieme)" % max_chunks)
		t.check(bad == 0, "ogni fiume ha terra su entrambi i lati")
		var without_edges := 0
		for chunk in course.get_children():
			if chunk.has_meta("kind") and (not chunk.has_node("Edges") or chunk.get_node("Edges").get_child_count() == 0):
				without_edges += 1
		t.check(without_edges == 0, "ogni blocco ha il suo bordo visibile (%d senza)" % without_edges)
		t.check(not lane_lengths.is_empty() and lane_lengths.all(func(l): return l > 40.0), "le auto nascono dentro le gallerie, oltre il bordo (%d corsie)" % lane_lengths.size())
		# La prima sezione finisce con la prima tana.
		var first_section := order.slice(0, order.find("DEN"))
		t.check(order.count("RAIL") >= 1 and not first_section.has("RAIL"), "le ferrovie compaiono, ma non nella prima sezione (%d)" % order.count("RAIL"))
		t.check(dens >= 6 and dens <= 12, "in 2 km si raggiungono fra 6 e 12 tane (%d)" % dens)
		# Una sezione avanzata è lunga circa 270 m: l'ultima tana può essere lontana.
		t.check(absf(frog.global_position.z - z) < 350.0 and frog.global_position.y > -1.0, "dopo la caduta ricompare nell'ultima tana (z=%.0f)" % frog.global_position.z)
		t.check(course.distance() > 1990.0, "la distanza percorsa è registrata (%.0f m)" % course.distance())
		t.finish(self)
	return false
