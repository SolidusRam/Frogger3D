extends SceneTree
## Le ultime quattro carte. Guantoni di ghiaccio: il pugno congela l'auto in un
## blocco fermo, il secondo pugno lo fa scivolare, il ghiaccio si scioglie
## (non con l'iceberg). Molle da canguro: salti di fila sempre più veloci,
## fermarsi azzera. Lingua mangiafuoco: ingoia il fuoco di un rottame, sputa
## una palla che fa rottame la prima auto. Lingua-ancora: ferma un'auto o un
## tronco per qualche secondo; senza doppia ancora la nuova libera la vecchia.

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
	# Il test fa molti rottami vicini: il rallentatore delle catene allungherebbe
	# i tempi dell'ancora.
	main.chain_size = 1000


## Un'auto in marcia vicino al centro, lontana dalle tane.
func _driving_car(skip: Array = []) -> Node3D:
	var course: Node = main.get_node("Course")
	for car in Lib.cars(main):
		if car.state != 0 or absf(car.global_position.x) > 20.0 or car in skip:
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
	var punch: Node = frog.punch_power
	var tongue: Node = frog.tongue_power
	match frame:
		3:
			upgrades.equip_kit({})
			upgrades.apply("ice_gloves")
			t.check(punch.enabled and punch.ice and frog._palette.get("glove") == "glove_ice", "i guantoni di ghiaccio danno il pugno, e sono azzurri")
			# Un'auto ferma è un blocco di ghiaccio; la rana la colpisce da dietro.
			var car := _driving_car()
			car.anchor(10.0)
			m.car = car
			frog.camera_rig.rotation.y = 0.0
			Lib.place(frog, car.global_position + Vector3(0.0, -car.global_position.y + 0.1, 1.3))
		5:
			var car: Node3D = m.car
			punch.use()
			main._hitstop_until = 0
			t.check(car.has_meta("ice") and car.freeze and car.state == 1, "il pugno congela l'auto in un blocco fermo")
		30:
			var car: Node3D = m.car
			t.check(car.freeze, "il blocco resta fermo")
			punch.cooldown_left = 0.0
			Lib.place(frog, car.global_position + Vector3(0.0, -car.global_position.y + 0.1, 1.3))
		32:
			var car: Node3D = m.car
			punch.use()
			main._hitstop_until = 0
			t.check(not car.freeze and car.linear_velocity.z < -10.0, "colpito di nuovo, scivola (%.1f m/s)" % car.linear_velocity.z)
			# Lo scioglimento, e l'iceberg.
			var other := _driving_car([car])
			other.freeze_ice()
			other._ice_left = 0.01
			m.melting = other
			var berg := _driving_car([car, other])
			berg.freeze_ice(false)
			t.check(berg._ice_left == INF, "l'iceberg non si scioglie")
		35:
			t.check(not m.melting.has_meta("ice") and not m.melting.freeze, "il ghiaccio si scioglie: torna un rottame")
			# Molle da canguro.
			upgrades.equip_kit({})
			upgrades.apply("kangaroo_springs")
			t.check(frog.kangaroo and frog.super_jump_power.enabled, "le molle da canguro danno anche il super salto")
			frog.velocity = Vector3(5.0, 0.0, 0.0)
			frog._time_on_floor = 0.0
			for i in 3:
				frog._kangaroo_hop()
			t.check(frog.kangaroo_streak == 3 and is_equal_approx(frog.kangaroo_factor(), 1.3), "tre salti di fila: più veloce (×%.2f)" % frog.kangaroo_factor())
			for i in 10:
				frog._kangaroo_hop()
			t.check(is_equal_approx(frog.kangaroo_factor(), frog.kangaroo_max), "fino a un massimo (×%.2f)" % frog.kangaroo_factor())
			frog.velocity = Vector3.ZERO
			frog._time_on_floor = 1.0
			frog._kangaroo_hop()
			t.check(frog.kangaroo_streak == 1 and is_equal_approx(frog.kangaroo_factor(), 1.0), "fermandosi il ritmo riparte da capo")
			# Lingua mangiafuoco: un rottame che fuma vicino.
			upgrades.equip_kit({})
			upgrades.apply("fire_tongue")
			var wreck := _driving_car()
			wreck.become_wreck()
			Lib.place(frog, wreck.global_position + Vector3(4.0, -wreck.global_position.y + 0.1, 0.0))
			t.check(tongue.use() and tongue.loaded, "la lingua ingoia il fuoco del rottame")
			var balls := main.get_children().filter(func(node: Node) -> bool: return node is Node3D and node.get_script() and node.get_script().resource_path.ends_with("fireball.gd"))
			t.check(balls.is_empty(), "e non sputa ancora")
			tongue.cooldown_left = 0.0
			t.check(tongue.use() and not tongue.loaded, "di nuovo: la sputa")
			balls = main.get_children().filter(func(node: Node) -> bool: return node.get_script() != null and node.get_script().resource_path.ends_with("fireball.gd"))
			t.check(balls.size() == 1, "una palla di fuoco")
			# Una palla davanti a un'auto in marcia, ferma per la prova.
			var target := _driving_car([wreck])
			target.anchor(5.0)
			var ball: Node3D = load("res://scripts/fireball.gd").new()
			ball.direction = Vector3.LEFT
			main.add_child(ball)
			ball.global_position = target.global_position + Vector3(4.0, 0.3, 0.0)
			m.target = target
		50:
			t.check(m.target.state == 1, "la palla di fuoco fa rottame l'auto che colpisce")
			# Lingua-ancora.
			upgrades.equip_kit({})
			upgrades.apply("anchor_tongue")
			var car := _driving_car()
			var other := _driving_car([car])
			tongue._anchor(car)
			t.check(car.is_anchored(), "l'ancora ferma l'auto")
			m.car = car
			m.z = car.global_position
			tongue._anchor(other)
			t.check(not car.is_anchored() and other.is_anchored(), "senza doppia ancora, la nuova libera la vecchia")
			tongue.double_anchor = true
			tongue._anchor(car)
			t.check(car.is_anchored() and other.is_anchored(), "con la doppia ancora due cose ferme insieme")
			m.z = car.global_position
			var logs := Lib.by_script(main, "river_log.gd")
			t.check(not logs.is_empty(), "c'è un tronco")
			m.log = logs[0]
			tongue._anchor(m.log)
			m.log_pos = m.log.global_position
		# Più tardi l'auto ferma può essere tamponata da quella dietro (succede
		# anche in gioco): si guarda prima.
		70:
			t.check(m.car.global_position.distance_to(m.z) < 0.05, "l'auto ancorata resta ferma")
		110:
			t.check(Vector2(m.log.global_position.x - m.log_pos.x, m.log.global_position.z - m.log_pos.z).length() < 0.05, "il tronco ancorato non scorre")
		400:
			t.check(not m.log.is_anchored() and m.log.global_position.distance_to(m.log_pos) > 0.5, "dopo qualche secondo il tronco riparte")
			t.finish(self)
	return false
