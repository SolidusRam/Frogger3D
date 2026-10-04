extends SceneTree
## Aeroporto: l'aereo travolge la rana, la fiamma dietro i motori brucia, il
## getto la spinge via e scaglia i rottami, col deltaplano nel getto si sale
## in alto, sull'ala si sta sicuri, un'auto in pista diventa rottame. Sotto le
## ali corrono le strade di servizio con i trenini bagagli: il getto porta via
## il carico e lo scaglia, un bagaglio che arriva veloce fa male, il pugno lo
## fa volare.

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
				var roads: Array = Lib.by_script(taxiway, "service_road.gd")
				var beside_engines := roads.size() == 2 and roads.all(func(r): return absf(absf(r.position.z) - 9.0) < 0.01)
				t.check(beside_engines, "sotto le ali, accanto ai motori, corrono due strade di servizio (%d)" % roads.size())
				t.check(Lib.by_script(taxiway, "car.gd").is_empty(), "sulle strade di servizio non passano auto")
				var loaded := roads.all(func(r): return not r.trains().is_empty() and not r.trains()[0].cargo().is_empty())
				t.check(loaded, "ogni strada ha già un trenino carico di bagagli")
				taxiway.queue_free()
				_next(5)
		5: # il getto porta via i bagagli dai carrelli e li scaglia all'indietro
			if f == 1:
				_new_plane(-10.0)
			if f == 3:
				frog.heal_full()
				Lib.place(frog, LANE + Vector3(0, 0.1, 20))
				# Un trenino fermo sotto l'ala destra, con i carrelli nel getto.
				var at: Vector3 = plane.to_global(Vector3(9, 0, 8))
				var train: Node3D = load("res://scripts/baggage_train.gd").new()
				train.speed = 0.0
				train.home = main
				train.position = Vector3(0, LANE.y, at.z)
				train.build(3)
				train.place_nose(at.x)
				main.add_child(train)
				m.train = train
				m.cargo = train.cargo().size()
				m.x = at.x
			if f == 63:
				var left: int = m.train.cargo().size()
				t.check(left < m.cargo, "il getto porta via i bagagli dai carrelli (%d su %d)" % [m.cargo - left, m.cargo])
				var thrown := Lib.by_script(main, "baggage.gd").filter(func(b): return not b.loaded and m.x - b.global_position.x > 15.0)
				t.check(not thrown.is_empty(), "il getto scaglia i bagagli all'indietro (%d oltre 15 m)" % thrown.size())
				m.train.queue_free()
				plane.queue_free()
				plane = null
				_next(6)
		6: # un bagaglio fa male solo se arriva addosso veloce
			if f == 1:
				frog.heal_full()
				Lib.place(frog, LANE + Vector3(0, 0.1, 0))
				m.fast = _loose_baggage(LANE + Vector3(-4, 0.6, 0), Vector3(18, 0, 0))
			if f == 30:
				t.check(frog.health == frog.max_health - 10, "un bagaglio scagliato addosso fa male (vita %d)" % frog.health)
				frog.heal_full()
				Lib.place(frog, LANE + Vector3(0, 0.1, 10))
				m.slow = _loose_baggage(LANE + Vector3(-1.2, 0.4, 10), Vector3(3, 0, 0))
			if f == 70:
				t.check(frog.health == frog.max_health, "un bagaglio lento non fa male")
				_next(7)
		7: # il pugno fa volare un bagaglio dal carrello
			if f == 1:
				Lib.place(frog, LANE + Vector3(0, 0.1, 30))
				var train: Node3D = load("res://scripts/baggage_train.gd").new()
				train.speed = 0.0
				train.home = main
				# Davanti alla rana (la telecamera guarda verso -Z), di traverso.
				train.position = LANE + Vector3(0, 0, 28.6)
				train.build(1)
				# Il centro del primo carrello è 4,75 m dietro il muso: davanti alla rana.
				train.place_nose(4.75)
				main.add_child(train)
				m.train = train
			if f == 5:
				m.bags = m.train.cargo()
				frog.punch()
			if f == 35:
				var flying: Array = m.bags.filter(func(b): return not b.loaded and b.global_position.z < LANE.z + 26.0)
				t.check(m.train.cargo().size() < m.bags.size(), "il pugno porta via i bagagli dal carrello (%d su %d)" % [m.bags.size() - m.train.cargo().size(), m.bags.size()])
				t.check(not flying.is_empty(), "il pugno li fa volare lontano (%d oltre 2,5 m)" % flying.size())
				_next(8)
		8: # il gradino: dal livello 3 metà degli aerei decolla
			var heat: Node = root.get_node("Heat")
			if f == 1:
				heat.running = false
				heat.value = 0.0
				var taxiway: Node3D = load("res://scripts/taxiway.gd").new()
				taxiway.difficulty = 4
				taxiway.takeoff_chance = 1.0
				taxiway.position = LANE + Vector3(0, 0, -60)
				main.add_child(taxiway)
				t.check(taxiway.min_interval == 6.0 and taxiway.max_interval == 10.0, "con la distanza gli aerei arrivano più spesso (%.0f-%.0f s)" % [taxiway.min_interval, taxiway.max_interval])
				var takeoffs := 0
				for i in 20:
					taxiway._send_plane(-200.0)
				for child in taxiway.get_children():
					if child.get_script() and child.get_script().resource_path.get_file() == "airplane.gd" and child.takeoff:
						takeoffs += 1
				t.check(takeoffs == 0, "a calore basso nessun aereo decolla")
				taxiway.queue_free()
				heat.value = 61.0
				frog.heal_full()
				if plane:
					plane.queue_free()
				plane = load("res://scripts/airplane.gd").create(1.0, 7.0)
				plane.takeoff = true
				plane.hold_x = 0.0
				plane.position = LANE + Vector3(-10, 0, 0)
				main.add_child(plane)
				Lib.place(frog, LANE + Vector3(0, 30, 30))
			if plane.is_spooling() and not m.has("spool_at"):
				m.spool_at = f
				m.hold = plane.global_position.x
			if m.has("spool_at"):
				var g: int = f - m.spool_at
				if g == 90:
					# A 30 m dietro il motore: oltre il getto normale (22 m).
					Lib.place(frog, plane.to_global(Vector3(6, 0, 30)) + Vector3(0, 0.1, 0))
					m.x = frog.global_position.x
				if g == 115:
					t.check(absf(plane.global_position.x - m.hold) < 0.01, "per decollare l'aereo si ferma sul raccordo")
					t.check(plane.power > 1.8, "fermo, i motori salgono di giri (%.2f)" % plane.power)
					var pushed: float = m.x - frog.global_position.x
					t.check(pushed > 1.5, "il getto del decollo arriva al doppio della distanza (%.1f m a 30 m)" % pushed)
					Lib.place(frog, LANE + Vector3(0, 30, 30))
				if g == 300:
					t.check(plane.is_rolling() and plane.speed > 18.0, "poi corre lungo il raccordo (%.0f m/s)" % plane.speed)
					t.finish(self)
			if f > 900:
				t.check(false, "l'aereo si ferma per decollare entro 15 s")
				t.finish(self)
	return false


func _loose_baggage(at: Vector3, velocity: Vector3) -> Node3D:
	var baggage: Node3D = load("res://scripts/baggage.gd").new()
	baggage.home = main
	main.add_child(baggage)
	baggage.global_position = at
	baggage.release()
	baggage.linear_velocity = velocity
	baggage.gravity_scale = 0.0
	return baggage
