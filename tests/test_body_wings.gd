extends SceneTree
## Quattro carte da sbloccare. Assicurazione: un colpo mortale lascia la rana
## con 1 di vita (30 con la franchigia), il calore sale di un livello, e si
## rinnova in tana. Rana velenosa: la pelle gialla, l'auto avvelenata diventa
## rottame, e con la tossina il rottame avvelena chi lo tocca. Ala corazzata:
## in volo para un colpo e si resta in aria; con l'ariete le auto toccate
## diventano rottami. Ala a elica: sospesa sul posto, poi plana; la turbina
## ribalta le auto sotto.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var upgrades: Node
var heat: Node
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")


## Un'auto in marcia vicino al centro, lontana dalle tane.
func _driving_car() -> Node3D:
	var course: Node = main.get_node("Course")
	for car in Lib.cars(main):
		if car.state != 0 or absf(car.global_position.x) > 20.0:
			continue
		var near_den := false
		for dz in [-8.0, 0.0, 8.0, 16.0]:
			if course.kind_at(car.global_position.z + dz) == 5:
				near_den = true
		if not near_den:
			return car
	return null


func _physics_process(_delta: float) -> bool:
	frame += 1
	heat = root.get_node("Heat")
	var glider: Node = frog.glider_power
	match frame:
		3:
			# Assicurazione.
			upgrades.apply("insurance")
			var level: int = heat.level()
			frog.take_hit(100000, Vector3.ZERO)
			t.check(not frog.is_dead and frog.health == 1, "l'assicurazione lascia la rana con 1 di vita (%d)" % frog.health)
			t.check(heat.level() == level + 1, "e il calore sale di un livello (%d → %d)" % [level, heat.level()])
			t.check(not frog.insurance_ready, "una volta per sezione")
			main.get_node("Course").den_reached.emit(1, 50.0)
			t.check(frog.insurance_ready, "in tana si rinnova")
			# La tana ha aperto le carte (e fermato il gioco): si chiudono.
			main.get_node("Hud").hide_offer()
			paused = false
			frog.asleep = false
			frog.insurance_deductible = true
			frog.insurance_bonus = true
			frog._invulnerable_time = 0.0
			level = heat.level()
			frog.take_hit(100000, Vector3.ZERO)
			t.check(frog.health == 30 and heat.level() == level, "franchigia e premio: 30 di vita, il calore non sale")
			# Rana velenosa.
			upgrades.equip_kit({})
			upgrades.apply("poison")
			t.check(frog.poisonous and frog._palette.get("frog") == "frog_poison", "la rana velenosa è gialla")
			var car := _driving_car()
			car.poison(true)
			t.check(car.state == 1 and car.has_meta("poison"), "l'auto avvelenata diventa rottame, e con la tossina avvelena")
			var other := _driving_car()
			car._on_wreck_body_entered(other)
			t.check(other.state == 1, "il rottame avvelenato avvelena chi lo tocca, anche piano")
			upgrades.equip_kit({})
			t.check(not frog.poisonous and frog._palette.get("frog", "") == "", "senza la carta la pelle torna normale")
			# Ala corazzata, in volo.
			upgrades.apply("armored_wing")
			frog.health = frog.max_health
			frog._invulnerable_time = 0.0
			Lib.place(frog, Vector3(0.0, 6.0, frog.global_position.z))
			Input.action_press("jump")
		# Un passo dopo la rana non tocca più terra: il deltaplano resta aperto.
		5:
			glider.charge = glider.duration
			glider.gliding = true
			glider.armor_left = glider.armor_hits
		6:
			var health: int = frog.health
			frog.take_hit(30, Vector3(6, 0, 0))
			t.check(frog.health == health and glider.gliding, "l'ala corazzata para il colpo e la rana resta in volo")
			frog._invulnerable_time = 0.0
			frog.take_hit(30, Vector3(6, 0, 0))
			t.check(frog.health < health, "un colpo solo per volo")
			# L'ariete.
			glider.ram = true
			var car := _driving_car()
			Lib.place(frog, car.global_position + Vector3.UP * 1.0)
			glider.gliding = true
			glider._ram()
			t.check(car.state == 1, "con l'ariete l'auto toccata in volo diventa rottame")
			glider.ram = false
			Input.action_release("jump")
			# Ala a elica.
			upgrades.equip_kit({})
			upgrades.apply("propeller_wing")
			# Sopra la striscia di partenza: lontano dalle tane.
			Lib.place(frog, Vector3(0.0, 8.0, frog._spawn_position.z - 5.0))
			Input.action_press("jump")
		8:
			glider.charge = glider.duration
			glider.gliding = true
			glider._hover_left = glider.hover_seconds
			m.y = frog.global_position.y
		50:
			t.check(glider.gliding and absf(frog.global_position.y - m.y) < 0.6, "l'ala a elica tiene sospesa la rana (%.2f m)" % (frog.global_position.y - m.y))
			t.check(Vector2(frog.velocity.x, frog.velocity.z).length() < 2.5, "quasi ferma")
		190:
			t.check(glider._hover_left <= 0.0 and Vector2(frog.velocity.x, frog.velocity.z).length() > 5.0, "dopo la sospensione plana (%.1f m/s)" % Vector2(frog.velocity.x, frog.velocity.z).length())
			Input.action_release("jump")
			# La turbina.
			glider.turbine = true
			var car := _driving_car()
			Lib.place(frog, car.global_position + Vector3.UP * 6.0)
			glider._hover_left = 1.0
			glider._hover(Vector3.ZERO, 0.016)
			t.check(car.state == 1, "la turbina ribalta l'auto sotto")
			t.finish(self)
	return false
