extends SceneTree
## Le imprese: il mazzo parte ridotto (le carte e le fusioni da sbloccare non
## escono nelle tane); un'impresa fatta si salva subito, si annuncia (dicendo
## se quello che sblocca arriva più avanti) e apre la sua carta; in una run di
## prova non se ne fanno; la schermata le mostra, le segrete coperte.

const Lib := preload("res://tests/lib.gd")
const PROGRESS := "user://progressi_test.cfg"

var t := Lib.new()
var main: Node
var hud: Node
var frog: Node3D
var upgrades: Node
var feats: GDScript
var progress: GDScript
var frame := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	hud = main.get_node("Hud")
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")
	feats = load("res://scripts/feats.gd")
	progress = load("res://scripts/progress.gd")
	feats.unlock_all = false


func _offered(times: int) -> Dictionary:
	var offered := {}
	for i in times:
		for id in upgrades.make_offer():
			offered[id] = true
	return offered


func _physics_process(_delta: float) -> bool:
	frame += 1
	var tracker: Node = main.get_node("Feats")
	match frame:
		3:
			var offered := _offered(300)
			t.check(not offered.has("long_glove") and not offered.has("slam"), "guantone a molla e schianto non escono finché non si sbloccano")
			t.check(offered.has("explosive_gloves") and offered.has("uppercut") and offered.has("trampoline") and offered.has("thermals") and offered.has("tongue"), "il mazzo iniziale sì")
			# Napalm pronta ma chiusa.
			upgrades.apply("explosive_gloves")
			upgrades.apply("thermals")
			t.check(not upgrades.make_offer().has("napalm"), "una fusione pronta ma da sbloccare non si offre")
			# Una run di prova non fa imprese.
			main.test_run = true
			feats.note(&"car_hit", 1.0)
			t.check(not feats.done("boomerang"), "in una run di prova niente imprese")
			main.test_run = false
			# Boomerang: la rana investita da un'auto che aveva colpito.
			feats.note(&"car_hit", 0.0)
			t.check(not feats.done("boomerang"), "un'auto qualsiasi non basta")
			feats.note(&"car_hit", 1.0)
			t.check(feats.done("boomerang"), "investita dall'auto che aveva colpito: Boomerang")
			t.check(hud.feat_text().contains("Boomerang") and hud.feat_text().contains("Rana velenosa") and not hud.feat_text().contains("più avanti"), "l'impresa si annuncia con quello che sblocca (%s)" % hud.feat_text())
			t.check(feats.card_available("poison"), "e la rana velenosa entra nel mazzo")
			# Un gettone: si sblocca e lo dice.
			feats.note(&"container_on_car")
			t.check(hud.feat_text().contains("Rilancia") and not hud.feat_text().contains("più avanti"), "Consegna sblocca il gettone Rilancia (%s)" % hud.feat_text())
			# Fuochi d'artificio: la Napalm entra nel mazzo.
			feats.note(&"explosion", 2.0)
			t.check(not feats.done("fuochi"), "due rottami non bastano")
			feats.note(&"explosion", 3.0)
			t.check(feats.done("fuochi") and upgrades.make_offer().has("napalm"), "un'esplosione che ne distrugge tre sblocca la Napalm, che ora si offre")
			t.check(hud.feat_text().contains("Napalm") and not hud.feat_text().contains("più avanti"), "la Napalm c'è già nel gioco")
			# Pugno al volo: la rana in aria (al passo dopo non tocca terra).
			frog.global_position.y += 6.0
		5:
			var tracker_now: Node = main.get_node("Feats")
			t.check(not frog.is_on_floor(), "la rana è in aria")
			var cars := Array([], TYPE_OBJECT, &"RigidBody3D", load("res://scripts/car.gd"))
			cars.append(Lib.cars(main)[0])
			frog.punched.emit(cars)
			t.check(feats.done("acrobata") and feats.card_available("long_glove"), "un pugno in aria sblocca il guantone a molla")
			# Le tane: cinque tane, senza pugni, col fuoco a 3 m.
			tracker_now._fire_gap = 3.0
			main.get_node("Course").den_reached.emit(5, 300.0)
			t.check(feats.done("tana5") and feats.done("pacifista") and feats.done("pelo"), "tana 5, senza pugni, col fuoco vicino: tre imprese")
			# Abbattuta in volo.
			t.check(main.get_node("Course").next_den_distance() > 0.0, "si sa quanto manca alla prossima tana")
			# Salvate subito.
			progress.load_from(PROGRESS)
			t.check(feats.done("boomerang") and feats.done("fuochi") and feats.count_done() == 7, "le imprese si salvano subito (%d)" % feats.count_done())
			# "Tutto sbloccato" (per provare): rane e carte aperte, la run è una prova.
			var settings: Node = root.get_node("Settings")
			t.check(not feats.card_available("anchor_tongue") and not load("res://scripts/frogs.gd").unlocked("camaleonte"), "senza l'opzione la lingua-ancora e il camaleonte sono chiusi")
			settings.set_option("unlock_everything", true)
			t.check(feats.card_available("anchor_tongue") and load("res://scripts/frogs.gd").unlocked("camaleonte"), "con Tutto sbloccato tutto è aperto")
			main._mark_unlocked_test()
			t.check(main.test_run, "e la run è una prova")
			settings.set_option("unlock_everything", false)
			main.test_run = false
			t.check(not feats.card_available("anchor_tongue"), "spento, torna com'era")
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://opzioni_test.cfg"))
			# La schermata.
			var panel: Node = load("res://scripts/feats_panel.gd").new()
			root.add_child(panel)
			t.check(panel._count.text == "7 / %d" % feats.ALL.size(), "la schermata conta le imprese fatte (%s)" % panel._count.text)
			var secret: Node = panel.find_child("arrosto", true, false)
			var texts: Array = secret.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
			t.check("???" in texts and not "Arrosto" in texts, "le segrete non fatte restano coperte")
			var shown: Node = panel.find_child("boomerang", true, false)
			texts = shown.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
			t.check("Boomerang" in texts and "Fatta" in texts, "quelle fatte si vedono come fatte")
			panel.queue_free()
		7:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
