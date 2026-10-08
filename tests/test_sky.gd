extends SceneTree
## Il cielo: al posto dell'acqua c'è il vuoto (niente letto né superficie),
## nuvole al posto dei tronchi e aquile al posto dei coccodrilli; chi cade
## perde vita e ricompare sull'ultima striscia sicura passata, purché davanti
## al fuoco (altrimenti la prima davanti al fuoco); il paesaggio è un mare di
## nubi e la luce è quella del cielo. Tornati sulla terra, l'acqua torna.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var heat: Node
var fire: Node3D
var course: Node3D
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	heat = root.get_node("Heat")
	fire = main.get_node("Wildfire")
	course = main.get_node("Course")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


func _chunks(kind: int) -> Array:
	return course.get_children().filter(func(c): return c.has_meta("kind") and c.get_meta("kind") == kind)


func _center(chunk: Node3D) -> float:
	return chunk.get_meta("near_z") - chunk.get_meta("depth") / 2.0


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				heat.running = false
				t.check(not frog.void_world, "sulla terra la rana nuota")
				main.next_world()
				# Un fiume di vuoto subito davanti.
				course.jump_to(3) # 3 = fiume
				_next(1)
		1:
			if f == 60:
				t.check(frog.void_world, "nel cielo cade")
				var rivers := _chunks(3) # 3 = fiume
				t.check(not rivers.is_empty(), "il cielo ha i suoi fiumi di vuoto (%d)" % rivers.size())
				var river: Node = Lib.by_script(rivers[0], "river.gd")[0]
				var bodies := river.get_children().filter(func(c): return c is StaticBody3D)
				t.check(river.sky and bodies.is_empty(), "senza letto: sotto c'è il vuoto")
				var logs := Lib.by_script(river, "river_log.gd")
				t.check(not logs.is_empty() and logs.all(func(l): return l.cloud and l.get_node_or_null("Cloud") != null), "al posto dei tronchi, nuvole (%d)" % logs.size())
				var croc: Node3D = load("res://scripts/crocodile.gd").new()
				croc.eagle = true
				croc.size = Vector3(1.4, 0.8, 6.0)
				main.add_child(croc)
				croc.global_position = Vector3(0, -50, 400)
				t.check(croc.find_child("WingL", true, false) != null, "al posto dei coccodrilli, aquile con le ali")
				croc.queue_free()
				var backdrop: Node3D = main.get_node("Backdrop")
				t.check(backdrop._plain.position.y < -50.0 and not backdrop._mountains[0].visible, "sotto, un mare di nubi lontano")
				var sky: ProceduralSkyMaterial = main.environment.environment.sky.sky_material
				t.check(sky.sky_top_color.b > 0.6 and sky.sky_top_color.r < 0.3, "il cielo è blu pieno (%s)" % str(sky.sky_top_color))
				# La caduta: davanti a un fiume, nel vuoto.
				var river_chunk: Node3D = rivers[0]
				m.before = frog.health
				fire.front_z = frog.global_position.z + 40.0
				Lib.place(frog, Vector3(3.0, -6.0, _center(river_chunk)))
				frog.health = frog.max_health
				m.before = frog.health
				m.fall_z = _center(river_chunk)
				_next(2)
				m.before = frog.max_health
				m.fall_z = _center(river_chunk)
		2:
			if f == 3:
				t.check(frog.health == m.before - frog.void_damage, "chi cade perde %d di vita (%d)" % [frog.void_damage, frog.health])
				t.check(course.kind_at(frog.global_position.z) in [0, 1, 5], "e ricompare su una striscia sicura")
				t.check(frog.global_position.z > m.fall_z and frog.global_position.z < fire.front_z, "dietro, ma davanti al fuoco (%.1f, fuoco %.1f)" % [frog.global_position.z, fire.front_z])
				# Nessuna striscia più vicina dietro: è l'ultima passata.
				var closer := false
				for c in _chunks(1) + _chunks(0) + _chunks(5):
					var z := _center(c)
					if z > m.fall_z and z < frog.global_position.z - 0.5:
						closer = true
				t.check(not closer, "l'ultima passata, non una qualsiasi")
				t.check(absf(frog.global_position.x - 3.0) < 0.01, "alla stessa x")
				# Il fuoco si è già preso la striscia dietro: la prima davanti a lui.
				var strip_z: float = frog.global_position.z
				fire.front_z = strip_z + 1.0
				var point: Vector3 = course.safe_point(m.fall_z - 0.1, fire.front_z - main.void_fire_margin, 0.0)
				t.check(point.z < fire.front_z - main.void_fire_margin, "se il fuoco l'ha presa, una più avanti, davanti al fuoco (%.1f)" % point.z)
				# Torna la terra: l'acqua di nuovo.
				main.next_world()
				_next(3)
		3:
			if f == 60:
				t.check(not frog.void_world, "tornati sulla terra si nuota di nuovo")
				var rivers := _chunks(3)
				if not rivers.is_empty():
					var river: Node = Lib.by_script(rivers[0], "river.gd")[0]
					t.check(not river.sky, "e i fiumi hanno l'acqua")
				var backdrop: Node3D = main.get_node("Backdrop")
				t.check(backdrop._mountains[0].visible, "e tornano le montagne")
				t.finish(self)
	return false
