extends SceneTree
## Fiume: nuoto, salto dall'acqua, tronchi, coccodrilli, zattere. Il
## gradino: dal livello 3 di calore il tronco affonda sotto la rana, con un
## secondo di avviso, e torna su quando lei scende.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var river: Node3D
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")


func _clear_lane() -> Node3D:
	# Una corrente sgombra: niente tronchi né coccodrilli che arrivino addosso.
	var lane: Node3D = Lib.by_script(river, "river_lane.gd")[0]
	lane.set_physics_process(false)
	for child in lane.get_children():
		child.free()
	return lane


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	match step:
		0:
			if frame == 5:
				river = Lib.by_script(main, "river.gd")[0]
				m.lane = _clear_lane()
				Lib.place(frog, Vector3(0, 0.3, m.lane.global_position.z))
				_next(1)
				m.lane = Lib.by_script(river, "river_lane.gd")[0]
		1: # nuoto
			if f == 120:
				t.check(frog.is_swimming(), "in acqua nuota")
				t.check(absf(frog.global_position.y - (river.surface_y() - frog.float_depth)) < 0.1, "galleggia alla quota prevista")
				t.check(frog.health < 75 and frog.health > 50, "in 2 s perde circa 40 di vita (vita %d)" % frog.health)
				m.top = -9.0
				Input.action_press("jump")
			if f > 120:
				m.top = maxf(m.top, frog.global_position.y)
			if f == 160:
				Input.action_release("jump")
			if f == 200:
				t.check(m.top > 0.3, "il salto tenuto esce dall'acqua (piedi a %.2f)" % m.top)
				_next(2)
		2: # tronco e coccodrillo
			if f == 1:
				for lane in Lib.by_script(river, "river_lane.gd"):
					for child in lane.get_children():
						var file: String = child.get_script().resource_path.get_file()
						if file == "river_log.gd" and absf(child.global_position.x) < 20.0 and not m.has("log"):
							m.log = child
						if file == "crocodile.gd" and absf(child.global_position.x) < 20.0 and not m.has("croc"):
							m.croc = child
				Lib.place(frog, m.log.global_position + Vector3.UP * (m.log.size.y / 2.0 + 0.05))
				m.frog_x = frog.global_position.x
				m.log_x = m.log.global_position.x
			if f == 120:
				var log_moved: float = m.log.global_position.x - m.log_x
				var frog_moved: float = frog.global_position.x - m.frog_x
				t.check(absf(log_moved) > 2.0, "il tronco scorre con la corrente (%.1f m in 2 s)" % log_moved)
				t.check(absf(log_moved - frog_moved) < 0.6, "il tronco trasporta la rana")
				t.check(frog.health == frog.max_health, "sul tronco non si fa male")
				t.check(not m.log.is_sinking(), "a calore basso il tronco non affonda")
				if m.has("croc"):
					var croc: Node3D = m.croc
					Lib.place(frog, croc.global_position - croc.global_basis.z * (croc.size.z / 2.0 - 0.5) + Vector3.UP * 0.2)
					m.bite_from = f
			if m.has("bite_from") and f > m.bite_from and frog.health < frog.max_health and not m.has("bitten"):
				m.bitten = true
			if f == 420:
				t.check(m.has("bitten"), "davanti alla bocca il coccodrillo morde")
				_next(3)
		3: # zattera: un rottame nel fiume galleggia e non fa male
			if f == 1:
				var lane := _clear_lane()
				var car: Node3D = Lib.cars(main).filter(func(c): return c.state == 0)[0]
				car.get_parent().remove_child(car)
				lane.add_child(car)
				car.global_position = Vector3(0, 2.0, lane.global_position.z)
				car.become_wreck()
				m.car = car
				Lib.place(frog, Vector3(0, 30, 0))
			if f == 300:
				var car: Node3D = m.car
				t.check(car.global_position.y > river.surface_y() - 1.5 and car.global_position.y < river.surface_y() + 1.5, "il rottame galleggia (quota %.2f)" % car.global_position.y)
				t.check(car.is_floating(), "il rottame è riconosciuto come zattera")
				Lib.place(frog, car.global_position + Vector3(-2.5, 0.4, 0))
			if f > 300 and f < 330 and not frog.is_swimming():
				frog.velocity.x = 7.0
			if f == 360:
				# Solo l'acqua può togliere vita: al massimo pochi punti, mai 20 o più in un colpo.
				t.check(frog.health > frog.max_health - 20, "correre contro una zattera non fa male (vita %d)" % frog.health)
				_next(4)
		4: # il gradino: dal livello 3 il tronco affonda sotto la rana
			var heat: Node = root.get_node("Heat")
			if f == 1:
				heat.running = false
				heat.value = 61.0
				frog.heal_full()
				for lane in Lib.by_script(main, "river_lane.gd"):
					for child in lane.get_children():
						# Un tronco lungo, vicino alla rana, che va verso il centro: resta
						# in vista per tutta la prova.
						var x: float = child.global_position.x
						var near: bool = absf(child.global_position.z - frog.global_position.z) < 40.0
						if child.get_script().resource_path.get_file() == "river_log.gd" and near and absf(x) < 20.0 and x * child.drift_velocity.x < 0.0 and child.size.z > 7.0 and not m.has("log"):
							m.log = child
				Lib.place(frog, m.log.global_position + Vector3.UP * (m.log.size.y / 2.0 + 0.05))
				m.float_y = m.log.global_position.y
				m.log_x = m.log.global_position.x
			if f == 45:
				t.check(not m.log.is_sinking() and not frog.is_swimming(), "per il primo secondo il tronco regge (avviso: trema)")
			# Saltella sul posto: non basta a tenerlo a galla.
			if f > 50 and f < 160 and frog.is_on_floor():
				frog.velocity.y = 5.0
			if f == 100:
				t.check(m.log.is_sinking(), "poi comincia ad affondare, anche saltellando")
				t.check(absf(m.log.global_position.x - m.log_x) > 2.0, "mentre affonda il tronco continua a scorrere")
			if f == 200:
				t.check(frog.is_swimming(), "in circa 3 s la rana finisce in acqua")
				Lib.place(frog, Vector3(0, 30, 0))
			if f == 400:
				t.check(not m.log.is_sinking() and absf(m.log.global_position.y - m.float_y) < 0.05, "senza la rana il tronco torna a galla")
				t.finish(self)
	if frame > 4000:
		t.check(false, "il test non si è bloccato (step %d)" % step)
		t.finish(self)
	return false
