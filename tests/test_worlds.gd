extends SceneTree
## I mondi: il teletrasporto compare su una striscia sicura solo al calore 5
## (uno per sezione), spostato di lato; entrarci porta nel mondo nuovo col
## calore a zero, il percorso che ricomincia sotto la rana (la distanza no),
## l'incendio lasciato indietro e un inseguitore più veloce; la quantità
## continua a crescere; finito l'ultimo mondo si torna al primo, con un
## livello di Siccità in più. A calore pieno il caos nutre l'inseguitore.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var heat: Node
var style: Node
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
	style = root.get_node("Style")
	fire = main.get_node("Wildfire")
	course = main.get_node("Course")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


func _portals() -> Array:
	return Lib.by_script(course, "portal.gd")


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				heat.running = false
				t.check(_portals().is_empty(), "sotto il calore 5 non c'è nessun teletrasporto")
				t.check(style.world == "terra" and course.world == 0, "la run parte dalla terra")
				heat.set_value(100.0)
				_next(1)
		1: # al calore 5 compare, su una striscia sicura davanti
			if f == 3:
				var portals := _portals()
				t.check(portals.size() == 1, "al calore 5 compare un teletrasporto (%d)" % portals.size())
				if portals.is_empty():
					t.finish(self)
					return true
				var portal: Node3D = portals[0]
				var chunk: Node3D = portal.get_parent()
				t.check(chunk.get_meta("kind") == 1, "sta su una striscia sicura") # 1 = SAFE
				t.check(chunk.get_meta("near_z") <= frog.global_position.z - course.portal_min_ahead, "abbastanza avanti (%.0f m)" % (frog.global_position.z - chunk.get_meta("near_z")))
				# Andando avanti, ogni sezione nuova ha il suo, non uno per striscia.
				frog.global_position.z -= 400.0
				frog.reset_physics_interpolation()
				m.portal = portal
				_next(2)
		2:
			if f == 30:
				var sections := {}
				var strips := 0
				for chunk in course.get_children():
					if chunk.has_meta("kind") and chunk.get_meta("kind") == 1:
						strips += 1
					if chunk.has_meta("portal"):
						sections[chunk.get_meta("section")] = sections.get(chunk.get_meta("section"), 0) + 1
				t.check(sections.values().all(func(n): return n == 1), "un teletrasporto per sezione al più (%s)" % str(sections))
				t.check(not sections.is_empty() and sections.size() < strips, "non su ogni striscia (%d su %d)" % [sections.size(), strips])
				var distance: float = course.distance()
				fire.elapsed = 300.0
				fire.front_z = frog.global_position.z + 5.0
				# Dentro il teletrasporto più vicino davanti.
				var portal: Node3D = null
				for p in _portals():
					if portal == null or p.global_position.z > portal.global_position.z:
						portal = p
				frog.global_position = portal.global_position + Vector3(0, 0.5, 0)
				frog.reset_physics_interpolation()
				_next(3)
				m.distance = distance
		3: # il passaggio
			if f == 10:
				t.check(course.world == 1 and style.world == "cielo", "il teletrasporto porta nel cielo")
				t.check(heat.value < 1.0, "col calore a zero (%.1f)" % heat.value)
				t.check(style.color_of("grass") != style.styles[style.current].colors.get("grass", Color.MAGENTA), "il cielo ha i suoi colori")
				t.check(absf(fire.distance() - fire.max_gap) < 2.0, "l'incendio è lasciato indietro (%.1f m)" % fire.distance())
				t.check(fire.elapsed < 1.0, "senza l'accelerazione accumulata")
				t.check(fire.world_factor > 1.0, "e l'inseguitore del mondo nuovo corre di più (×%.2f)" % fire.world_factor)
				t.check(course.distance() >= m.distance, "la distanza continua (%.0f m)" % course.distance())
				t.check(course.growth_cap() > course.section_growth_cap, "la quantità continua a crescere (tetto %d)" % course.growth_cap())
				t.check(course.kind_at(frog.global_position.z) == 0, "la rana è su una partenza nuova") # 0 = START
				t.check(_portals().is_empty(), "nel mondo nuovo nessun teletrasporto, a calore zero")
			if f == 120:
				t.check(frog.is_on_floor() and absf(frog.global_position.y) < 1.0, "la rana arriva dall'alto e atterra (y %.2f)" % frog.global_position.y)
				# A calore pieno il caos nutre l'inseguitore.
				heat.set_value(100.0)
				fire.stopped = true
				fire.front_z = frog.global_position.z + 30.0
				var car := Node3D.new()
				main.add_child(car)
				car.global_position = frog.global_position + Vector3(5, 0, 0)
				heat.on_wreck(car)
				t.check(absf(fire.distance() - (30.0 - fire.fed_per_wreck)) < 0.01, "a calore pieno un rottame vicino avvicina l'inseguitore (%.1f m)" % fire.distance())
				heat.set_value(50.0)
				fire.front_z = frog.global_position.z + 30.0
				heat.on_wreck(car)
				t.check(absf(fire.distance() - 30.0) < 0.01, "sotto il massimo no")
				car.queue_free()
				fire.stopped = false
				var gap: float = fire.max_gap
				# Il giro: dal cielo si torna alla terra, con la Siccità 1.
				main.next_world()
				_next(4)
				m.gap = gap
		4:
			if f == 5:
				t.check(course.world == 0 and course.loop == 1, "finito l'ultimo mondo si torna al primo (giro %d)" % (course.loop + 1))
				t.check(style.world == "terra", "coi colori della terra")
				t.check(absf(fire.max_gap - (m.gap - 10.0)) < 0.01, "il giro nuovo aggiunge la Siccità 1: l'incendio più vicino (%.0f m)" % fire.max_gap)
				t.check(absf(main.fly_value - 1.2) < 0.01, "e le mosche valgono come alla Siccità 1 (×%.2f)" % main.fly_value)
				t.check(fire.world_factor > 1.2, "l'inseguitore corre ancora di più (×%.2f)" % fire.world_factor)
				t.finish(self)
	return false
