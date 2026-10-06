extends SceneTree
## Le rane: la comune c'è dall'inizio, le altre con la loro impresa; ognuna
## parte col suo attrezzo, la sua pelle e il suo pro e contro; la scelta si
## salva, si fa dal menu (la rana sullo sfondo cambia subito) e vale per la
## run che parte.

const Lib := preload("res://tests/lib.gd")
const PROGRESS := "user://progressi_test.cfg"

var t := Lib.new()
var main: Node
var frog: Node
var upgrades: Node
var frogs: GDScript
var feats: GDScript
var progress: GDScript
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")
	frogs = load("res://scripts/frogs.gd")
	feats = load("res://scripts/feats.gd")
	progress = load("res://scripts/progress.gd")
	feats.unlock_all = false


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		3:
			t.check(frogs.unlocked("comune") and not frogs.unlocked("raganella") and not frogs.unlocked("rospo"), "all'inizio c'è solo la comune")
			progress.frog = "raganella"
			t.check(frogs.selected() == "comune", "una rana chiusa non si può usare: si gioca con la comune")
			progress.feat_done("tana5")
			t.check(frogs.unlocked("raganella") and frogs.selected() == "raganella", "l'impresa Cinque tane sblocca la raganella")
			# La raganella: molle, pelle sua, salto alto, poca vita.
			main.starting_kit = {}
			var jump: float = frog.jump_height
			main.preview_frog("raganella")
			main._apply_frog_mods()
			t.check(upgrades.slots.springs == "base" and not frog.punch_power.enabled, "la raganella parte con le molle e senza pugno")
			t.check(frog.skin == "frog_tree", "ha la sua pelle")
			t.check(frog._palette.get("eye") == "eye_red" and frog.model.find_child("FootL__pads", true, false) != null, "la raganella ha gli occhi rossi e le ventose sulle dita")
			t.check(frog.max_health == 70 and is_equal_approx(frog.jump_height, jump * 1.6), "70 di vita e salto più alto")
			# La rana di fiume: la pelle impermeabile, e il colore dell'acqua.
			main.preview_frog("fiume")
			t.check(upgrades.slots.body == "waterproof" and frog.waterproof and frog._palette.get("frog") == "frog_wet", "la rana di fiume parte impermeabile, del colore dell'acqua")
			# La paracadutista: la cuffia appesa alla testa.
			main.preview_frog("paracadutista")
			var cap: Node = frog.model.find_child("Head__cap", true, false)
			t.check(cap != null and cap.get_parent().name == "Head" and frog.model.find_child("FootL__pads", true, false) == null, "la paracadutista ha la cuffia sulla testa, e le ventose se ne sono andate")
			# Il rospo: niente.
			main.preview_frog("rospo")
			t.check(frog.model.scale.x > 1.1 and frog._palette.get("frog_spot") == "wart", "il rospo è più tozzo, con le macchie marroni")
			t.check(upgrades.slots.values().all(func(item: String) -> bool: return item == ""), "il rospo parte senza attrezzi")
			# La schermata.
			var panel: Node = load("res://scripts/frogs_panel.gd").new()
			root.add_child(panel)
			var locked: Node = panel._grid.get_node("rospo")
			var button: Button = locked.find_children("*", "Button", true, false)[0]
			var texts: Array = locked.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
			t.check(button.disabled and texts.any(func(text: String) -> bool: return text.contains("Pacifista")), "una rana chiusa dice quale impresa la sblocca")
			panel._choose("comune")
			progress.load_from(PROGRESS)
			t.check(progress.frog == "comune", "la scelta si salva")
			panel.queue_free()
			# Dal menu: la rana sullo sfondo cambia subito.
			change_scene_to_file("res://scenes/menu.tscn")
		10:
			var menu := current_scene
			t.check(menu._frog_button.text == "Rana: Comune", "il menu dice la rana scelta (%s)" % menu._frog_button.text)
			# L'anteprima: una rana chiusa sullo sfondo è una silhouette.
			menu._frogs.previewed.emit("rospo")
			t.check(menu._game.frog.silhouette and menu._game.frog_kind == "rospo" and menu._preview_label.text.contains("?"), "una rana chiusa in anteprima è una silhouette")
			menu._frogs.previewed.emit("raganella")
			t.check(not menu._game.frog.silhouette and menu._game.frog_kind == "raganella", "una aperta si vede coi suoi colori")
			menu._frogs.closed.emit()
			t.check(not menu._preview_label.visible and menu._game.frog_kind == "comune", "chiusa la scelta torna la rana scelta")
			menu._frogs._choose("raganella")
			t.check(menu._game.upgrades.slots.springs == "base" and menu._game.frog.skin == "frog_tree", "scelta dal menu, la raganella compare sullo sfondo")
			t.check(menu._frog_button.text == "Rana: Raganella", "e il menu la nomina")
			menu._play()
			m.menu = menu
		# Dopo la dissolvenza del menu (0,3 s): le sue scritte non ci sono più.
		45:
			# Dalla pausa le opzioni non toccano più il menu (le sue scritte non
			# ci sono più) né la rana della run.
			var settings: Node = root.get_node("Settings")
			settings.set_option("unlock_everything", true)
			settings.set_option("language", 1)
			settings.set_option("language", 0)
			settings.set_option("unlock_everything", false)
			var game: Node = current_scene.get_child(0)
			t.check(game.frog_kind == "raganella" and game.upgrades.slots.springs == "base", "cambiare le opzioni durante la run non cambia la rana")
			t.check(game.frog.max_health >= 70 and game.frog.max_health < 100 and game.frog_kind == "raganella", "la run parte con la raganella (vita %d)" % game.frog.max_health)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
