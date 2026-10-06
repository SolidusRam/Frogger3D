extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## Primo piano della rana. SCENE: fronte | lato | dietro | pugno | salto |
## caduta | boxe | guscio (di spalle, col guscio e le molle a razzo). SHOT.
## RANA=raganella|paracadutista|fiume|camaleonte|rospo: quella rana (vedi
## Frogs), con i suoi accessori. CAPPELLO, COLORE, STILE: guardaroba e stile.
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
		if OS.get_environment("RANA") != "":
			main.preview_frog(OS.get_environment("RANA"))
		# CAPPELLO=hard_hat, COLORE=charred, STILE=3 (vedi Cosmetics, Style).
		if OS.get_environment("CAPPELLO") != "":
			frog.set_hat(OS.get_environment("CAPPELLO"))
		if OS.get_environment("COLORE") != "":
			frog.skin = load("res://scripts/cosmetics.gd").palette_of(OS.get_environment("COLORE"))
		if OS.get_environment("STILE") != "":
			root.get_node("Style").set_style(int(OS.get_environment("STILE")))
		main.get_node("Upgrades").apply("explosive_gloves")
		if scene == "guscio":
			main.get_node("Upgrades").apply("shell")
			main.get_node("Upgrades").apply("rocket_springs")
	if frame == 30:
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.fov = 40
		cam.make_current()
		var at: Vector3 = frog.global_position + Vector3(0, 0.4, 0)
		var eye: Vector3 = {"fronte": Vector3(1.0, 0.9, -2.6), "lato": Vector3(2.8, 0.7, 0.2), "dietro": Vector3(-1.4, 1.5, 2.4),
			"pugno": Vector3(2.4, 1.0, -1.6), "salto": Vector3(3.2, 0.6, 0.0), "caduta": Vector3(3.2, 0.6, 0.0),
			"boxe": Vector3(1.6, 0.9, -2.4), "guscio": Vector3(-1.8, 1.4, 1.8)}[scene]
		cam.look_at_from_position(at + eye + (Vector3.UP * 2.0 if scene in ["salto", "caduta"] else Vector3.ZERO), at + (Vector3.UP * 2.0 if scene in ["salto", "caduta"] else Vector3.ZERO))
		if scene == "boxe":
			frog.animator._idle_time = 5.0
	# Ferma a mezz'aria, mentre sale o scende.
	if scene in ["salto", "caduta"] and frame >= 30:
		frog.global_position.y = 2.0
		frog.velocity.y = 9.0 if scene == "salto" else -7.0
	if frame == 44 and scene == "pugno":
		frog.punch()
	if frame == 46:
		get_root().get_texture().get_image().save_png(OS.get_environment("SHOT"))
		print("salvato ", OS.get_environment("SHOT"))
		quit()
	return false
