extends RefCounted
## Strumenti comuni ai test.
##
## I test non nominano i tipi del gioco (Car, Frog, Course...): lo script del
## test viene compilato prima che esistano gli autoload (Heat, Style), e gli
## script del gioco che li usano non si compilerebbero. I nodi si cercano per
## nome del file di script, con by_script().

var failures := 0
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  OK       " + message)
	else:
		failures += 1
		print("  FALLITO  " + message)


func finish(tree: SceneTree) -> void:
	print("%d controlli, %d falliti" % [checks, failures])
	tree.quit(1 if failures > 0 else 0)


## Carica la partita con un seme fisso e un file del record solo per i test.
static func load_main(tree: SceneTree) -> Node:
	seed(1234)
	# Anche le mosche, che hanno un generatore tutto loro: test ripetibili.
	load("res://scripts/fly.gd").rng().seed = 1234
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progressi_test.cfg"))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_test.cfg"
	main.progress_path = "user://progressi_test.cfg"
	# Niente suggerimenti (né incendio che aspetta): li prova test_hints.
	main.tutorial = false
	# Le carte della tana subito, senza la festa (la prova test_den).
	main.den_celebration_seconds = 0.0
	# Molti test cercano un fiume o una strada nel percorso del seme 1234 con
	# le sezioni corte di prima (2 ostacoli, +1 a sezione fino a 3): lo teniamo
	# fisso. test_course rimette le sezioni vere.
	var course: Node = main.get_node("Course")
	course.section_obstacles = 2
	course.section_growth_cap = 3
	tree.root.add_child(main)
	tree.current_scene = main
	# L'incendio insegue la rana: nei test che la spostano in giro va fermato
	# (test_fire lo riaccende).
	var fire: Node = main.get_node("Wildfire")
	fire.stopped = true
	fire.burn = 0.0
	fire.set_physics_process(false)
	return main


## Tutti i nodi sotto root il cui script si chiama file_name ("car.gd"...).
static func by_script(root: Node, file_name: String) -> Array:
	var found := []
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script: Script = node.get_script()
		if script and script.resource_path.get_file() == file_name:
			found.append(node)
		stack.append_array(node.get_children())
	return found


## I veicoli; state 0 = in marcia, 1 = rottame.
static func cars(root: Node) -> Array:
	return by_script(root, "car.gd")


static func place(frog: Node3D, at: Vector3) -> void:
	frog.global_position = at
	frog.velocity = Vector3.ZERO
	frog.health = frog.max_health
	frog._invulnerable_time = 0.0
	frog._stun_time = 0.0
	frog.reset_physics_interpolation()


## Una piattaforma di terreno dietro la partenza, dove il percorso non genera
## niente: le prove lì non vengono disturbate da auto, treni o tane.
static func test_ground(main: Node, center := Vector3(0, 0, 320), size := 120.0) -> void:
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 1, size)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ground.add_child(collision)
	main.add_child(ground)
	ground.global_position = center + Vector3(0, -0.5, 0)
