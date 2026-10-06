extends SceneTree
## Il guardaroba e lo stile nuovo: cappelli e colori si sbloccano con le
## imprese, si scelgono per ogni rana e si salvano; il cappello si appende
## alla testa e copre la cuffia della paracadutista; il colore cambia la
## pelle. Lo stile Game Boy si usa solo dopo "Duemila metri" (F2 lo salta).

const Lib := preload("res://tests/lib.gd")
const PROGRESS := "user://progressi_test.cfg"

var t := Lib.new()
var main: Node
var frog: Node
var cosmetics: GDScript
var progress: GDScript
var frame := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	cosmetics = load("res://scripts/cosmetics.gd")
	progress = load("res://scripts/progress.gd")
	load("res://scripts/feats.gd").unlock_all = false


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		3:
			var style: Node = root.get_node("Style")
			t.check(not cosmetics.unlocked("hard_hat") and cosmetics.next("hat", "") == "", "senza imprese niente cappelli")
			progress.feat_done("cantiere")
			t.check(cosmetics.unlocked("hard_hat") and cosmetics.next("hat", "") == "hard_hat", "Lavori in corso sblocca l'elmetto")
			cosmetics.choose("paracadutista", "hat", "hard_hat")
			main.starting_kit = {}
			main.preview_frog("paracadutista")
			var hat: Node = frog.model.find_child("Head__hat", true, false)
			var cap: Node3D = frog.model.find_child("Head__cap", true, false)
			t.check(hat != null and hat.get_parent().name == "Head", "l'elmetto è appeso alla testa")
			t.check(cap != null and not cap.visible, "e copre la cuffia della paracadutista")
			cosmetics.choose("paracadutista", "hat", "")
			main.preview_frog("paracadutista")
			cap = frog.model.find_child("Head__cap", true, false)
			t.check(frog.model.find_child("Head__hat", true, false) == null and cap.visible, "senza cappello torna la cuffia")
			# Un colore.
			progress.feat_done("arrosto")
			cosmetics.choose("comune", "color", "charred")
			main.preview_frog("comune")
			t.check(frog.skin == "frog_charred", "la rana carbonizzata ha la pelle sua")
			progress.load_from(PROGRESS)
			t.check(cosmetics.chosen("comune").color == "charred", "la scelta si salva")
			# Un colore ancora chiuso non si usa.
			cosmetics.choose("comune", "color", "glowing")
			t.check(cosmetics.chosen("comune").color == "", "un colore chiuso non si usa")
			# La schermata delle rane.
			var panel: Node = load("res://scripts/frogs_panel.gd").new()
			root.add_child(panel)
			t.check(panel._hat_button.text.begins_with("Cappello") and panel._wardrobe_note.text.contains("3"), "il guardaroba nella schermata dice cosa manca (%s)" % panel._wardrobe_note.text)
			panel.queue_free()
			# Lo stile Game Boy.
			var gameboy: int = style.styles.size() - 1
			t.check(style.styles[gameboy].name == "Game Boy" and not style.unlocked(gameboy), "il Game Boy c'è ma è chiuso")
			t.check(style.next_unlocked(gameboy - 1) == 0, "F2 lo salta")
			progress.feat_done("duemila")
			t.check(style.unlocked(gameboy) and style.next_unlocked(gameboy - 1) == gameboy, "Duemila metri lo apre")
			var before: int = style.current
			root.get_node("Settings").set_option("style", gameboy)
			t.check(style.current == gameboy, "si sceglie nelle opzioni")
			style.set_style(before)
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://opzioni_test.cfg"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
