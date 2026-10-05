extends SceneTree
## Aeroporto: l'aereo travolge la rana, la fiamma dietro i motori brucia, il
## getto la spinge via e scaglia i rottami, col deltaplano nel getto si sale
## in alto, sull'ala si sta sicuri, un'auto in pista diventa rottame.
## L'atterraggio: scende dal cielo con ombra e luci del punto di contatto, a
## terra sotto di lui si passa e in volo no, frena coi motori al contrario;
## dal livello 3 l'atterraggio di pancia, con l'ala bassa e il fuoco. Sotto le
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


## Un aereo che atterra sulla pista dei test, con contatto in x = 0.
func _landing_plane(belly: bool) -> void:
	if plane:
		plane.queue_free()
	plane = load("res://scripts/airplane.gd").create(1.0, 7.0)
	plane.position.z = LANE.z
	plane.land(0.0, 70.0, belly)
	main.add_child(plane)


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
		8: # l'atterraggio: scende, ombra e luci; a terra sotto di lui si passa
			var heat: Node = root.get_node("Heat")
			if f == 1:
				heat.running = false
				heat.value = 0.0
				var taxiway: Node3D = load("res://scripts/taxiway.gd").new()
				taxiway.difficulty = 4
				taxiway.belly_chance = 1.0
				taxiway.position = LANE + Vector3(0, 0, -60)
				main.add_child(taxiway)
				t.check(taxiway.min_interval == 6.0 and taxiway.max_interval == 10.0, "con la distanza gli aerei arrivano più spesso (%.0f-%.0f s)" % [taxiway.min_interval, taxiway.max_interval])
				var bellies := 0
				for i in 20:
					taxiway._send_plane()
				for child in taxiway.get_children():
					if child.get_script() and child.get_script().resource_path.get_file() == "airplane.gd":
						bellies += 1 if child.belly else 0
				t.check(bellies == 0, "a calore basso nessun aereo atterra di pancia")
				taxiway.queue_free()
				_landing_plane(false)
				frog.heal_full()
				Lib.place(frog, LANE + Vector3(-30, 0.1, 0))
				m.alt = plane.altitude()
				m.descending = true
			if f == 2:
				t.check(plane.is_flying() and plane.altitude() > 10.0, "l'aereo arriva dal cielo (quota %.0f m)" % plane.altitude())
				t.check(plane._shadow != null and plane._marker != null, "a terra la sua ombra, e le luci nel punto di contatto")
			if plane.is_flying():
				m.descending = m.descending and plane.altitude() <= m.alt
				m.alt = plane.altitude()
			if plane.position.x > -10.0 and not m.has("over"):
				m.over = true
				t.check(m.descending, "scende lungo la rampa")
				t.check(frog.health == frog.max_health, "a terra, sotto l'aereo in volo, si passa")
			if not plane.is_flying() and not m.has("down"):
				m.down = f
				t.check(absf(plane.position.y) < 0.01 and absf(plane.position.x) < 0.5, "tocca terra nel punto delle luci (x %.1f)" % plane.position.x)
				t.check(plane._marker == null and plane._shadow == null, "toccata terra, ombra e luci spariscono")
				# Davanti al motore destro, mentre frena coi motori al contrario.
				Lib.place(frog, plane.to_global(Vector3(6, 0, -11)) * Vector3(1, 0, 1) + Vector3(0, LANE.y + 0.1, 0))
				m.x = frog.global_position.x
			if m.has("down"):
				var g: int = f - m.down
				if g == 20:
					t.check(frog.global_position.x - m.x > 0.8, "i motori al contrario spingono in avanti (%.1f m)" % (frog.global_position.x - m.x))
					Lib.place(frog, LANE + Vector3(0, 30, 40))
				if g == 300:
					t.check(plane.phase == 2 and is_equal_approx(plane.speed, plane.taxi_speed), "poi frena fino al rullaggio (%.0f m/s)" % plane.speed)
					_next(9)
			if f > 1200:
				t.check(false, "l'aereo atterra entro 20 s")
				t.finish(self)
		9: # chi vola sulla sua rotta ci finisce contro
			if f == 1:
				_landing_plane(false)
				frog.heal_full()
				m.alt = 20.0 * 0.2 + 2.6
			if plane.is_flying() and plane.position.x < -15.0:
				# Sospesa in aria, dove l'aereo passerà a 4 m di quota (senza
				# Lib.place, che rimetterebbe la vita piena).
				frog.global_position = LANE + Vector3(-20, m.alt, 0)
				frog.velocity = Vector3.ZERO
			if plane.position.x > -10.0 and not m.has("checked"):
				m.checked = true
				t.check(frog.health < frog.max_health, "chi vola sulla rotta dell'aereo ci finisce contro (vita %d)" % frog.health)
				_next(10)
			if f > 900:
				t.check(false, "l'aereo passa entro 15 s")
				t.finish(self)
		10: # il gradino: dal livello 3 l'atterraggio di pancia
			var heat: Node = root.get_node("Heat")
			if f == 1:
				heat.value = 61.0
				var taxiway: Node3D = load("res://scripts/taxiway.gd").new()
				taxiway.belly_chance = 1.0
				taxiway.position = LANE + Vector3(0, 0, -60)
				main.add_child(taxiway)
				var bellies := 0
				var planes := 0
				for i in 6:
					taxiway._send_plane()
				for child in taxiway.get_children():
					if child.get_script() and child.get_script().resource_path.get_file() == "airplane.gd":
						planes += 1
						bellies += 1 if child.belly else 0
				t.check(bellies == planes, "dal livello 3 gli aerei atterrano di pancia (%d su %d)" % [bellies, planes])
				taxiway.queue_free()
				_landing_plane(true)
				Lib.place(frog, LANE + Vector3(0, 30, 40))
				frog.heal_full()
			if not plane.is_flying() and not m.has("down"):
				m.down = f
				t.check(plane.position.y < -0.5, "di pancia scivola basso (%.1f m)" % plane.position.y)
			if m.has("down"):
				var g: int = f - m.down
				if g == 1:
					# Sotto l'ala, davanti all'aereo: nella scivolata non si passa.
					Lib.place(frog, plane.to_global(Vector3(10, 0, -14)) * Vector3(1, 0, 1) + Vector3(0, LANE.y + 0.1, 0))
				if g == 90:
					t.check(frog.health < frog.max_health, "sotto le ali non si passa più (vita %d)" % frog.health)
					var patches: Array = Lib.by_script(main, "fire_patch.gd")
					t.check(not patches.is_empty(), "lascia chiazze di fuoco (%d)" % patches.size())
					frog.heal_full()
					# La chiazza più nuova: le vecchie si stanno spegnendo.
					patches.sort_custom(func(a, b): return a._left > b._left)
					m.patch = patches[0]
				if g > 90 and g < 120 and is_instance_valid(m.patch):
					frog.global_position = m.patch.global_position + Vector3(0, 0.1, 0)
					frog.velocity = Vector3.ZERO
				if g == 120:
					t.check(frog.health < frog.max_health - 10, "le chiazze di fuoco bruciano (vita %d)" % frog.health)
					t.finish(self)
			if f > 1200:
				t.check(false, "l'aereo atterra di pancia entro 20 s")
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
