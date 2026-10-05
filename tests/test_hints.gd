extends SceneTree
## I suggerimenti del primo minuto: "muoviti" compare all'inizio coi tasti
## giusti (anche passando al controller) e l'incendio aspetta; muovendosi
## sparisce e il fuoco parte. Il primo potere fa comparire la regola del
## calore, davanti agli altri; l'incendio vicino fa comparire la tana, che lo
## esegue. Eseguiti in due run, non compaiono più. Alla fine della corsa, con
## le mosche, lo stagno è in evidenza finché non lo si apre. "Rivedi i
## suggerimenti" li rimette.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var hud: Node
var frog: Node3D
var fire: Node
var hints: Node
var progress: GDScript
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	hud = main.get_node("Hud")
	frog = main.get_node("Frog")
	fire = main.get_node("Wildfire")
	progress = load("res://scripts/progress.gd")


func _physics_process(_delta: float) -> bool:
	frame += 1
	var settings: Node = root.get_node("Settings")
	match frame:
		1:
			main.tutorial = true
			main.start_hints()
			hints = main.get_node("Hints")
		2:
			t.check(fire.waiting, "nella prima run l'incendio aspetta")
		60:
			t.check(hints._current == "move" and hud.hint_text().contains("WASD") and hud.hint_text().contains("muoviti"), "all'inizio: WASD per muoversi (%s)" % hud.hint_text())
			# Passando al controller il suggerimento si riscrive.
			settings.using_pad = true
			settings.changed.emit()
			t.check(hud.hint_text().contains("Levetta sinistra"), "col controller dice la levetta (%s)" % hud.hint_text())
			settings.using_pad = false
			settings.changed.emit()
			Lib.place(frog, frog.global_position + Vector3(0, 0, -12))
		62:
			t.check(hints._current == "" and not fire.waiting, "dopo 12 m il suggerimento è eseguito e l'incendio parte")
			t.check(progress.hint_count("move") == 1, "conta come eseguito una volta")
			# Il primo potere: la regola del calore.
			frog.power_used.emit(&"punch")
			m.at = frame
		140:
			t.check(hints._current == "heat" and hud.hint_text().contains("calore non scende mai"), "dopo il primo potere: il calore non scende mai")
			# L'incendio vicino: passa davanti agli altri.
			fire.front_z = frog.global_position.z + 20.0
		700:
			t.check(progress.hint_count("heat") == 1, "il calore, letto, conta come eseguito")
			t.check(hints._current == "fire" and hud.hint_text().contains("tana"), "l'incendio vicino: raggiungi la tana (%s)" % hud.hint_text())
			main.get_node("Course").den_reached.emit(1, 60.0)
		702:
			t.check(hints._current != "fire" and progress.hint_count("fire") == 1, "la tana raggiunta esegue il suggerimento")
			# Una seconda run in cui si muove: "muoviti" è ritirato.
			progress.hint_done("move")
			hints.queue_free()
			fire.waiting = false
		704:
			var again: Node = load("res://scripts/hints.gd").new()
			main.add_child(again)
			again.setup(main)
			hints = again
			t.check(not fire.waiting and not "move" in again._queue, "eseguito in due run, muoviti non compare più e l'incendio non aspetta")
			# La fine della corsa con le mosche in tasca.
			main.run_flies = 4
			frog.take_hit(100000, Vector3.ZERO)
		710:
			t.check(hud._pond_note.visible and hud._pond_note.text.contains("stagno"), "a fine corsa, con le mosche, lo stagno è in evidenza")
			hud._open_pond()
			t.check(not hud._pond_note.visible and progress.hint_count("pond") == 1, "aprire lo stagno lo esegue")
			# Rivedi i suggerimenti.
			progress.reset_hints()
			t.check(progress.hint_count("move") == 0 and progress.hint_count("heat") == 0, "rivedere i suggerimenti li rimette tutti")
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progressi_test.cfg"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
