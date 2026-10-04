extends SceneTree
## Strumento per gli screenshot (vedi tools/screenshot.sh), non fa parte del gioco.
## L'annuncio dei gradini: il calore passa la soglia e l'HUD lo dice.
## SCENE: soglia. HEAT è il calore di partenza (sotto la soglia). SHOT.
var frame := 0
var main: Node
var heat: Node

func _initialize() -> void:
	get_root().size = Vector2i(1280, 720)
	seed(3)
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_shot.cfg"
	root.add_child(main)
	current_scene = main
	heat = root.get_node("Heat")

func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		heat.add(float(OS.get_environment("HEAT")) - heat.value)
		root.get_node("Style").set_style(1)
	if frame == 40:
		heat.add(heat.STEP_LEVEL * 20.0 + 1.0 - heat.value)
	if frame == 70:
		root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
		print("salvato " + OS.get_environment("SHOT").get_file())
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_shot.cfg"))
		quit()
	return false
