extends SceneTree
## Pugno: a vuoto niente fermo-immagine; su un'auto rottame, fermo-immagine,
## scintille e fumo; quattro rottami vicini fanno partire la catena.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var frame := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")


func _process(_delta: float) -> bool:
	frame += 1
	var now := Time.get_ticks_msec()
	match step:
		0:
			if frame == 20:
				Lib.place(frog, Vector3(0, 0.1, 5))
				frog.punch()
				t.check(Engine.time_scale == 1.0, "pugno a vuoto: niente fermo-immagine")
				var car = Lib.cars(main).filter(func(c): return c.state == 0)[0]
				car.get_parent().set_physics_process(false)
				car.set_physics_process(false)
				car.global_position = frog.global_position + Vector3(0, car.size.y / 2.0, -1.8)
				m.car = car
				m.t = now
				step = 1
		1:
			if now - m.t > 50 and not m.has("punched"):
				m.punched = now
				frog.punch()
				t.check(m.car.state == 1, "il pugno trasforma l'auto in rottame")
				t.check(Engine.time_scale < 0.1, "pugno su un'auto: fermo-immagine (%.2f)" % Engine.time_scale)
				var particles: int = m.car.get_children().filter(func(n): return n is CPUParticles3D).size()
				t.check(particles == 2, "il rottame ha scintille e fumo")
			if m.has("punched") and now - m.punched > 200:
				t.check(Engine.time_scale == 1.0, "dopo il fermo-immagine il tempo riparte")
				var anchor = Lib.cars(main).filter(func(c): return c.state == 0)[5]
				Lib.place(frog, anchor.global_position + Vector3(0, 6, 0))
				var near = Lib.cars(main).filter(func(c): return c.state == 0 and c.global_position.distance_to(frog.global_position) < 30.0)
				for i in mini(4, near.size()):
					near[i].become_wreck()
				m = {"t": now}
				step = 2
		2:
			if now - m.t > 100:
				var hud: Node = main.get_node("Hud")
				t.check(Engine.time_scale < 0.5, "quattro rottami vicini: rallentatore (%.2f)" % Engine.time_scale)
				t.check(hud._chain_label.text.begins_with("CATENA") and hud._chain_label.modulate.a > 0.5, "compare la scritta CATENA")
				t.finish(self)
	if frame > 5000:
		t.check(false, "il test non si è bloccato (step %d)" % step)
		t.finish(self)
	return false
