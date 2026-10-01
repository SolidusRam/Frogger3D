extends SceneTree
## Power-up: la tana ferma il gioco e offre tre carte; la scelta equipaggia e
## fa ripartire. Guantoni esplosivi, correnti calde, pelle dura, offerte.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var upgrades: Node
var hud: Node
var frame := 0
var start := 0
var step := 0
var z := 0.0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")
	hud = main.get_node("Hud")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


func _process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	match step:
		0: # volo fino alla prima tana
			if not paused:
				z -= 0.6
				frog.global_position = Vector3(0, 5, z)
				frog.velocity = Vector3.ZERO
			elif not m.has("checked"):
				m.checked = true
				var shown: int = hud._offer_buttons.filter(func(b): return b.visible).size()
				t.check(true, "raggiunta la prima tana a %.0f m" % -z)
				t.check(hud._offer.visible and shown == 3, "la tana ferma il gioco e offre tre carte")
				# Le prove seguenti non devono finire in un'altra tana.
				main.get_node("Course").den_reached.disconnect(main._on_den_reached)
				upgrades.current_offer.assign(["explosive_gloves", "thermals", "tough_skin"])
				upgrades.choose(0)
				t.check(not paused, "scelta una carta il gioco riparte")
				t.check(upgrades.slots.gloves == "explosive_gloves" and frog.punch_power.explosive, "i guantoni esplosivi occupano lo slot dei guantoni")
				_explosion_setup()
			if frame > 4000:
				t.check(false, "si raggiunge una tana")
				t.finish(self)
		1: # esplosione
			if f == 120:
				var hit := 0
				for i in 2:
					if m.others[i].state == 1 and m.others[i].global_position.distance_to(m.starts[i]) > 1.5:
						hit += 1
				t.check(m.bomb.state == 1 and hit == 2, "l'esplosione trasforma in rottami e scaglia le auto vicine (%d su 2)" % hit)
				_thermal_setup()
		2: # correnti calde
			# Prima qualche istante fermi in aria, poi si apre il deltaplano: così
			# Spazio non diventa un salto da terra.
			if f < 10:
				Lib.place(frog, m.wreck.global_position + Vector3(0, 4, 0))
			if f == 10:
				Input.action_press("jump")
				frog.glider_power.gliding = true
			if f == 12:
				m.y = frog.global_position.y
				m.charge = frog.glider_power.charge
			if f == 70:
				t.check(frog.global_position.y > m.y + 1.0, "nel fumo di un rottame il deltaplano sale (+%.1f m)" % (frog.global_position.y - m.y))
				t.check(frog.glider_power.charge >= m.charge - 0.01, "nelle correnti calde la carica non si consuma")
				Input.action_release("jump")
				upgrades.apply("tough_skin")
				t.check(frog.max_health == 125 and frog.health == 125, "la pelle dura alza la vita massima e cura")
				var repeated := false
				for i in 20:
					var offer: Array = upgrades.make_offer()
					if offer.has("explosive_gloves") or offer.has("thermals"):
						repeated = true
				t.check(not repeated, "le offerte non ripropongono i modificatori già equipaggiati")
				t.finish(self)
	return false


## Una piattaforma di terreno dietro la partenza, dove il percorso non genera
## niente: nessun treno o auto può disturbare le prove.
func _test_ground() -> void:
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(120, 1, 120)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ground.add_child(collision)
	main.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 320)


## Tre auto in marcia vicine e ferme; la prima viene armata come da un pugno.
func _explosion_setup() -> void:
	_next(1)
	_test_ground()
	# Solo auto piccole, affiancate senza sovrapporsi: un camion sovrapposto
	# scaglierebbe via la "bomba" prima dell'esplosione.
	var driving: Array = Lib.cars(main).filter(func(c): return c.state == 0 and c.model_type in ["compact", "sedan"])
	for car in driving.slice(0, 3):
		car.get_parent().set_physics_process(false)
		car.set_physics_process(false)
	var base := Vector3(0, 0, 300)
	m.bomb = driving[0]
	m.others = [driving[1], driving[2]]
	m.bomb.global_position = base + Vector3(0, m.bomb.size.y / 2.0, 0)
	m.others[0].global_position = base + Vector3(0, m.others[0].size.y / 2.0, 3)
	m.others[1].global_position = base + Vector3(0, m.others[1].size.y / 2.0, -3)
	m.starts = [m.others[0].global_position, m.others[1].global_position]
	m.bomb.set_physics_process(true)
	m.bomb.receive_punch(Vector3.ZERO, true)
	# Diventando rottame conserverebbe la velocità di marcia e scapperebbe via.
	m.bomb.linear_velocity = Vector3.ZERO
	frog.global_position = Vector3(0, 40, 350)


## Un rottame fermo che fuma e la rana col deltaplano aperto poco sopra.
func _thermal_setup() -> void:
	_next(2)
	upgrades.apply("thermals")
	var wreck = Lib.cars(main).filter(func(c): return c.state == 0 and c.is_physics_processing())[0]
	wreck.become_wreck()
	wreck.freeze = true
	wreck.global_position = Vector3(10, 1, 330)
	m.wreck = wreck

