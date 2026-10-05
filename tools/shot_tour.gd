extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## Un'inquadratura di tre quarti su un bioma, con la rana in primo piano.
## SCENE: strada | fiume | tana | ferrovia | aeroporto | porto. HEAT, SHOT.
const BIOMES := {"strada": 2, "fiume": 3, "ferrovia": 4, "tana": 5, "aeroporto": 6, "porto": 7}
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
		cam.look_at_from_position(frog.global_position + Vector3(-5.5, 3.2, 4.5), at)
	if frame == 200:
		get_root().get_texture().get_image().save_png(OS.get_environment("SHOT"))
		print("salvato ", OS.get_environment("SHOT"))
		quit()
	return false
