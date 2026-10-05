extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## Primo piano della rana. SCENE: fronte | lato | dietro | pugno. SHOT.
var frame := 0
var main: Node
var scene := OS.get_environment("SCENE")


func _initialize() -> void:
	get_root().size = DisplayServer.window_get_size()
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_shot.cfg"
	main.progress_path = "user://progressi_shot.cfg"
	root.add_child(main)
	current_scene = main


func _process(_d: float) -> bool:
	frame += 1
	var frog: Node3D = main.get_node("Frog")
	if frame == 5:
		main.get_node("Wildfire").stopped = true
		main.get_node("Hud").visible = false
		main.get_node("Upgrades").apply("explosive_gloves")
	if frame == 30:
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.fov = 40
		cam.make_current()
		var at: Vector3 = frog.global_position + Vector3(0, 0.4, 0)
		var eye: Vector3 = {"fronte": Vector3(1.0, 0.9, -2.6), "lato": Vector3(2.8, 0.7, 0.2), "dietro": Vector3(-1.4, 1.5, 2.4), "pugno": Vector3(2.4, 1.0, -1.6)}[scene]
		cam.look_at_from_position(at + eye, at)
	if frame == 44 and scene == "pugno":
		frog.punch()
	if frame == 46:
		get_root().get_texture().get_image().save_png(OS.get_environment("SHOT"))
		print("salvato ", OS.get_environment("SHOT"))
		quit()
	return false
