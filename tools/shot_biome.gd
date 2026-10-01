extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## Screenshot di aeroporto e porto. SCENE: aereo | getto | gru | caduta. HEAT, SHOT.
var frame := 0
var main: Node
var frog: Node3D
var course: Node3D
var chunk: Node3D
var subject: Node3D
var done_at := -1
var drop_seen := -1
var lit_frames := 0
var scene := OS.get_environment("SCENE")
var kind := 6 if scene in ["aereo", "getto"] else 7
var aerial := scene == "porto"
var prefix := "AIRPORT" if kind == 6 else "PORT"

func _initialize() -> void:
	get_root().size = Vector2i(1280, 720)
	seed(11)
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_shot.cfg"
	root.add_child(main)
	current_scene = main
	frog = main.get_node("Frog")
	course = main.get_node("Course")

func aim_camera(at: Vector3) -> void:
	var d := at - frog.global_position
	frog.get_node("CameraRig").rotation.y = atan2(-d.x, -d.z)

func by_script(root_node: Node, file: String) -> Array:
	var out := []
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_script() and n.get_script().resource_path.get_file() == file: out.append(n)
		stack.append_array(n.get_children())
	return out

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
		# Il blocco voluto viene creato subito, in fondo al percorso pronto.
		course._add_chunk(kind)
	if frame == 4:
		for c in course.get_children():
			if String(c.name).begins_with(prefix):
				chunk = c
		if chunk == null:
			print("niente blocco"); quit(); return false
		var back := 9.0 if kind == 7 else -0.8
		frog.global_position = Vector3(4, 0.1, chunk.get_meta("near_z") + back)
		frog.reset_physics_interpolation()
		if aerial:
			# Vista dall'alto: nastri, ombra e gru insieme.
			frog.global_position = Vector3(4, 0.1, chunk.get_meta("near_z") + 2.0)
			frog.get_node("CameraRig/Pitch").rotation.x = -0.75
			frog.get_node("CameraRig/Pitch/SpringArm3D").spring_length = 16.0
		elif kind == 7:
			# Per il porto lo sguardo si alza: deve entrare tutta la gru.
			frog.get_node("CameraRig/Pitch").rotation.x = -0.02
	if frame > 4 and done_at < 0:
		match scene:
			"aereo":
				var planes := by_script(chunk, "airplane.gd")
				for p in planes:
					var x: float = p.global_position.x * p.direction
					if x > -14.0 and x < -4.0:
						aim_camera(p.global_position + Vector3(0, 3, 0))
						frog.get_node("CameraRig").rotation.y += 0.25 * p.direction
						done_at = frame + 2
			"getto":
				var planes := by_script(chunk, "airplane.gd")
				for p in planes:
					var x: float = p.global_position.x * p.direction
					if x > -12.0 and x < 8.0 and not frog.has_meta("set"):
						frog.set_meta("set", frame)
						subject = p
			"porto":
				var crane: Node3D = by_script(chunk, "crane.gd")[0]
				# La rana davanti alla gru: la telecamera guarda verso di lei.
				frog.global_position = Vector3(crane.global_position.x + 2.0, 0.1, chunk.get_meta("near_z") + 2.0)
				frog.velocity = Vector3.ZERO
				aim_camera(Vector3(crane.global_position.x, 0, crane.global_position.z))
				# Lo screenshot prende il fotogramma già disegnato: l'ombra deve
				# essere accesa da qualche fotogramma.
				lit_frames = lit_frames + 1 if crane.is_warning() and crane._shadow.visible else 0
				if lit_frames == 3 and frame > 60:
					done_at = frame
			"gru", "caduta":
				var crane: Node3D = by_script(chunk, "crane.gd")[0]
				aim_camera(Vector3(crane.global_position.x, 7, crane.global_position.z))
				if scene == "gru" and crane.is_warning() and crane._shadow.visible and frame > 60:
					done_at = frame
				if scene == "caduta":
					if crane.phase == 2 and drop_seen < 0:
						drop_seen = frame
					if drop_seen > 0 and frame == drop_seen + 22:
						done_at = frame
	if scene == "getto" and frog.has_meta("set"):
		var p: Node3D = subject
		var f: int = frame - frog.get_meta("set")
		if f < 8:
			frog.global_position = p.to_global(Vector3(6, 0, 4)) + Vector3(0, 3.0, 0)
			frog.velocity = Vector3.ZERO
			frog.reset_physics_interpolation()
			aim_camera(p.global_position + Vector3(0, 2, 0))
		if f == 8:
			Input.action_press("jump")
			frog.glider_power.gliding = true
			frog.glider_power._unfold()
		if f == 30:
			aim_camera(p.global_position + Vector3(0, 3, 0))
		if f == 40:
			done_at = frame
	if done_at > 0 and frame == done_at:
		root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
		print("salvato " + OS.get_environment("SHOT").get_file())
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_shot.cfg"))
		quit()
	if frame > 4000:
		print("niente (%s)" % scene); quit()
	return false
