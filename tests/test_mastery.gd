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
var _used := 0
var frame := 0
var start := 0
var step := 0
var m := {}
## Il fiume svuotato per tuffo e ondata (m si azzera a ogni prova).
var _river: Node3D


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


## Un'auto mai usata, ferma in marcia nel punto dato.
func _fresh(at: Vector3) -> Node3D:
	_used += 1
	var car: Node3D = cars[_used - 1]
	# Ferma: in marcia, ma a velocità zero.
	car.cruise_speed = 0.0
	car._speed = 0.0
	return _park(car, at)


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
				cars = Lib.cars(main).filter(func(c): return c.state == 0 and c.model_type in ["compact", "sedan"]).slice(0, 24)
				for car in cars:
					car.get_parent().set_physics_process(false)
					# Fuori dai blocchi del percorso, che si cancellano quando la
					# rana va lontano.
					car.reparent(main)
					car.global_position = Vector3(0, -50, 0)
				_next(1)
		1: # guantoni esplosivi: prova, reazione a catena
			if f == 1:
				_equip("explosive_gloves", true, false)
				t.check(main.get_node("Course") != null and load("res://scripts/car.gd").chain_explosions, "la reazione a catena attivata vale quando si equipaggia la carta")
				Lib.place(frog, BASE + Vector3(0, 0.1, 40))
				m.bomb = _fresh(BASE + Vector3(0, 0, 0))
				m.a = _fresh(BASE + Vector3(4.5, 0, 0))
				m.b = _fresh(BASE + Vector3(9.5, 0, 0))
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
				m.bomb = _fresh(BASE + Vector3(-22.5, 0, 0))
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
				m.car = _fresh(BASE + Vector3(20, 0, 30) + _forward() * 1.4)
				m.car.set_physics_process(true)
				m.before = _trial("uppercut", 0)
			if f == 3:
				frog.punch()
			if f == 5:
				t.check(_trial("uppercut", 0) == m.before + 1, "la prova del montante conta le auto lanciate")
				t.check(m.car.has_meta("meteor"), "meteora: l'auto lanciata è segnata")
				# La meteora a terra: un'auto vicina al punto di caduta.
				var meteor: Node3D = _fresh(BASE + Vector3(-30, 0, 30))
				meteor.set_physics_process(true)
				meteor.become_wreck()
				meteor.set_meta("meteor", true)
				m.near = _fresh(BASE + Vector3(-27, 0, 30))
				meteor._wreck_age = 1.0
				meteor._on_wreck_body_entered(main.get_child(main.get_child_count() - 1))
			if f == 8:
				t.check(m.near.state == 1, "meteora: ricadendo, l'auto ribalta quelle vicine")
				_next(4)
		4: # doppio montante
			if f == 1:
				_equip("uppercut", false, true)
				Lib.place(frog, BASE + Vector3(30, 0.1, -30))
				m.high = _fresh(BASE + Vector3(30, 3.0, -30) + _forward() * 1.3)
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
				m.near = _fresh(BASE + Vector3(-30, 0, -30) + _forward() * 1.6)
				m.far = _fresh(BASE + Vector3(-30, 0, -30) + _forward() * 3.8)
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
				m.car = _fresh(BASE + Vector3(0, 0, -40) + _forward() * 3.6)
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
				_next(7)
		7: # molle-trampolino: crescendo e prove
			if f == 1:
				_equip("trampoline", true, false)
				m.car = _fresh(BASE + Vector3(0, 0, 0))
				m.top = m.car.global_position.y + m.car.size.y / 2.0
				Lib.place(frog, m.car.global_position + Vector3(0, 2.5, 0))
				m.apexes = []
				m.rising = false
			if f > 1:
				# Le cime dei rimbalzi; la rana resta sopra l'auto.
				frog.global_position.x = m.car.global_position.x
				frog.global_position.z = m.car.global_position.z
				if frog.velocity.y > 0.0:
					m.rising = true
				elif m.rising:
					m.rising = false
					m.apexes.append(frog.global_position.y - m.top)
			if f == 240:
				var apexes: Array = m.apexes
				t.check(apexes.size() >= 3 and apexes[2] > apexes[0] + 0.5, "crescendo: ogni rimbalzo di fila è più alto (%s)" % str(apexes.slice(0, 3).map(func(a): return snappedf(a, 0.1))))
				t.check(_trial("trampoline", 0) >= 3.0 and _trial("trampoline", 1) >= 3.0, "le prove del trampolino contano i rimbalzi e quelli di fila")
				Lib.place(frog, BASE + Vector3(0, 0.1, 30))
				_next(8)
		8: # schianto: doppia onda e dal cielo
			if f == 1:
				_equip("slam", true, false)
				m.a = _fresh(BASE + Vector3(4.0, 0, 30))
				# A 10,5 m: fuori dalla prima onda (6 m, misurata al bordo dell'auto), dentro la seconda.
				m.b = _fresh(BASE + Vector3(-10.5, 0, 30))
			if f < 6:
				Lib.place(frog, BASE + Vector3(0, 6, 30))
			if f == 6:
				frog.slam_power.cooldown_left = 0.0
				Input.action_press("slam")
			if f == 8:
				Input.action_release("slam")
			if f > 6 and not m.has("landed") and frog.is_on_floor():
				m.landed = f
				m.b_at_landing = m.b.state
				main._hitstop_until = 0
			if m.has("landed") and f == m.landed + 45:
				t.check(m.a.state == 1 and m.b_at_landing == 0 and m.b.state == 1, "doppia onda: mezzo secondo dopo, una seconda onda più larga")
				t.check(_trial("slam", 0) >= 2.0, "la prova dello schianto conta le auto ribaltate")
				_next(9)
		9: # dal cielo
			if f == 1:
				_equip("slam", false, true)
				m.far = _fresh(BASE + Vector3(10.0, 0, -20))
			if f < 6:
				Lib.place(frog, BASE + Vector3(0, 14, -20))
			if f == 6:
				frog.slam_power.cooldown_left = 0.0
				Input.action_press("slam")
			if f == 8:
				Input.action_release("slam")
			if f == 70:
				t.check(m.far.state == 1, "dal cielo: cadendo da 14 m l'onda arriva a 10 m")
				_next(10)
		10: # correnti calde: fenice
			if f == 1:
				_equip("thermals", true, false)
				m.wreck = _fresh(BASE + Vector3(-30, 0, 0))
				m.wreck.set_physics_process(true)
				m.wreck.become_wreck()
				m.wreck.linear_velocity = Vector3.ZERO
			if f < 10:
				Lib.place(frog, m.wreck.global_position + Vector3(0, 4, 0))
				frog.health = 50
			if f == 10:
				Input.action_press("jump")
				frog.glider_power.gliding = true
			if f == 80:
				t.check(frog.health > 55, "fenice: nel fumo la rana recupera vita (%d)" % frog.health)
				t.check(_trial("thermals", 0) > 0.0 and _trial("thermals", 1) > 0.5, "le prove delle correnti calde contano la salita e i secondi nel fumo")
				Input.action_release("jump")
				_next(11)
		11: # camino: il fumo davanti all'incendio
			var fire: Node3D = main.get_node("Wildfire")
			if f == 1:
				_equip("thermals", false, true)
			if f < 10:
				Lib.place(frog, Vector3(20, 6, fire.front_z - 10.0))
			if f == 10:
				Input.action_press("jump")
				frog.glider_power.gliding = true
				m.y = frog.global_position.y
			if f == 50:
				t.check(frog.global_position.y > m.y + 0.5, "camino: davanti all'incendio il fumo solleva (%+.1f m)" % (frog.global_position.y - m.y))
				Input.action_release("jump")
				_next(12)
		12: # ala a reazione: postbruciatore e raffreddata
			if f == 1:
				_equip("jet_wing", true, false)
				m.car = _fresh(BASE + Vector3(30, 0, 0))
			if f < 10:
				Lib.place(frog, m.car.global_position + Vector3(0, 4, 0))
			if f == 10:
				Input.action_press("jump")
				frog.glider_power.gliding = true
			if f == 20:
				t.check(m.car.state == 1, "postbruciatore: l'auto sotto l'ala diventa rottame")
				t.check(_trial("jet_wing", 0) > 0.0, "la prova dell'ala a reazione conta i metri volati")
				Input.action_release("jump")
				_next(13)
		13: # raffreddata
			if f == 1:
				_equip("jet_wing", false, true)
			if f < 10:
				Lib.place(frog, BASE + Vector3(-40, 8, -40))
			if f == 10:
				Input.action_press("jump")
				frog.glider_power.gliding = true
				m.heat = root.get_node("Heat").value
			if f == 40:
				t.check(frog.glider_power.gliding and root.get_node("Heat").value == m.heat, "raffreddata: in volo il calore non sale")
				Input.action_release("jump")
				_next(14)
		14: # pelle impermeabile: tuffo e prove
			if f == 1:
				_river = Lib.by_script(main, "river.gd")[0]
			var river: Node3D = _river
			if f == 1:
				_equip("waterproof", true, false)
				# Le correnti del fiume vuote: niente tronchi né coccodrilli addosso.
				for lane in Lib.by_script(river, "river_lane.gd"):
					lane.set_physics_process(false)
					for child in lane.get_children():
						child.queue_free()
				Lib.place(frog, Vector3(0, river.surface_y() - 0.3, river.global_position.z))
			if f == 20:
				Input.action_press("slam")
			if f == 80:
				t.check(frog.submerged and frog.global_position.y < river.surface_y() - 1.5, "tuffo: in acqua, con Ctrl, la rana va sotto (%.1f m)" % (frog.global_position.y - river.surface_y()))
				t.check(_trial("waterproof", 1) > 1.0, "la prova della pelle impermeabile conta i secondi di fila in acqua")
				Input.action_release("slam")
				_next(15)
		15: # ondata
			# Lo stesso fiume del tuffo, senza tronchi: il percorso intanto può
			# averne creati altri, e il primo trovato non sarebbe più vuoto.
			var river: Node3D = _river
			if f == 1:
				_equip("waterproof", false, true)
				Lib.place(frog, Vector3(10, river.surface_y() - 0.3, river.global_position.z))
				m.car = _fresh(Vector3(13, river.surface_y() + 0.5, river.global_position.z))
			if f == 30:
				Input.action_press("jump")
			if f == 32:
				Input.action_release("jump")
			if f == 40:
				t.check(m.car.state == 1, "ondata: saltando fuori dall'acqua l'auto vicina viene spinta via")
				_next(16)
		16: # lingua: fionda e prove
			if f == 1:
				_equip("tongue", true, false)
				Lib.place(frog, BASE + Vector3(0, 0.1, 45))
				m.car = _fresh(BASE + Vector3(0, 0, 45) + _forward() * 8.0)
				frog.tongue_power.cooldown_left = 0.0
			if f == 3:
				Input.action_press("tongue")
			if f > 40 and f <= 100:
				m.car.global_position.x += 8.0 / 60.0
			if f == 100:
				Input.action_release("tongue")
			if f == 102:
				t.check(frog.velocity.x > 16.0, "fionda: lasciando dopo un traino si parte a velocità doppia (%.1f m/s)" % frog.velocity.x)
				t.check(_trial("tongue", 0) >= 1.0 and _trial("tongue", 1) > 3.0, "le prove della lingua contano i traini e i metri trascinati")
				_next(17)
		17: # lingua doppia
			if f == 1:
				_equip("tongue", false, true)
				Lib.place(frog, BASE + Vector3(-20, 0.1, 45))
				m.car = _fresh(BASE + Vector3(-20, 0, 45) + _forward() * 8.0)
				frog.tongue_power.cooldown_left = 0.0
			if f == 3:
				Input.action_press("tongue")
			if f == 20:
				m.flies = main.run_flies
				var fly: Node3D = load("res://scripts/fly.gd").new()
				main.add_child(fly)
				fly.global_position = frog.global_position + Vector3(3, 1, 0)
				fly.set_physics_process(false)
			if f == 25:
				t.check(main.run_flies == m.flies + 1, "lingua doppia: mentre la lingua trascina, le mosche vicine finiscono in bocca")
				Input.action_release("tongue")
				t.finish(self)
	return false
