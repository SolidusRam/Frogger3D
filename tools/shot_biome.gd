extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## Screenshot dell'aeroporto (il porto ha tools/shot_port.gd).
## SCENE: aereo | getto | dietro. HEAT, SHOT.
var frame := 0
var main: Node
var frog: Node3D
var course: Node3D
var chunk: Node3D
var subject: Node3D
var done_at := -1
var lit_frames := 0
var scene := OS.get_environment("SCENE")
var kind := 6
var prefix := "AIRPORT"

func _initialize() -> void:
	get_root().size = Vector2i(1280, 720)
	seed(11)
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_shot.cfg"
	main.progress_path = "user://progressi_shot.cfg"
	root.add_child(main)
	current_scene = main
	frog = main.get_node("Frog")
	course = main.get_node("Course")
	# STILE=3: lo stile grafico (vedi Style).
	if OS.get_environment("STILE") != "":
		root.get_node("Style").set_style.call_deferred(int(OS.get_environment("STILE")))

func aim_camera(at: Vector3) -> void:
	var d := at - frog.global_position
	frog.get_node("CameraRig").rotation.y = atan2(-d.x, -d.z)

## Una telecamera libera, per inquadrare con precisione.
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
		frog.global_position = Vector3(4, 0.1, chunk.get_meta("near_z") - 0.8)
		frog.reset_physics_interpolation()
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
			"dietro":
				# Dopo un po' di passaggi: rottami in giro. Rana dietro la coda.
				var planes := by_script(chunk, "airplane.gd")
				for p in planes:
					var x: float = p.global_position.x * p.direction
					if frame > 150 and x > -6.0 and x < 0.0 and not frog.has_meta("set"):
						frog.set_meta("set", frame)
						subject = p
	if scene == "getto" and frog.has_meta("set"):
		# Come un giocatore: super salto dietro il motore, deltaplano nel getto.
		var p: Node3D = subject
		if not frog.has_meta("t0"):
			frog.set_meta("t0", Engine.get_physics_frames())
			frog.global_position = p.to_global(Vector3(6, 0, 12))
			frog.global_position.y = 0.1
			frog.velocity = Vector3.ZERO
			frog.reset_physics_interpolation()
			Input.action_press("super_jump")
		var f: int = Engine.get_physics_frames() - frog.get_meta("t0")
		if f >= 2:
			Input.action_release("super_jump")
		if f >= 14:
			Input.action_press("jump")
		aim_camera(p.to_global(Vector3(4, 4, -4)))
		frog.get_node("CameraRig/Pitch").rotation.x = -0.1
		if f >= 52 and done_at < 0:
			done_at = frame + 1
	if scene == "dietro" and frog.has_meta("set"):
		# Di lato alla fiamma del motore destro, fuori dal getto e dalle strade.
		var p: Node3D = subject
		if not frog.has_meta("t0"):
			frog.set_meta("t0", Engine.get_physics_frames())
		var f: int = Engine.get_physics_frames() - frog.get_meta("t0")
		frog.global_position = p.to_global(Vector3(11.5, 0, 9))
		frog.global_position.y = 0.1
		frog.velocity = Vector3.ZERO
		frog.reset_physics_interpolation()
		shoot_from(p.to_global(Vector3(17, 5, 17)), p.to_global(Vector3(4, 1.5, 5)))
		if f >= 6 and done_at < 0:
			done_at = frame + 1
	if done_at > 0 and frame == done_at:
		root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
		print("salvato " + OS.get_environment("SHOT").get_file())
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_shot.cfg"))
		quit()
	if frame > 4000:
		print("niente (%s)" % scene); quit()
	return false
