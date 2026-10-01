extends SceneTree
## Investimento (danno, sbalzo fuori dalla corsia) e viaggio sul tetto.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")


func _lane_with_traffic_upstream() -> Array:
	# Una corsia e un punto libero con un veicolo che arriva da 10-25 m.
	for lane in Lib.by_script(main, "lane.gd"):
		for x in range(-20, 21, 2):
			var free := true
			var upstream := false
			for car in Lib.cars(lane):
				var d: float = (x - car.position.x) * lane.direction
				if absf(x - car.position.x) < car.size.z / 2.0 + 2.0:
					free = false
				if d > 10.0 and d < 25.0 and car.state == 0:
					upstream = true
			if free and upstream:
				return [lane, float(x)]
	return []


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	match step:
		0:
			if frame == 10:
				var spot := _lane_with_traffic_upstream()
				m.lane = spot[0]
				Lib.place(frog, Vector3(spot[1], 0.1, spot[0].global_position.z))
				frog.health_changed.connect(func(h, _max): if not m.has("hit"): m.hit = frame)
				step = 1
				start = frame
		1:
			if m.has("hit") and frame == m.hit + 60:
				var off_lane := absf(frog.global_position.z - m.lane.global_position.z)
				t.check(frog.health < frog.max_health, "un veicolo che arriva investe la rana (vita %d)" % frog.health)
				t.check(off_lane > 2.0, "lo sbalzo la butta fuori dalla corsia (%.1f m dal centro)" % off_lane)
				# Sul tetto di un'auto in marcia.
				for car in Lib.cars(m.lane.get_parent()):
					if car.state == 0 and car.model_type == "van" or car.state == 0 and car.model_type == "sedan":
						if absf(car.global_position.x) < 15.0:
							m.car = car
							break
				Lib.place(frog, m.car.global_position + Vector3.UP * (m.car.size.y / 2.0 + 0.05))
				m.frog_x = frog.global_position.x
				m.car_x = m.car.global_position.x
				step = 2
				start = frame
			if f > 900:
				t.check(false, "un veicolo investe la rana entro 15 s")
				t.finish(self)
		2:
			if f == 60:
				var car_moved: float = m.car.global_position.x - m.car_x
				var frog_moved: float = frog.global_position.x - m.frog_x
				t.check(absf(car_moved - frog_moved) < 1.0, "sul tetto la rana viaggia con l'auto (%.1f m contro %.1f)" % [frog_moved, car_moved])
				t.check(frog.health == frog.max_health, "sul tetto non si fa male")
				t.finish(self)
	return false
