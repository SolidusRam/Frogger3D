extends SceneTree
## Il suono: ogni nome usato nel codice ha il suo file; le auto hanno il
## motore e l'incendio il suo crepitio; il salto, il pugno (che copre lo
## schianto dell'auto colpita), lo schianto di un'auto qualsiasi e il calore
## che sale fanno partire il loro suono; alla morte il mondo si attutisce,
## come dietro il menu. Nei test non suona niente: Sfx conta
## soltanto (vedi Sfx.silent).

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var sfx: Node
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	sfx = root.get_node("Sfx")


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		10:
			t.check(sfx.silent, "nei test headless l'audio è muto e conta soltanto")
			var missing := _missing_sounds()
			t.check(missing.is_empty(), "ogni suono usato nel codice ha il suo file (mancano: %s)" % ", ".join(missing))
			t.check(sfx.loop_count(&"car_engine") > 10, "le auto in strada hanno il motore acceso (%d)" % sfx.loop_count(&"car_engine"))
			t.check(sfx.loop_count(&"fire_loop") == 1 and sfx.loop_count(&"fire_roar") == 1, "l'incendio crepita e ruggisce")
			Lib.place(frog, Vector3(0, 0.1, 5))
			m.jumps = _count(&"frog_jump")
			Input.action_press("jump")
		12:
			Input.action_release("jump")
			t.check(_count(&"frog_jump") == m.jumps + 1, "il salto fa \"bwoip\"")
		40:
			var car = Lib.cars(main).filter(func(c): return c.state == 0)[0]
			car.get_parent().set_physics_process(false)
			car.set_physics_process(false)
			Lib.place(frog, Vector3(0, 0.1, 5))
			car.global_position = frog.global_position + Vector3(0, car.size.y / 2.0, -1.8)
			m.car = car
		45:
			m.hits = _count(&"punch_hit")
			m.crashes = _count(&"car_crash")
			frog.punch()
			main._hitstop_until = 0
			t.check(_count(&"punch_hit") == m.hits + 1, "il pugno a segno suona")
			t.check(_count(&"car_crash") == m.crashes, "l'auto presa a pugni non aggiunge il suo schianto")
			t.check(not sfx.is_looping(m.car, &"car_engine"), "il rottame ha il motore spento")
			var other = Lib.cars(main).filter(func(c): return c.state == 0)[3]
			other.become_wreck()
			t.check(_count(&"car_crash") == m.crashes + 1, "un'auto che diventa rottame da sola si schianta con rumore")
			m.heat = _count(&"heat_up")
			root.get_node("Heat").set_value(45.0)
		50:
			t.check(_count(&"heat_up") > m.heat, "il calore che sale di livello suona l'allarme")
			t.check(sfx._muffle_target == 0.0, "in corsa il mondo si sente pieno")
			Lib.place(frog, Vector3(0, 0.1, 5))
			frog.take_hit(1000, Vector3.ZERO)
			t.check(frog.is_dead and sfx._muffle_target == 1.0, "alla fine della corsa il mondo si attutisce")
			t.finish(self)
	return false


func _count(sound: StringName) -> int:
	return sfx.played.get(sound, 0)


## I nomi fra &"..." sulle righe che chiamano Sfx, in tutti gli script.
func _missing_sounds() -> Array[String]:
	var missing: Array[String] = []
	var name_pattern := RegEx.create_from_string("&\"([a-z0-9_]+)\"")
	var paths: Array[String] = []
	for dir in ["res://scripts/", "res://scripts/powers/"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				paths.append(dir + file)
	for path in paths:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.contains("Sfx."):
				continue
			for found in name_pattern.search_all(line):
				var sound := found.get_string(1)
				if not sfx._files.has(sound) and not missing.has(sound):
					missing.append(sound)
	return missing
