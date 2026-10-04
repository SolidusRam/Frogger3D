extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## Screenshot del porto. SCENE: panorama | nave | caccia. HEAT, SHOT.
##   panorama: dall'alto, la corsia con la nave e una gru che avvisa
##   nave: la rana sul ponte, tra i container
##   caccia: la rana sul ponte e la gru bloccata sopra di lei (calore 3+)
var frame := 0
var main: Node
var frog: Node3D
var course: Node3D
var chunk: Node3D
var lane: Node3D
var ship: Node3D
var done_at := -1
var lit_frames := 0
var scene := OS.get_environment("SCENE")

func _initialize() -> void:
	get_root().size = Vector2i(1280, 720)
	seed(5)
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_shot.cfg"
	main.progress_path = "user://progressi_shot.cfg"
	root.add_child(main)
	current_scene = main
	frog = main.get_node("Frog")
	course = main.get_node("Course")

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

## La nave più vicina al centro della zona di gioco.
func central_ship() -> Node3D:
	var best: Node3D = null
	for s in lane.ships():
		if best == null or absf(s.global_position.x) < absf(best.global_position.x):
			best = s
	return best

## Mette la rana su una casella vuota della nave, la più vicina alla banchina.
func board(s: Node3D) -> void:
	for row in [3, 2, 1, 0]:
		for col in [2, 1, 3, 0, 4]:
			var cell := Vector2i(col, row)
			if s.level(cell) == 0:
				frog.global_position = s.to_global(s.cell_position(cell, 0)) + Vector3(0, -1.2, 0)
				frog.velocity = Vector3.ZERO
				frog.reset_physics_interpolation()
				return

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
		course._add_chunk(7)
	if frame == 4:
		for c in course.get_children():
			if String(c.name).begins_with("PORT"):
				chunk = c
		lane = by_script(chunk, "ship_lane.gd")[0]
		frog.global_position = Vector3(0, 0.1, chunk.get_meta("near_z") - 2.0)
		frog.reset_physics_interpolation()
	if frame > 4 and done_at < 0:
		match scene:
			"panorama":
				var near_z: float = chunk.get_meta("near_z")
				shoot_from(Vector3(-4, 17, near_z + 9), Vector3(4, 0, lane.global_position.z - 2))
				lit_frames = lit_frames + 1 if lane.cranes.any(func(c): return c.is_warning() and c._shadow.visible) else 0
				if lit_frames >= 2 and frame > 90:
					done_at = frame
			"nave":
				if frame == 40:
					ship = central_ship()
					board(ship)
				if frame > 40 and frame < 60:
					shoot_from(frog.global_position + Vector3(-3, 11, 8), frog.global_position + Vector3(2, 0, -3))
				if frame == 60:
					done_at = frame
			"caccia":
				if frame == 40:
					ship = central_ship()
					board(ship)
				if frame > 40:
					shoot_from(frog.global_position + Vector3(-5, 13, 9), frog.global_position + Vector3(0, 1.0, -1))
					var locked: bool = lane.cranes.any(func(c): return c.aimed and c.is_locked())
					lit_frames = lit_frames + 1 if locked else 0
					if lit_frames >= 1:
						done_at = frame
	if done_at > 0 and frame == done_at:
		root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
		print("salvato " + OS.get_environment("SHOT").get_file())
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_shot.cfg"))
		quit()
	if frame > 3000:
		print("niente (%s)" % scene); quit()
	return false
