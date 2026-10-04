extends SceneTree
## Ferrovia: avviso leale prima del treno, il treno travolge rana e auto,
## sul tetto si viaggia sicuri, dopo il passaggio tutto torna in attesa. Il
## gradino: dal livello 3 di calore il rapido, più veloce ma con lo stesso
## avviso, la cui scia risucchia verso i binari.

const Lib := preload("res://tests/lib.gd")
const TRACK_Z := 5.0

var t := Lib.new()
var main: Node
var frog: Node3D
var track: Node3D
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


func _lit_lamps() -> int:
	return track._lamps.filter(func(lamp): return lamp.visible).size()


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	match step:
		0:
			if frame == 5:
				# Un binario nella zona di partenza, dove c'è terreno sotto la rana.
				track = load("res://scripts/rail_track.gd").new()
				track.direction = 1.0
				main.add_child(track)
				track.position = Vector3(0, 0, TRACK_Z)
				track._timer = 0.3
				Lib.place(frog, Vector3(0, 0.1, TRACK_Z))
				var car: Node3D = Lib.cars(main).filter(func(c): return c.state == 0)[0]
				car.get_parent().set_physics_process(false)
				car.set_physics_process(false)
				car.global_position = Vector3(-15, car.size.y / 2.0, TRACK_Z)
				m.car = car
				m.car_start = car.global_position
				frog.health_changed.connect(func(h, _max): if not m.has("hit"): m.hit = h)
				_next(1)
				m.car = car
				m.car_start = car.global_position
		1: # avviso, poi il treno
			if track.phase == 1 and not m.has("warning_at"):
				m.warning_at = f
			if m.has("warning_at") and not m.has("lamps_seen") and _lit_lamps() > 0:
				m.lamps_seen = true
			if track.train and not m.has("entered_at") and absf(track.train.nose_x()) <= 37.0:
				m.entered_at = f
				var lead: float = (m.entered_at - m.warning_at) / 60.0
				t.check(m.has("lamps_seen"), "le luci lampeggiano durante l'avviso")
				t.check(lead > 2.3 and lead < 2.7, "il treno entra nella zona di gioco dopo circa 2,5 s di avviso (%.2f)" % lead)
				t.check(not m.has("hit"), "prima che il treno arrivi, la rana sui binari non viene colpita")
			# Il treno entra a 37 m dalla rana: la raggiunge dopo circa 1,4 s.
			if m.has("entered_at") and f == m.entered_at + 150:
				t.check(m.has("hit") and m.hit <= 40, "il treno travolge la rana sui binari (vita %s)" % str(m.get("hit", "intatta")))
				t.check(absf(frog.global_position.z - TRACK_Z) > 2.0, "la rana è sbalzata fuori dal binario")
				var car: Node3D = m.car
				t.check(car.state == 1 and car.global_position.distance_to(m.car_start) > 3.0, "l'auto sui binari diventa rottame e vola via")
				t.check(not track.train.has_method("become_wreck"), "il treno non è un veicolo che può diventare rottame")
			if m.has("entered_at") and track.phase == 0:
				t.check(track.train == null and _lit_lamps() == 0, "passata la coda il treno sparisce e le luci si spengono")
				Lib.place(frog, Vector3(0, 30, 40))
				track._timer = 0.3
				_next(2)
			if f > 900:
				t.check(false, "il primo treno passa entro 15 s")
				t.finish(self)
		2: # sul tetto di un vagone
			if track.train and not m.has("aboard") and track.train._wagons[1].global_position.x > -30.0:
				var wagon: Node3D = track.train._wagons[1]
				var shape: Vector3 = (wagon.get_child(0) as CollisionShape3D).shape.size
				Lib.place(frog, wagon.global_position + Vector3(0, 0.7 + shape.y + 0.05, 0))
				m.aboard = f
				m.x = frog.global_position.x
				m.wagon_x = wagon.global_position.x
			if m.has("aboard") and f == m.aboard + 30:
				var wagon_moved: float = track.train._wagons[1].global_position.x - m.wagon_x
				var frog_moved: float = frog.global_position.x - m.x
				t.check(absf(wagon_moved - frog_moved) < 1.5, "sul tetto la rana viaggia col treno (%.1f m contro %.1f)" % [frog_moved, wagon_moved])
				t.check(frog.health == frog.max_health, "sul tetto non si fa male")
				_next(3)
		3: # il rapido
			var heat: Node = root.get_node("Heat")
			if f == 1:
				# A calore basso, nessun rapido.
				heat.running = false
				heat.value = 0.0
				track.express_chance = 1.0
				var express := 0
				for i in 20:
					track._send_train()
					if track.train.express:
						express += 1
					track.train.free()
				track.train = null
				track.phase = 0
				t.check(express == 0, "a calore basso niente rapidi")
				heat.value = 61.0
				frog.heal_full()
				# Accanto ai binari, a 1,5 m dalla fiancata.
				Lib.place(frog, Vector3(0, 0.1, TRACK_Z + 3.0))
				track._timer = 0.3
			if track.phase == 1 and not m.has("warning_at"):
				m.warning_at = f
				t.check(track.train.express, "dal livello 3 arriva il rapido")
				t.check(track.train.speed > 40.0, "il rapido è molto più veloce (%.0f m/s)" % track.train.speed)
			if m.has("warning_at") and not m.has("entered_at") and track.train and absf(track.train.nose_x()) <= 37.0:
				m.entered_at = f
				m.z = frog.global_position.z
				var lead: float = (m.entered_at - m.warning_at) / 60.0
				t.check(lead > 2.3 and lead < 2.7, "il rapido ha lo stesso avviso di 2,5 s (%.2f)" % lead)
			if m.has("entered_at") and f == m.entered_at + 90:
				var pulled: float = m.z - frog.global_position.z
				t.check(pulled > 0.5 or frog.health < frog.max_health, "la scia risucchia la rana verso i binari (%.1f m, vita %d)" % [pulled, frog.health])
				t.finish(self)
			if f > 900:
				t.check(false, "il rapido passa entro 15 s")
				t.finish(self)
			if f > 1500:
				t.check(false, "il secondo treno passa entro 25 s")
				t.finish(self)
	return false
