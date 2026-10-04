extends SceneTree
## Aeroporto: l'aereo travolge la rana, la fiamma dietro i motori brucia, il
## getto la spinge via e scaglia i rottami, col deltaplano nel getto si sale
## in alto, sull'ala si sta sicuri, un'auto in pista diventa rottame, sotto i
## motori corrono le strade di servizio.

const Lib := preload("res://tests/lib.gd")
const LANE := Vector3(0, 0, 320)

var t := Lib.new()
var main: Node
var frog: Node3D
var plane: Node3D
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


func _new_plane(x: float) -> void:
	if plane:
		plane.queue_free()
	plane = load("res://scripts/airplane.gd").create(1.0, 7.0)
	plane.position = LANE + Vector3(x, 0, 0)
	main.add_child(plane)


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				main.get_node("Course").den_reached.disconnect(main._on_den_reached)
				Lib.test_ground(main)
				_new_plane(-40.0)
				Lib.place(frog, LANE + Vector3(0, 0.1, 0))
				var car: Node3D = Lib.cars(main).filter(func(c): return c.state == 0 and c.model_type == "sedan")[0]
				car.get_parent().set_physics_process(false)
				car.set_physics_process(false)
				car.global_position = LANE + Vector3(-15, car.size.y / 2.0, 6)
				m.car = car
				_next(1)
				m.car = car
		1: # l'aereo arriva: travolge la rana sulla sua linea e l'auto sotto il motore
			if f == 360:
				t.check(frog.health <= frog.max_health - 35, "la fusoliera travolge la rana (vita %d)" % frog.health)
				t.check(m.car.state == 1, "un'auto sotto il motore diventa rottame")
				t.check(not plane.has_method("become_wreck"), "l'aereo non diventa mai rottame")
				_next(2)
		2: # la fiamma brucia, più indietro il getto spinge soltanto
			if f == 1:
				_new_plane(-10.0)
			if f == 3:
				frog.heal_full()
				# Subito dietro il motore destro, a terra: nella fiamma.
				Lib.place(frog, plane.to_global(Vector3(6, 0, 3)) + Vector3(0, 0.1, 0))
			if f == 33:
				t.check(frog.health < frog.max_health - 10, "la fiamma dietro il motore brucia (vita %d)" % frog.health)
				frog.heal_full()
				# Più indietro, a terra: solo vento.
				Lib.place(frog, plane.to_global(Vector3(6, 0, 12)) + Vector3(0, 0.1, 0))
				m.x = frog.global_position.x
			if f == 63:
				var pushed: float = m.x - frog.global_position.x
				t.check(pushed > 2.0, "il getto spinge via la rana (%.1f m in 0,5 s)" % pushed)
				t.check(frog.health == frog.max_health, "lontano dalla fiamma il getto spinge ma non ferisce")
				var wreck: Node3D = Lib.cars(main).filter(func(c): return c.state == 0 and c.model_type == "compact")[0]
				wreck.get_parent().set_physics_process(false)
				wreck.global_position = plane.to_global(Vector3(-6, 0, 10)) + Vector3(0, 0.8, 0)
				wreck.become_wreck()
				wreck.linear_velocity = Vector3.ZERO
				m.wreck = wreck
				m.wreck_x = wreck.global_position.x
			if f == 93:
				var thrown: float = m.wreck_x - m.wreck.global_position.x
				t.check(thrown > 4.0, "il getto scaglia i rottami (%.1f m in 0,5 s)" % thrown)
				_next(3)
		3: # col deltaplano il getto è un ascensore
			if f == 1:
				_new_plane(-10.0)
			if f < 12:
				Lib.place(frog, plane.to_global(Vector3(6, 0, 10)) + Vector3(0, 3.0, 0))
			if f == 12:
				Input.action_press("jump")
				frog.glider_power.gliding = true
				m.y = frog.global_position.y
				m.charge = frog.glider_power.charge
			if f == 60:
				t.check(frog.glider_power.charge == m.charge, "nel getto la carica non si consuma (%.1f su %.1f)" % [frog.glider_power.charge, m.charge])
			if f == 102:
				Input.action_release("jump")
				var risen: float = frog.global_position.y - m.y
				t.check(risen > 6.0, "nel getto il deltaplano sale in alto (%+.1f m in 1,5 s)" % risen)
				_next(4)
		4: # sull'ala si sta sicuri e si viaggia con l'aereo
			if f == 1:
				_new_plane(-10.0)
			if f == 3:
				Lib.place(frog, plane.to_global(Vector3(-9, 2.9, 0.5)))
				m.x = frog.global_position.x
				m.plane_x = plane.global_position.x
			if f == 63:
				var moved: float = frog.global_position.x - m.x
				var plane_moved: float = plane.global_position.x - m.plane_x
				t.check(absf(moved - plane_moved) < 1.0, "sull'ala la rana viaggia con l'aereo (%.1f m contro %.1f)" % [moved, plane_moved])
				t.check(frog.health == frog.max_health, "sull'ala non si fa male")
				var taxiway: Node3D = load("res://scripts/taxiway.gd").new()
				taxiway.position = LANE + Vector3(0, 0, -40)
				main.add_child(taxiway)
				var lanes: Array = taxiway.get_children().filter(func(n): return n.get_script() and n.get_script().resource_path.get_file() == "lane.gd")
				var under_engines := lanes.size() == 2 and lanes.all(func(l): return absf(absf(l.position.z) - 6.0) < 0.01)
				t.check(under_engines, "sotto i motori corrono due strade di servizio (%d)" % lanes.size())
				t.finish(self)
	return false
