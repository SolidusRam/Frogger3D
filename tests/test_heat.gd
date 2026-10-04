extends SceneTree
## Calore: sale col tempo, coi poteri e coi rottami. Morte: schermata di fine,
## record salvato (nel file dei test), calore fermo. Ricomincia: tutto da zero.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var heat: Node
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	heat = root.get_node("Heat")


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	match step:
		0:
			if frame == 2:
				m.start = heat.value
			if frame == 602:
				t.check(absf(heat.value - m.start - 1.5) < 0.1, "10 s senza fare niente: +1,5 di calore (%.2f)" % (heat.value - m.start))
				var before: float = heat.value
				frog.power_used.emit(&"super_jump")
				t.check(is_equal_approx(heat.value - before, 3.0), "super salto: +3")
				before = heat.value
				frog.power_used.emit(&"glide")
				t.check(is_equal_approx(heat.value - before, 2.0), "deltaplano: +2")
				before = heat.value
				frog.power_used.emit(&"punch")
				t.check(is_equal_approx(heat.value - before, 1.0), "pugno: +1")
				before = heat.value
				var driving: Array = Lib.cars(main).filter(func(c): return c.state == 0)
				driving.sort_custom(func(a, b): return a.global_position.distance_to(frog.global_position) < b.global_position.distance_to(frog.global_position))
				driving[0].become_wreck()
				t.check(is_equal_approx(heat.value - before, 0.6), "un rottame vicino alla rana: +0,6")
				before = heat.value
				var far: Node3D = driving[1]
				far.get_parent().set_physics_process(false)
				far.global_position = frog.global_position + Vector3(0, 0, 320)
				far.become_wreck()
				t.check(is_equal_approx(heat.value, before), "un rottame lontano dalla rana non scalda")
				main.get_node("Course").best_distance = 123.0
				Lib.place(frog, Vector3(0, 0.5, 0))
				frog.take_hit(1000, Vector3.ZERO)
				step = 1
				start = frame
		1:
			if f == 30:
				var hud: Node = main.get_node("Hud")
				t.check(frog.is_dead, "con la vita a zero la rana muore")
				t.check(hud._game_over.visible, "compare la schermata di fine")
				t.check(not heat.running, "il calore si ferma")
				var config := ConfigFile.new()
				var saved := config.load("user://record_test.cfg") == OK and is_equal_approx(config.get_value("record", "distance", 0.0), 123.0)
				t.check(saved, "il record è salvato su disco")
				t.check(hud.game_over_text().contains("Nuovo record"), "la schermata annuncia il nuovo record")
				main.restart()
				step = 2
				start = frame
		2:
			if f == 30:
				var new_main := current_scene
				t.check(new_main != main, "Ricomincia carica una partita nuova")
				t.check(heat.value < 1.0, "Ricomincia azzera il calore")
				t.check(not new_main.get_node("Frog").is_dead, "Ricomincia rimette in vita la rana")
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
				t.finish(self)
	return false
