extends SceneTree
## La pattuglia acrobatica: il capo vola alto e innocuo, i gregari passano
## dopo, bassi, esattamente sotto la sua strada; la scia resta nel cielo e
## sul banco di nubi; il giro della morte sale e torna giù; il gregario
## travolge chi tocca ma porta chi gli sta sopra; il capo colpito precipita
## e i gregari si schiantano dove si è schiantato lui, scaldando il mondo.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var course: Node3D
var heat: Node
var frame := 0
var start := 0
var step := 0
var m := {}
var formation_node: Node3D
var wrecks := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	course = main.get_node("Course")
	heat = root.get_node("Heat")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


func _show() -> Node:
	var found: Node = null
	for chunk in course.get_children():
		if chunk.has_meta("kind") and chunk.get_meta("kind") == 8:
			found = Lib.by_script(chunk, "aerobatics.gd")[0]
	return found


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				heat.running = false
				main.next_world()
				course.jump_to(8) # la pattuglia
				_next(1)
		1:
			if f == 5:
				var show := _show()
				t.check(show != null, "nel cielo c'è la pattuglia acrobatica")
				# Niente passaggi a caso durante la prova.
				show.set_physics_process(false)
				for old in Lib.by_script(show, "formation.gd"):
					old.queue_free()
				# Un passaggio: senza giro della morte e senza scarabocchio, per misurare.
				var formation: Node3D = load("res://scripts/formation.gd").new()
				formation.direction = 1.0
				formation.loop_chance = 0.0
				formation.half_depth = show.depth / 2.0
				formation.half_length = 67.0
				show.add_child(formation)
				formation_node = formation
		2:
			pass
	if step == 1 and f > 5:
		var formation: Node3D = formation_node
		var leader: Node3D = formation.leader()
		var planes: Array = formation.wingmen_planes()
		if f == 6:
			t.check(leader != null and planes.size() == formation.wingmen, "un capo e %d gregari" % formation.wingmen)
		if f == 60:
			t.check(leader.global_position.y > 6.0, "il capo vola alto (%.1f m)" % leader.global_position.y)
			var low: Node3D = planes[0]
			t.check(absf(low.position.y - 1.1) < 0.5 or low.position.x < -60.0, "i gregari volano bassi")
			var trails := formation.find_children("*", "CPUParticles3D", true, false)
			t.check(trails.size() >= 2 and trails.all(func(p): return p.emitting), "la scia nel cielo e la sua ombra sul banco")
			m.leader_at_60 = leader.position
		# Il primo gregario passa dove era passato il capo, LIFT metri sotto.
		var delay: int = formation._delays[0]
		if f == 60 + delay:
			var first: Node3D = planes[0]
			var expected: Vector3 = m.leader_at_60 - Vector3.UP * formation.LIFT
			t.check(first.position.distance_to(expected) < 0.6, "il primo gregario passa esattamente sotto la scia (scarto %.2f m)" % first.position.distance_to(expected))
			# Travolge chi tocca.
			Lib.place(frog, first.global_position + Vector3(0, -0.3, 0))
			m.hp = frog.health
		if f == 62 + delay:
			t.check(frog.health < m.hp, "il gregario travolge la rana (vita %d)" % frog.health)
			# Il capo colpito con un pugno precipita.
			Lib.place(frog, leader.global_position + Vector3(0, -2.0, 0))
			frog.velocity = Vector3.ZERO
			main.get_node("Wildfire").stopped = true
			heat.wreck_created.connect(func(_c): wrecks += 1)
			frog.punch_power.cooldown_left = 0.0
			frog.punch()
			t.check(formation.is_crashed(), "un pugno vicino abbatte il capo")
			# Lontano dallo schianto, per non farsi male.
			Lib.place(frog, Vector3(0, 0.5, frog.global_position.z + 30.0))
			_next(3)
	if step == 3:
		var formation: Node3D = formation_node
		if f == 600 or (f > 30 and not is_instance_valid(formation)):
			t.check(not is_instance_valid(formation) or formation.wingmen_planes().is_empty(), "i gregari seguono il capo fino allo schianto")
			t.check(wrecks >= 2, "ogni schianto è caos che scalda (%d)" % wrecks)
			_next(4)
	if step == 4 and f == 1:
		# Il giro della morte: sale e torna giù.
		var show := _show()
		var formation: Node3D = load("res://scripts/formation.gd").new()
		formation.loop_chance = 1.0
		formation.half_depth = show.depth / 2.0
		show.add_child(formation)
		var top := 0.0
		for p in formation._points:
			top = maxf(top, p.y)
		t.check(top > 8.0, "il giro della morte sale (%.1f m): in cima si passa sotto" % top)
		formation.queue_free()
		# Sugli aerei si sale: un passaggio dritto, la rana sul dorso del primo.
		var ride: Node3D = load("res://scripts/formation.gd").new()
		ride.direction = 1.0
		ride.loop_chance = 0.0
		ride.half_depth = 1.0
		ride.half_length = 67.0
		show.add_child(ride)
		formation_node = ride
		_next(5)
	if step == 5:
		var plane: Node3D = formation_node.wingmen_planes()[0]
		if not m.has("on") and plane.global_position.x > -30.0 and f > 2:
			Lib.place(frog, plane.global_position + Vector3(0, 1.3, 0))
			m.on = frame
			m.x = plane.global_position.x
			m.hp = frog.health
		if m.has("on") and frame == m.on + 40:
			t.check(frog.global_position.x - m.x > 4.0 and frog.health == m.hp, "sul dorso del gregario la rana viaggia sicura (%.1f m)" % (frog.global_position.x - m.x))
			t.finish(self)
	return false
