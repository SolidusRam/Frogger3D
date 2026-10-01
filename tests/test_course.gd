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


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	course = main.get_node("Course")
	course.den_reached.connect(func(count, _distance): dens = count)


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame > 5 and z > -2000.0:
		z -= 1.5
		frog.global_position = Vector3(0, 5, z)
		frog.velocity = Vector3.ZERO
	for chunk in course.get_children():
		if not seen.has(chunk.name):
			seen[chunk.name] = true
			order.append(String(chunk.name).get_slice("_", 0))
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
		t.check(dens >= 10, "in 2 km si raggiungono almeno 10 tane (%d)" % dens)
		t.check(absf(frog.global_position.z - z) < 200.0 and frog.global_position.y > -1.0, "dopo la caduta ricompare nell'ultima tana (z=%.0f)" % frog.global_position.z)
		t.check(course.distance() > 1990.0, "la distanza percorsa è registrata (%.0f m)" % course.distance())
		t.finish(self)
	return false
