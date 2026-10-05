extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## Un'inquadratura di tre quarti su un bioma, con la rana in primo piano.
## SCENE: strada | fumo | bestiario (coccodrillo e tronco da vicino) | festa (l'arrivo in tana) | fiume | tana | tana_lontano | laghetto | ferrovia | aeroporto | porto.
## HEAT, SHOT.
const BIOMES := {"strada": 2, "fiume": 3, "ferrovia": 4, "tana": 5, "tana_lontano": 5, "laghetto": 5, "fumo": 2, "bestiario": 1, "festa": 5, "aeroporto": 6, "porto": 7}
var frame := 0
var main: Node
var scene := OS.get_environment("SCENE")


func _initialize() -> void:
	get_root().size = DisplayServer.window_get_size()
	seed(7)
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_shot.cfg"
	main.progress_path = "user://progressi_shot.cfg"
	root.add_child(main)
	current_scene = main


func _process(_d: float) -> bool:
	frame += 1
	var frog: Node3D = main.get_node("Frog")
	if paused:
		main.get_node("Upgrades").choose(0)
	if frame == 3:
		main.get_node("Wildfire").stopped = true
		main.get_node("Hud").visible = false
		frog.invincible = true
		var heat = root.get_node("Heat")
		heat.running = false
		heat.set_value(float(OS.get_environment("HEAT")))
		main.get_node("Course").jump_to(BIOMES[scene])
	if frame == 5:
		# Sulla striscia sicura prima del bioma, girata verso il bioma.
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.fov = 60
		cam.make_current()
		var at: Vector3 = frog.global_position + Vector3(0, 0.5, -6)
		if scene == "bestiario":
			var croc: Node3D = load("res://scripts/crocodile.gd").new()
			croc.size = Vector3(1.4, 0.8, 6.0)
			# Prima di entrare in scena: si sincronizzano con la fisica.
			croc.position = frog.global_position + Vector3(-1.5, 0.4, -5.0)
			croc.rotation.y = PI - 0.9
			main.add_child(croc)
			croc.set_physics_process(false)
			croc._set_mouth_open(true)
			var log: Node3D = load("res://scripts/river_log.gd").new()
			log.size = Vector3(1.6, 1.0, 8.0)
			log.position = frog.global_position + Vector3(3.5, 0.5, -6.0)
			log.rotation.y = 0.3
			main.add_child(log)
			log.set_physics_process(false)
			cam.look_at_from_position(frog.global_position + Vector3(-4.5, 3.0, 3.5), frog.global_position + Vector3(0.5, 0.3, -5.5))
		elif scene == "laghetto":
			# Il laghetto di destra, dall'alto e di lato.
			var pond: Vector3 = frog.global_position + Vector3(21.0, 0.0, -9.0)
			cam.look_at_from_position(pond + Vector3(-7.0, 6.0, 7.0), pond)
		elif scene == "tana_lontano":
			# Da dietro la rana, come giocando, con la tana in fondo.
			cam.look_at_from_position(frog.global_position + Vector3(0, 3.0, 30.0), frog.global_position + Vector3(0, 1.5, -12.0))
		else:
			cam.look_at_from_position(frog.global_position + Vector3(-5.5, 3.2, 4.5), at)
	if scene == "festa" and frame == 120:
		# Nella tana, con la telecamera dove sarebbe quella del gioco.
		main.den_celebration_seconds = 5.0
		for chunk in main.get_node("Course").get_children():
			if chunk.has_meta("den") and chunk.global_position.z < frog.global_position.z:
				frog.global_position = Vector3(-2.0, 0.5, chunk.global_position.z + 1.0)
				frog.velocity = Vector3.ZERO
				var cam: Camera3D = root.get_viewport().get_camera_3d()
				cam.look_at_from_position(frog.global_position + Vector3(1.5, 3.0, 7.0), frog.global_position + Vector3(4.0, 1.4, -4.0))
				break
	if scene == "fumo" and frame == 120:
		# Rottami fumanti davanti alla rana, e il fuoco a 15 m dietro.
		for car in main.find_children("*", "RigidBody3D", true, false):
			if car.has_method("become_wreck") and car.global_position.distance_to(frog.global_position) < 30.0:
				car.become_wreck()
		main.get_node("Wildfire").front_z = frog.global_position.z + 15.0
	if frame == (150 if scene == "festa" else 200):
		get_root().get_texture().get_image().save_png(OS.get_environment("SHOT"))
		print("salvato ", OS.get_environment("SHOT"))
		quit()
	return false
