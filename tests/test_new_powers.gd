extends SceneTree
## Power-up nuovi: lingua-rampino (tira la rana su un'auto, tira un rottame
## verso la rana, a vuoto non fa niente), schianto sismico, molle-trampolino,
## montante, guantone a molla, ala a reazione, pelle impermeabile. Fusioni:
## Napalm e Terremoto (offerte di sicuro, occupano due slot, si perdono
## scegliendo un'altra carta per uno dei loro slot).

const Lib := preload("res://tests/lib.gd")
const BASE := Vector3(0, 0, 320)

var t := Lib.new()
var main: Node
var frog: Node3D
var upgrades: Node
var heat: Node
var cars: Array = []
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")
	heat = root.get_node("Heat")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


func _forward() -> Vector3:
	return -frog.camera_rig.flat_basis().z


## Un'auto ferma (la sua corsia non la muove più) nel punto dato, a terra.
func _park(car: Node3D, at: Vector3) -> Node3D:
	car.global_position = at + Vector3(0, car.size.y / 2.0, 0)
	return car


func _tap(action: String) -> void:
	Input.action_press(action)
	m["release_" + action] = frame + 1


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	for key in m.keys():
		if String(key).begins_with("release_") and m[key] == frame:
			Input.action_release(String(key).trim_prefix("release_"))
	if paused:
		upgrades.choose(0)
	match step:
		0:
			if frame == 5:
				main.get_node("Course").den_reached.disconnect(main._on_den_reached)
				heat.running = false
				Lib.test_ground(main)
				cars = Lib.cars(main).filter(func(c): return c.state == 0 and c.model_type in ["compact", "sedan"]).slice(0, 8)
				for car in cars:
					car.get_parent().set_physics_process(false)
					car.set_physics_process(false)
					car.global_position = Vector3(0, -50, 0)
				_next(1)
		1: # la lingua tira la rana sul tetto di un'auto
			if f == 1:
				upgrades.apply("tongue")
				Lib.place(frog, BASE + Vector3(0, 0.1, 0))
				m.car = _park(cars[0], BASE + _forward() * 8.0)
			if f == 3:
				t.check(frog.tongue_power.enabled, "la carta Lingua-rampino sblocca la lingua")
				m.heat = heat.value
				_tap("tongue")
			if f == 60:
				var flat: Vector3 = frog.global_position - m.car.global_position
				flat.y = 0.0
				t.check(flat.length() < 1.6 and frog.global_position.y > m.car.global_position.y, "la lingua tira la rana sul tetto dell'auto (a %.1f m)" % flat.length())
				t.check(heat.value > m.heat, "la lingua scalda")
				_next(2)
		2: # un rottame viene tirato verso la rana
			if f == 1:
				Lib.place(frog, BASE + Vector3(0, 0.1, 0))
				m.wreck = _park(cars[1], BASE + _forward() * 9.0 + Vector3(4, 0, 0))
				m.wreck.become_wreck()
				m.wreck.linear_velocity = Vector3.ZERO
			if f == 80:
				m.before = m.wreck.global_position.distance_to(frog.global_position)
				frog.tongue_power.cooldown_left = 0.0
				_tap("tongue")
			if f == 120:
				var after: float = m.wreck.global_position.distance_to(frog.global_position)
				t.check(after < m.before - 3.0, "la lingua tira un rottame verso la rana (da %.1f a %.1f m)" % [m.before, after])
				# A vuoto: niente da agganciare.
				Lib.place(frog, BASE + Vector3(-45, 0.1, 40))
				frog.tongue_power.cooldown_left = 0.0
			if f == 125:
				t.check(not frog.tongue_power.use() and not frog.tongue_power.pulling, "senza niente davanti la lingua scatta a vuoto")
				_next(3)
		3: # schianto sismico
			if f == 1:
				upgrades.apply("slam")
				m.a = _park(cars[2], BASE + Vector3(17, 0, 0))
				m.b = _park(cars[3], BASE + Vector3(23, 0, 0))
				Lib.place(frog, BASE + Vector3(20, 6, 0))
				m.heat = heat.value
				m.vy = 0.0
			if f < 6:
				frog.global_position = BASE + Vector3(20, 6, 0)
				frog.velocity = Vector3.ZERO
			if f == 6:
				t.check(frog.slam_power.can_start(), "in alto lo schianto si può fare")
				_tap("slam")
			# Solo da rottami: un'auto ferma appena spostata ha una velocità finta.
			for car in [m.a, m.b]:
				if car.state == 1:
					m.vy = maxf(m.vy, car.linear_velocity.y)
			if f == 70:
				t.check(m.a.state == 1 and m.b.state == 1, "lo schianto ribalta le auto intorno")
				t.check(m.vy > 3.0, "e le fa volare (%.1f m/s in alto)" % m.vy)
				t.check(heat.value >= m.heat + 2.0, "lo schianto scalda")
				t.check(frog.health == frog.max_health, "lo schianto non fa male alla rana")
				_next(4)
		4: # molle-trampolino
			if f == 1:
				upgrades.apply("trampoline")
				t.check(not frog.slam_power.enabled and frog.trampoline, "le molle-trampolino prendono il posto dello schianto")
				m.car = _park(cars[4], BASE + Vector3(-20, 0, 0))
				Lib.place(frog, m.car.global_position + Vector3(0, 3, 0))
				m.top = m.car.global_position.y + m.car.size.y / 2.0
				m.landed = false
				m.bounce = 0.0
			if f > 1:
				if frog.global_position.y < m.top + 0.3:
					m.landed = true
				elif m.landed:
					m.bounce = maxf(m.bounce, frog.global_position.y - m.top)
			if f == 90:
				t.check(m.bounce > 1.2, "sul tetto di un'auto la rana rimbalza da sola (%.1f m)" % m.bounce)
				_next(5)
		5: # montante e guantone a molla
			if f == 1:
				upgrades.apply("uppercut")
				Lib.place(frog, BASE + Vector3(-30, 0.1, 20))
				m.car = _park(cars[5], BASE + Vector3(-30, 0, 20) + _forward() * 1.5)
			if f == 3:
				frog.punch()
			if f == 8:
				var v: Vector3 = m.car.linear_velocity
				t.check(m.car.state == 1 and v.y > Vector2(v.x, v.z).length() * 0.8, "il montante solleva l'auto (%.1f in alto, %.1f di lato)" % [v.y, Vector2(v.x, v.z).length()])
				upgrades.apply("long_glove")
				Lib.place(frog, BASE + Vector3(30, 0.1, 20))
				m.far = _park(cars[6], BASE + Vector3(30, 0, 20) + _forward() * 3.6)
				frog.punch_power.cooldown_left = 0.0
			if f == 10:
				frog.punch()
			if f == 14:
				t.check(m.far.state == 1, "il guantone a molla arriva a 3,6 m")
				_next(6)
		6: # ala a reazione
			if f == 1:
				upgrades.apply("jet_wing")
				# Il pugno di prima ha fatto scattare il fermo-immagine, che dura in
				# tempo reale: nei test (più veloci del reale) durerebbe molti passi.
				main._hitstop_until = 0
				main._slowmo_until = 0
			if f < 8:
				Lib.place(frog, BASE + Vector3(0, 8, 40))
			if f == 8:
				Input.action_press("jump")
				frog.glider_power.gliding = true
				m.heat = heat.value
			if f == 40:
				var speed: float = Vector2(frog.velocity.x, frog.velocity.z).length()
				t.check(speed > 14.0, "con l'ala a reazione il deltaplano va veloce (%.1f m/s)" % speed)
				t.check(heat.value > m.heat + 0.5, "e finché vola il calore sale")
				Input.action_release("jump")
				_next(7)
		7: # pelle impermeabile
			if f == 1:
				upgrades.apply("waterproof")
				var river: Node3D = Lib.by_script(main, "river.gd")[0]
				Lib.place(frog, Vector3(0, river.surface_y() - 0.3, river.global_position.z))
			if f == 90:
				t.check(frog.is_swimming() and frog.health == frog.max_health, "con la pelle impermeabile l'acqua non toglie vita")
				_next(8)
		8: # fusioni
			if f == 1:
				upgrades.apply("explosive_gloves")
				upgrades.apply("thermals")
				var offer: Array = upgrades.make_offer()
				t.check(offer[0] == "napalm", "con guantoni esplosivi e correnti calde la tana offre il Napalm")
				upgrades.apply("napalm")
				t.check(upgrades.slots.gloves == "napalm" and upgrades.slots.wing == "napalm", "il Napalm occupa guantoni e ala")
				t.check(frog.punch_power.explosive and frog.glider_power.thermals, "e tiene gli effetti di tutti e due")
				var smoke: float = load("res://scripts/car.gd").smoke_seconds
				t.check(smoke == 15.0, "col Napalm i rottami fumano più a lungo (%.0f s)" % smoke)
				var parts_offered := false
				for i in 30:
					var again: Array = upgrades.make_offer()
					if again.has("explosive_gloves") or again.has("thermals") or again.has("napalm"):
						parts_offered = true
				t.check(not parts_offered, "col Napalm le sue parti non vengono più offerte")
				upgrades.apply("uppercut")
				smoke = load("res://scripts/car.gd").smoke_seconds
				t.check(upgrades.slots.wing == "" and not frog.punch_power.explosive and not frog.glider_power.thermals and smoke == 6.0, "un'altra carta per i guantoni toglie tutta la fusione")
				upgrades.apply("slam")
				offer = upgrades.make_offer()
				t.check(offer[0] == "earthquake", "con montante e schianto la tana offre il Terremoto")
				upgrades.apply("earthquake")
				t.check(frog.slam_power.enabled and frog.slam_power.radius == 10.0, "col Terremoto l'onda arriva a 10 m")
				t.finish(self)
	return false
