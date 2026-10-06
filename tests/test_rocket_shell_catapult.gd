extends SceneTree
## Le tre carte nuove del mazzo iniziale. Molle a razzo: in aria un secondo
## super salto (un terzo col miglioramento), e la scia di fuoco fa rottami
## sotto. Guscio: assorbe un colpo intero, si rompe, si riforma; con le spine
## l'auto che lo rompe diventa rottame. Lingua-catapulta: aggancia solo
## rottami, li tiene sopra la testa e li scaglia dove si guarda.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var upgrades: Node
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")


## Un'auto in marcia vicino al centro, lontana dalle tane (arrivare in tana
## fermerebbe il gioco per le carte).
func _driving_car() -> Node3D:
	var course: Node = main.get_node("Course")
	for car in Lib.cars(main):
		if car.state != 0 or absf(car.global_position.x) > 20.0:
			continue
		var near_den := false
		for dz in [-8.0, 0.0, 8.0, 16.0]:
			if course.kind_at(car.global_position.z + dz) == 5: # 5 = tana
				near_den = true
		if not near_den:
			return car
	return null


func _physics_process(_delta: float) -> bool:
	frame += 1
	var jump: Node = frog.super_jump_power
	match frame:
		3:
			upgrades.equip_kit({})
			upgrades.apply("rocket_springs")
			t.check(jump.enabled and jump.rocket, "le molle a razzo danno il super salto e il razzo")
			Lib.place(frog, frog.global_position)
			jump.use(Vector3.FORWARD)
		20:
			t.check(jump.can_air_jump(), "in aria, durante la ricarica, il razzo è pronto")
			m.vy = frog.velocity.y
			jump.air_jump(Vector3.FORWARD)
			t.check(frog.velocity.y > m.vy + 5.0, "il secondo salto rilancia in alto (%.1f → %.1f)" % [m.vy, frog.velocity.y])
			t.check(not jump.can_air_jump(), "un solo salto in aria")
			# Terzo stadio.
			jump.air_jumps = 2
		60:
			pass
		120:
			t.check(frog.is_on_floor(), "atterrata")
			jump.cooldown_left = 0.0
			jump.use(Vector3.FORWARD)
		135:
			jump.air_jump(Vector3.FORWARD)
			t.check(jump.can_air_jump(), "col terzo stadio un altro salto ancora")
			# La scia di fuoco: un'auto sotto la rana diventa rottame.
			var car := _driving_car()
			m.car = car
			Lib.place(frog, car.global_position + Vector3.UP * 5.0)
			jump.fire_trail = true
			jump.active = true
			jump.air_jump(Vector3.FORWARD)
			t.check(car.state == 1, "la scia di fuoco fa rottame l'auto sotto")
			jump.fire_trail = false
			jump.air_jumps = 1
			# Il guscio.
			upgrades.apply("shell")
			Lib.place(frog, Vector3(0.0, 0.1, frog.global_position.z + 40.0))
		140:
			t.check(frog.shell and frog._shell_mesh.visible, "il guscio si vede sulla schiena")
			var health: int = frog.health
			frog.take_hit(30, Vector3(5, 3, 0))
			t.check(frog.health == health and not frog._shell_ready, "il guscio para il colpo e si rompe (vita %d)" % frog.health)
			frog._invulnerable_time = 0.0
			frog._stun_time = 0.0
			frog.take_hit(30, Vector3(5, 3, 0))
			t.check(frog.health < health, "rotto il guscio, il colpo dopo fa male")
		160:
			t.check(not frog._shell_mesh.visible, "il guscio rotto non si vede")
			frog._shell_left = 0.01
		163:
			t.check(frog._shell_ready and frog._shell_mesh.visible, "dopo la ricarica il guscio si riforma")
			# Le spine.
			frog.shell_spines = true
			var car := _driving_car()
			frog._invulnerable_time = 0.0
			frog.last_hit_by = car
			frog.take_hit(30, Vector3.ZERO)
			t.check(car.state == 1, "con le spine l'auto che rompe il guscio diventa rottame")
			frog.shell_spines = false
			upgrades.equip_kit({})
			t.check(not frog.shell and not frog._shell_mesh.visible, "senza la carta niente guscio")
			# La catapulta: un rottame davanti alla rana.
			upgrades.apply("catapult_tongue")
			frog._invulnerable_time = 0.0
			frog._stun_time = 0.0
			var wreck := _driving_car()
			wreck.become_wreck()
			m.wreck = wreck
			var other := _driving_car()
			m.other = other
			# La rana guarda il rottame da 6 m; il mirino non prende auto in marcia.
			var spot: Vector3 = wreck.global_position + Vector3(0.0, 0.0, 6.0)
			spot.y = 0.1
			Lib.place(frog, spot)
			frog.camera_rig.rotation.y = 0.0
			# Le mosche il mirino le preferisce: qui non servono.
			for fly in get_root().get_tree().get_nodes_in_group("flies"):
				fly.queue_free()
		166:
			var tongue: Node = frog.tongue_power
			var target: Node3D = tongue._find_target()
			t.check(target == m.wreck, "la catapulta mira il rottame (%s, rottame a %.1f m)" % [target, m.wreck.global_position.distance_to(frog.global_position)])
			# Si tiene premuto: lasciando, la rana scaglia. La rana sta in mezzo
			# alla strada: il traffico non deve interrompere la prova.
			frog._invulnerable_time = 10.0
			Input.action_press("tongue")
			t.check(tongue.use(), "la lingua aggancia il rottame")
		200:
			var tongue: Node = frog.tongue_power
			var wreck: Node3D = m.wreck
			t.check(wreck.global_position.y > frog.global_position.y + 1.5, "il rottame è sospeso sopra la testa (%.1f m)" % (wreck.global_position.y - frog.global_position.y))
			Input.action_release("tongue")
		202:
			var wreck: Node3D = m.wreck
			t.check(not frog.tongue_power.attached, "lasciato il tasto, la lingua molla")
			var flat := Vector2(wreck.linear_velocity.x, wreck.linear_velocity.z)
			t.check(flat.length() > 20.0 and wreck.linear_velocity.z < -15.0, "lasciando, lo scaglia dove si guarda (%.1f m/s)" % flat.length())
			t.check(wreck.has_meta("thrown"), "il rottame è segnato come scagliato")
			t.finish(self)
	return false
