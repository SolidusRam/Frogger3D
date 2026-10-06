extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## Screenshot delle schermate: menu | partenza | stagno | maestria | opzioni | audio | grafica | tasti | imprese | impresa | rane | gettoni | hud | carte | pausa | fine | prova.
## HEAT, SHOT; LINGUA=en per le schermate in inglese.
var frame := 0
var main: Node
var scene := OS.get_environment("SCENE")
const PROGRESS := "user://progressi_shot.cfg"


func _initialize() -> void:
	get_root().size = DisplayServer.window_get_size()
	seed(11)
	if OS.get_environment("PERF") != "":
		load("res://scripts/perf_overlay.gd").shown = true
	var progress: GDScript = load("res://scripts/progress.gd")
	progress.load_from(PROGRESS)
	progress.flies = 137
	progress.golden = 3
	progress.stat_levels = {"health": 2, "speed": 1, "choice": 1}
	progress.trials = {"explosive_gloves:0": 30.0, "uppercut:0": 12.0, "slam:1": 3.0}
	progress.save()
	if scene in ["menu", "stagno", "maestria", "partenza", "opzioni", "audio", "grafica", "tasti", "imprese", "rane"]:
		var menu: Node = load("res://scenes/menu.tscn").instantiate()
		menu.progress_path = PROGRESS
		menu.record_path = "user://record_shot.cfg"
		root.add_child(menu)
		current_scene = menu
		return
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_shot.cfg"
	main.progress_path = PROGRESS
	root.add_child(main)
	current_scene = main


func _process(_d: float) -> bool:
	frame += 1
	# La lingua dopo che Settings ha letto le opzioni, senza salvarla.
	if frame == 1 and OS.get_environment("LINGUA") != "":
		var settings: Node = root.get_node("Settings")
		settings.language = OS.get_environment("LINGUA")
		settings.apply()
	if frame == 2 and main:
		var heat = root.get_node("Heat")
		heat.value = float(OS.get_environment("HEAT"))
		heat.changed.emit(heat.value, heat.level())
		main.get_node("Wildfire").stopped = true
	if frame == 10:
		match scene:
			"stagno", "maestria":
				current_scene._open_pond()
				if scene == "maestria":
					var tabs: TabContainer = current_scene._pond.find_children("*", "TabContainer", true, false)[0]
					tabs.current_tab = 1
			"opzioni", "audio", "grafica", "tasti":
				current_scene._open_options()
				var tabs: TabContainer = current_scene._options.find_children("*", "TabContainer", true, false)[0]
				tabs.current_tab = ["opzioni", "audio", "grafica", "tasti"].find(scene)
			"imprese":
				var feats: GDScript = load("res://scripts/feats.gd")
				for id in ["boomerang", "acrobata", "fuochi", "arrosto"]:
					load("res://scripts/progress.gd").feats[id] = true
				current_scene._open_feats()
			"rane":
				load("res://scripts/progress.gd").feats["tana5"] = true
				current_scene._open_frogs()
			"impresa":
				main.get_node("Hud").show_feat("Boomerang", "Rana velenosa", false)
			"carte":
				main.offer_upgrade()
			"gettoni":
				load("res://scripts/feats.gd").unlock_all = true
				main.get_node("Upgrades").reset_tokens()
				main.offer_upgrade()
			"pausa":
				main.get_node("Hud").pause()
			"fine":
				main.get_node("Frog").take_hit(1000, Vector3.ZERO)
			"prova":
				for child in main.get_children():
					if child.get_script() and child.get_script().resource_path.ends_with("test_mode.gd"):
						child._set_open(true)
			"hud":
				var upgrades: Node = main.get_node("Upgrades")
				for id in ["tongue", "explosive_gloves", "thermals", "waterproof", "punch_power", "punch_power", "tough_skin"]:
					upgrades.apply(id)
				main.get_node("Hud").show_equipment(upgrades)
				main.add_flies(23)
				main.add_golden(1)
				var frog: Node = main.get_node("Frog")
				frog.super_jump_power.cooldown_left = frog.super_jump_power.cooldown * 0.6
				frog.take_hit(30, Vector3.ZERO)
				main.get_node("Wildfire").front_z = frog.global_position.z + 12.0
	if scene == "menu" and frame == 45 and OS.get_environment("ANGLE") != "":
		current_scene.get_child(0).get_node("Frog/CameraRig").rotation.y = float(OS.get_environment("ANGLE"))
	if scene == "partenza" and frame == 60:
		current_scene._play()
	if frame == (90 if scene == "partenza" else 50):
		get_root().get_texture().get_image().save_png(OS.get_environment("SHOT"))
		print("salvato ", OS.get_environment("SHOT"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_shot.cfg"))
		quit()
	return false
