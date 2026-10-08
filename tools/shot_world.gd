extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## I mondi. SCENE: portale (il teletrasporto visto dalla rana al calore 5) |
## cielo (la rana appena arrivata nel cielo, che guarda avanti) | nuvole (un
## fiume di vuoto con nuvole e aquile) | bioma (nel cielo, il bioma BIOMA:
## 2 strada, 4 funivia, 6 aeroporto, 7 porto, 5 tana; ATTESA: fotogrammi prima
## dello scatto). HEAT, SHOT.
var frame := 0
var main: Node
var frog: Node3D
var course: Node3D
var scene := OS.get_environment("SCENE")
var wait := int(OS.get_environment("ATTESA")) if OS.get_environment("ATTESA") != "" else 90


func _initialize() -> void:
	get_root().size = Vector2i(1280, 720)
	seed(11)
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_shot.cfg"
	main.progress_path = "user://progressi_shot.cfg"
	main.tutorial = false
	root.add_child(main)
	current_scene = main
	frog = main.get_node("Frog")
	course = main.get_node("Course")
	if OS.get_environment("STILE") != "":
		root.get_node("Style").set_style.call_deferred(int(OS.get_environment("STILE")))


func shoot_from(eye: Vector3, target: Vector3) -> void:
	var cam := root.get_node_or_null("ShotCamera") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "ShotCamera"
		cam.fov = 60.0
		root.add_child(cam)
		cam.make_current()
	cam.look_at_from_position(eye, target)


func by_script(root_node: Node, file: String) -> Array:
	var out := []
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_script() and n.get_script().resource_path.get_file() == file:
			out.append(n)
		stack.append_array(n.get_children())
	return out


func _process(_d: float) -> bool:
	frame += 1
	if paused:
		main.get_node("Upgrades").choose(0)
	var heat = root.get_node("Heat")
	var fire = main.get_node("Wildfire")
	fire.stopped = true
	frog.invincible = true
	if frame == 2:
		heat.running = false
		if scene in ["cielo", "nuvole", "bioma", "temporale"]:
			main.next_world()
		if scene == "bioma":
			course.jump_to(int(OS.get_environment("BIOMA")))
		if scene == "nuvole":
			course.jump_to(3)
			var lanes := by_script(course, "river_lane.gd")
			for lane in lanes:
				lane.crocodile_chance = 0.5
		heat.set_value(float(OS.get_environment("HEAT")))
	if frame == 40 and scene == "portale":
		heat.set_value(100.0)
	# La funivia: aspetta che una cabina sia davanti alla rana.
	if scene == "bioma" and OS.get_environment("BIOMA") == "4" and frame >= wait and frame < wait + 900 and wait > 0:
		var passing := false
		for track in by_script(course, "rail_track.gd"):
			if track.train and absf(track.train.nose_x()) < 15.0:
				passing = true
		if not passing:
			wait += 1
	if scene == "temporale" and frame > 2:
		fire.front_z = frog.global_position.z + 14.0
	# La pattuglia: aspetta che il primo gregario sia davanti alla rana.
	if scene == "bioma" and OS.get_environment("BIOMA") == "8" and frame >= wait and frame < 2000:
		var near := false
		for formation in by_script(course, "formation.gd"):
			var planes: Array = formation.wingmen_planes()
			if not planes.is_empty() and absf(planes[0].global_position.x - frog.global_position.x) < 12.0:
				near = true
		if not near:
			wait += 1
	if frame == wait:
		if scene == "portale":
			var portals := by_script(course, "portal.gd")
			if portals.is_empty():
				print("niente teletrasporto")
				quit(1)
				return true
			var p: Node3D = portals[0]
			shoot_from(p.global_position + Vector3(-6, 7, 26), p.global_position + Vector3(0, 4, 0))
		elif scene == "temporale":
			shoot_from(frog.global_position + Vector3(6, 5, -10), frog.global_position + Vector3(0, 6, 14))
		elif scene == "bioma" and OS.get_environment("LATO") != "":
			shoot_from(frog.global_position + Vector3(-34, 16, -6), frog.global_position + Vector3(0, 6, -16))
		elif scene in ["nuvole", "bioma"]:
			shoot_from(frog.global_position + Vector3(-8, 9, 6), frog.global_position + Vector3(4, -1, -14))
		else:
			shoot_from(frog.global_position + Vector3(0, 6, 10), frog.global_position + Vector3(0, 1, -30))
	if frame == wait + 20:
		var image := root.get_texture().get_image()
		image.save_png(OS.get_environment("SHOT"))
		print("salvato " + OS.get_environment("SHOT"))
		quit()
	return false
