extends SceneTree
## Mosche: stanno sopra le cose che si muovono, si prendono toccandole (la
## d'oro è una valuta a sé), la lingua le mangia a distanza senza agganciarsi, ogni
## tana ne dà 3, a fine run si sommano al totale salvato; una run di prova
## non le conta.

const Lib := preload("res://tests/lib.gd")
const BASE := Vector3(0, 0, 320)

var t := Lib.new()
var main: Node
var frog: Node3D
var upgrades: Node
var cars: Array = []
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


func _forward() -> Vector3:
	return -frog.camera_rig.flat_basis().z


func _new_fly(carrier: Node3D, at: Vector3, golden := false) -> Node3D:
	var fly: Node3D = load("res://scripts/fly.gd").new()
	fly.golden = golden
	fly.position = at
	carrier.add_child(fly)
	return fly


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		upgrades.choose(0)
	match step:
		0:
			if frame == 60:
				main.get_node("Course").den_reached.disconnect(main._on_den_reached)
				root.get_node("Heat").running = false
				var flies: Array = get_nodes_in_group("flies")
				var on_movers: bool = flies.all(func(fly): return fly.get_parent() is RigidBody3D or fly.get_parent() is AnimatableBody3D)
				t.check(not flies.is_empty() and on_movers, "ci sono mosche, sopra le cose che si muovono (%d)" % flies.size())
				Lib.test_ground(main)
				cars = Lib.cars(main).filter(func(c): return c.state == 0 and c.model_type in ["compact", "sedan"]).slice(0, 3)
				for car in cars:
					car.get_parent().set_physics_process(false)
					car.set_physics_process(false)
					# Le mosche nate con l'auto falserebbero i conti.
					for child in car.get_children():
						if child.is_in_group("flies"):
							child.free()
				_next(1)
		1: # toccandole: 1, la d'oro 5
			if f == 1:
				var car: Node3D = cars[0]
				car.global_position = BASE + Vector3(0, car.size.y / 2.0, 0)
				_new_fly(car, Vector3(0, car.size.y / 2.0 + 0.7, 0))
				_new_fly(car, Vector3(0, car.size.y / 2.0 + 0.7, 0.4), true)
				Lib.place(frog, car.global_position + Vector3(0, car.size.y / 2.0 + 0.1, 0.5))
			if f == 20:
				t.check(main.run_flies == 1 and main.run_golden == 1, "toccandole si prendono: una mosca e una mosca d'oro (%d e %d)" % [main.run_flies, main.run_golden])
				_next(2)
		2: # la lingua le mangia a distanza
			if f == 1:
				upgrades.apply("tongue")
				Lib.place(frog, BASE + Vector3(-20, 0.1, 0))
				var car: Node3D = cars[1]
				car.global_position = BASE + Vector3(-20, car.size.y / 2.0, 0) + _forward() * 8.0
				m.fly = _new_fly(car, Vector3(0, car.size.y / 2.0 + 0.7, 0))
				m.before = main.run_flies
			if f == 3:
				t.check(frog.tongue_power.aimed == m.fly, "il mirino della lingua preferisce la mosca")
				Input.action_press("tongue")
			if f == 5:
				Input.action_release("tongue")
			if f == 20:
				t.check(main.run_flies == m.before + 1 and not frog.tongue_power.attached, "la lingua mangia la mosca a distanza, senza agganciarsi")
				_next(3)
		3: # la tana ne dà 3; a fine run si sommano
			if f == 1:
				m.before = main.run_flies
				main._on_den_reached(1, 10.0)
			if f == 3:
				t.check(main.run_flies == m.before + 3, "ogni tana dà 3 mosche")
				m.run = main.run_flies
				frog.take_hit(1000, Vector3.ZERO)
			if f == 30:
				var config := ConfigFile.new()
				config.load("user://progressi_test.cfg")
				var saved: int = config.get_value("stagno", "mosche", -1)
				t.check(saved == m.run, "a fine run le mosche si sommano al totale salvato (%d)" % saved)
				t.check(main.get_node("Hud")._game_over_text.text.contains("Mosche: +%d" % m.run), "la fine della corsa le mostra")
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progressi_test.cfg"))
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
				t.finish(self)
	return false
