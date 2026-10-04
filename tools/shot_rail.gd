extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## Screenshot della ferrovia. SCENE: arrivo | passaggio | tetto. HEAT, SHOT.
var frame := 0
var main: Node
var frog: Node3D
var course: Node3D
var track: Node3D
var chunk: Node3D
var done_at := -1
var scene := OS.get_environment("SCENE")

func _initialize() -> void:
	get_root().size = Vector2i(1280, 720)
	seed(7)
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_shot.cfg"
	main.progress_path = "user://progressi_shot.cfg"
	root.add_child(main)
	current_scene = main
	frog = main.get_node("Frog")
	course = main.get_node("Course")

func _process(_d: float) -> bool:
	frame += 1
	if paused:
		main.get_node("Upgrades").choose(0)
	if frame == 2:
		var heat = root.get_node("Heat")
		heat.value = float(OS.get_environment("HEAT"))
		heat.changed.emit(heat.value, heat.level())
		var style = root.get_node("Style")
		style.phase = style.PHASE_BY_LEVEL[heat.level()]
		style.set_style(1)
		course._add_chunk(4) # una ferrovia, creata subito in fondo al percorso pronto
	if frame == 4:
		for c in course.get_children():
			if String(c.name).begins_with("RAIL"):
				chunk = c
		track = chunk.get_children().filter(func(n): return n.has_method("is_warning"))[0]
		for other in chunk.get_children().filter(func(n): return n.has_method("is_warning")):
			other._timer = 999.0
		track._timer = 0.05
		frog.global_position = Vector3(6, 0.1, chunk.get_meta("near_z") - 0.8)
		frog.reset_physics_interpolation()
		var yaw: float = {"arrivo": 1.05, "passaggio": 0.35, "tetto": -1.3}[scene] * track.direction
		frog.get_node("CameraRig").rotation.y = yaw
	if frame > 4 and done_at < 0 and track.train:
		var dir: float = track.direction
		var nose: float = track.train.nose_x() * dir
		if scene == "arrivo" and nose > -52.0:
			done_at = frame
		elif scene == "passaggio" and nose > 6.0 * dir + 14.0:
			done_at = frame
		elif scene == "tetto" and track.train._wagons[1].global_position.x * dir > -30.0 and not frog.has_meta("aboard"):
			var wagon: Node3D = track.train._wagons[1]
			var top: float = 0.7 + (wagon.get_child(0) as CollisionShape3D).shape.size.y
			frog.global_position = wagon.global_position + Vector3(0, top + 0.05, 0)
			frog.velocity = Vector3.ZERO
			frog.reset_physics_interpolation()
			frog.set_meta("aboard", true)
			done_at = frame + 25
	if done_at > 0 and frame == done_at:
		var img := root.get_texture().get_image()
		img.save_png(OS.get_environment("SHOT"))
		print("salvato %s (binari: %d, verso %+d)" % [OS.get_environment("SHOT").get_file(), chunk.get_children().filter(func(n): return n.has_method("is_warning")).size(), track.direction])
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_shot.cfg"))
		quit()
	if frame > 3000:
		print("niente treno"); quit()
	return false
