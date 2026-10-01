extends SceneTree
## Traffico: niente compenetrazioni a calore 0 e 100, code dietro un rottame
## fermo, prestazioni della fisica al calore massimo.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var heat: Node
var frame := 0
var start := 0
var step := 0
var m := {}
var query := PhysicsShapeQueryParameters3D.new()


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	heat = root.get_node("Heat")
	query.collision_mask = 4


## Veicoli in marcia che si compenetrano tra loro o con un rottame.
func _count_overlaps() -> int:
	var overlaps := 0
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	for car in Lib.cars(main):
		if car.state != 0 or car.collision_layer == 0:
			continue
		var box := BoxShape3D.new()
		box.size = car.size * 0.8
		query.shape = box
		query.transform = car.global_transform
		query.exclude = [car.get_rid()]
		for hit in space.intersect_shape(query, 8):
			var other = hit.collider
			if other.has_method("become_wreck") and other.collision_layer != 0:
				overlaps += 1
	return overlaps


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	frog.global_position = Vector3(0, 40, frog.global_position.z)
	frog.velocity = Vector3.ZERO
	match step:
		0: # calore 0: niente compenetrazioni
			if f % 10 == 0:
				m.overlaps = m.get("overlaps", 0) + _count_overlaps()
			if f == 900:
				t.check(m.overlaps == 0, "calore 0, 15 s: nessuna compenetrazione (%d)" % m.overlaps)
				_jam_setup()
		1: # coda dietro un rottame fermo
			if f == 600:
				var lane: Node = m.lane
				var stopped := 0
				var wrecks := 0
				for car in Lib.cars(lane):
					if car.state == 0 and car.motion_velocity().length() < 0.5:
						stopped += 1
					if car.state == 1:
						wrecks += 1
				t.check(stopped >= 1, "dietro un rottame fermo si forma una coda (%d auto ferme)" % stopped)
				t.check(wrecks == 1, "la coda si forma senza tamponamenti (%d rottami)" % wrecks)
				step = 2
				start = frame
				m = {"overlaps": 0, "max_ms": 0.0}
				heat.value = 100.0
		2: # calore 100: niente compenetrazioni, fisica sostenibile
			if f % 10 == 0:
				m.overlaps += _count_overlaps()
			if f > 60:
				m.max_ms = maxf(m.max_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			if f == 1800:
				t.check(m.overlaps == 0, "calore 100, 30 s: nessuna compenetrazione (%d)" % m.overlaps)
				t.check(Lib.cars(main).filter(func(c): return c.state == 1).size() <= 90, "al calore 100 i rottami restano sotto il tetto")
				print("  (fisica: al massimo %.1f ms per passo)" % m.max_ms)
				t.finish(self)
	return false


func _jam_setup() -> void:
	step = 1
	start = frame
	for lane in Lib.by_script(main, "lane.gd"):
		for car in Lib.cars(lane):
			if car.state == 0 and absf(car.position.x) < 5.0 and car.model_type != "truck":
				m.lane = lane
				car.become_wreck()
				car.linear_velocity = Vector3.ZERO
				car.freeze = true
				return
