extends SceneTree
## Aeroporto: l'aereo travolge la rana, il getto la spinge via, col deltaplano
## nel getto si vola, sull'ala si sta sicuri, un'auto in pista diventa rottame.

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
		2: # il getto spinge la rana
			if f == 1:
				_new_plane(-10.0)
			if f == 3:
				# Dietro il motore destro, a terra.
				Lib.place(frog, plane.to_global(Vector3(6, 0, 6)) + Vector3(0, 0.1, 0))
				m.x = frog.global_position.x
			if f == 33:
				var pushed: float = m.x - frog.global_position.x
				t.check(pushed > 2.0, "il getto spinge via la rana (%.1f m in 0,5 s)" % pushed)
				t.check(frog.health == frog.max_health, "il getto spinge ma non ferisce")
				_next(3)
		3: # col deltaplano il getto diventa una corrente
			if f == 1:
				_new_plane(-10.0)
			if f < 12:
				Lib.place(frog, plane.to_global(Vector3(6, 0, 5)) + Vector3(0, 3.0, 0))
			if f == 12:
				Input.action_press("jump")
				frog.glider_power.gliding = true
				m.y = frog.global_position.y
				m.x = frog.global_position.x
			if f == 42:
				Input.action_release("jump")
				var travelled: float = m.x - frog.global_position.x
				t.check(travelled > 4.0, "col deltaplano il getto lancia lontano (%.1f m in 0,5 s)" % travelled)
				t.check(frog.global_position.y > m.y - 0.3, "nel getto il deltaplano non scende (%+.1f m)" % (frog.global_position.y - m.y))
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
				t.finish(self)
	return false
