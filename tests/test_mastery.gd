extends SceneTree
## Maestria delle carte: le prove avanzano usando la carta, e i miglioramenti
## speciali attivati cambiano come si usa. Guantoni esplosivi (reazione a
## catena, razzo), montante (meteora, doppio montante), guantone a molla
## (perforante, tira e molla).

const Lib := preload("res://tests/lib.gd")
const BASE := Vector3(0, 0, 320)

var t := Lib.new()
var main: Node
var frog: Node3D
var upgrades: Node
var progress: GDScript
var cars: Array = []
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")
	progress = load("res://scripts/progress.gd")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}
	# Il fermo-immagine dura in tempo reale: nei test durerebbe molti passi.
	main._hitstop_until = 0
	main._slowmo_until = 0


func _forward() -> Vector3:
	return -frog.camera_rig.flat_basis().z


func _park(car: Node3D, at: Vector3) -> Node3D:
	car.global_position = at + Vector3(0, car.size.y / 2.0, 0)
	return car


## Equipaggia la carta coi miglioramenti speciali dati.
func _equip(card: String, first: bool, second: bool) -> void:
	progress.card_active["%s:0" % card] = first
	progress.card_active["%s:1" % card] = second
	upgrades.apply(card)


func _trial(card: String, index: int) -> float:
	return progress.run_trials.get("%s:%d" % [card, index], 0.0)


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		upgrades.choose(0)
	match step:
		0:
			if frame == 5:
				main.get_node("Course").den_reached.disconnect(main._on_den_reached)
				root.get_node("Heat").running = false
				Lib.test_ground(main)
				cars = Lib.cars(main).filter(func(c): return c.state == 0 and c.model_type in ["compact", "sedan"]).slice(0, 12)
				for car in cars:
					car.get_parent().set_physics_process(false)
					car.global_position = Vector3(0, -50, 0)
				_next(1)
		1: # guantoni esplosivi: prova, reazione a catena
			if f == 1:
				_equip("explosive_gloves", true, false)
				t.check(main.get_node("Course") != null and load("res://scripts/car.gd").chain_explosions, "la reazione a catena attivata vale quando si equipaggia la carta")
				Lib.place(frog, BASE + Vector3(0, 0.1, 40))
				m.bomb = _park(cars[0], BASE + Vector3(0, 0, 0))
				m.a = _park(cars[1], BASE + Vector3(4.5, 0, 0))
				m.b = _park(cars[2], BASE + Vector3(9.5, 0, 0))
				for car in [m.bomb, m.a, m.b]:
					car.set_physics_process(true)
			if f == 3:
				m.bomb.become_wreck()
				m.bomb.linear_velocity = Vector3.ZERO
				m.bomb.explode()
			if f == 60:
				t.check(m.a.state == 1, "l'esplosione distrugge l'auto vicina")
				t.check(m.a._chain_depth == 1 and m.a.exploded, "reazione a catena: l'auto distrutta esplode a sua volta")
				t.check(_trial("explosive_gloves", 0) >= 1.0, "la prova dei guantoni esplosivi conta le auto esplose (%d)" % _trial("explosive_gloves", 0))
				_next(2)
		2: # razzo
			if f == 1:
				_equip("explosive_gloves", false, true)
				Lib.place(frog, BASE + Vector3(-20, 0.1, 0))
				m.bomb = _park(cars[3], BASE + Vector3(-22.5, 0, 0))
				m.bomb.set_physics_process(true)
			if f == 3:
				m.bomb.become_wreck()
				m.bomb.linear_velocity = Vector3.ZERO
				m.bomb.explode()
				m.vy = frog.velocity.y
			if f == 4:
				t.check(frog.health == frog.max_health and frog.velocity.y > 8.0, "razzo: l'esplosione vicina non ferisce, lancia in alto (%.1f m/s)" % frog.velocity.y)
				_next(3)
		3: # montante: prova, meteora
			if f == 1:
				upgrades.apply("explosive_gloves") # e poi lo si toglie col montante
				_equip("uppercut", true, false)
				Lib.place(frog, BASE + Vector3(20, 0.1, 30))
				m.car = _park(cars[4], BASE + Vector3(20, 0, 30) + _forward() * 1.4)
				m.car.set_physics_process(true)
				m.before = _trial("uppercut", 0)
			if f == 3:
				frog.punch()
			if f == 5:
				t.check(_trial("uppercut", 0) == m.before + 1, "la prova del montante conta le auto lanciate")
				t.check(m.car.has_meta("meteor"), "meteora: l'auto lanciata è segnata")
				# La meteora a terra: un'auto vicina al punto di caduta.
				var meteor: Node3D = _park(cars[5], BASE + Vector3(-30, 0, 30))
				meteor.set_physics_process(true)
				meteor.become_wreck()
				meteor.set_meta("meteor", true)
				m.near = _park(cars[6], BASE + Vector3(-27, 0, 30))
				meteor._wreck_age = 1.0
				meteor._on_wreck_body_entered(main.get_child(main.get_child_count() - 1))
			if f == 8:
				t.check(m.near.state == 1, "meteora: ricadendo, l'auto ribalta quelle vicine")
				_next(4)
		4: # doppio montante
			if f == 1:
				_equip("uppercut", false, true)
				Lib.place(frog, BASE + Vector3(30, 0.1, -30))
				m.high = _park(cars[7], BASE + Vector3(30, 3.0, -30) + _forward() * 1.3)
			if f == 3:
				frog.punch_power.cooldown_left = 0.0
				frog.punch()
			if f == 5:
				t.check(m.high.state == 1, "doppio montante: il pugno colpisce anche in alto")
				_next(5)
		5: # guantone a molla: perforante e prove
			if f == 1:
				_equip("long_glove", true, false)
				Lib.place(frog, BASE + Vector3(-30, 0.1, -30))
				m.near = _park(cars[8], BASE + Vector3(-30, 0, -30) + _forward() * 1.6)
				m.far = _park(cars[9], BASE + Vector3(-30, 0, -30) + _forward() * 3.8)
			if f == 3:
				frog.punch_power.cooldown_left = 0.0
				frog.punch()
			if f == 5:
				t.check(m.near.state == 1 and m.far.state == 1, "perforante: il pugno colpisce tutte le auto sulla linea")
				t.check(_trial("long_glove", 1) >= 2.0 and _trial("long_glove", 0) >= 1.0, "le prove del guantone a molla contano i colpi lontani e le auto per pugno")
				_next(6)
		6: # tira e molla
			if f == 1:
				_equip("long_glove", false, true)
				Lib.place(frog, BASE + Vector3(0, 0.1, -40))
				m.car = _park(cars[10], BASE + Vector3(0, 0, -40) + _forward() * 3.6)
				m.car.set_physics_process(true)
				m.d0 = m.car.global_position.distance_to(frog.global_position)
			if f == 3:
				frog.punch_power.cooldown_left = 0.0
				frog.punch()
				main._hitstop_until = 0
			if f == 10:
				m.d1 = m.car.global_position.distance_to(frog.global_position)
				t.check(m.d1 < m.d0, "tira e molla: prima il guantone tira l'auto verso la rana (%.1f -> %.1f m)" % [m.d0, m.d1])
			if f == 60:
				var speed: float = m.car.linear_velocity.length()
				var d2: float = m.car.global_position.distance_to(frog.global_position)
				t.check(d2 > m.d1 + 2.0, "poi la scaglia via (%.1f m, %.1f m/s)" % [d2, speed])
				t.finish(self)
	return false
