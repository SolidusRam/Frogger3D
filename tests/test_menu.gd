extends SceneTree
## La cornice: Esc mette in pausa e riprende; abbandonare la run salva le
## mosche e porta al menu; nel menu il calore è fermo e lo stile non tocca la
## partita che non c'è più; con "Più scelta" la tana mostra quattro carte; il
## rimborso dello stagno chiede conferma; da morta la rana non raccoglie più
## mosche.

const Lib := preload("res://tests/lib.gd")
const PROGRESS := "user://progressi_test.cfg"

var t := Lib.new()
var main: Node
var hud: Node
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	hud = main.get_node("Hud")


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _physics_process(_delta: float) -> bool:
	frame += 1
	var heat: Node = root.get_node("Heat")
	var progress: GDScript = load("res://scripts/progress.gd")
	match frame:
		5:
			# Più scelta: quattro carte, e il tasto 4 sceglie la quarta.
			main.get_node("Upgrades").offer_size = 4
			main.offer_upgrade()
			var shown := 0
			for button in hud._offer_buttons:
				shown += 1 if button.visible else 0
			t.check(shown == 4, "con Più scelta la tana mostra quattro carte (%d)" % shown)
			m.fourth = main.get_node("Upgrades").current_offer[3]
			var key := InputEventKey.new()
			key.physical_keycode = KEY_4
			key.pressed = true
			Input.parse_input_event(key)
		8:
			var upgrades: Node = main.get_node("Upgrades")
			var taken: bool = m.fourth in upgrades.slots.values() or upgrades.stacks.has(m.fourth)
			t.check(taken and not paused, "il tasto 4 sceglie la quarta carta")
			# Esc: pausa.
			_press("pause")
		10:
			t.check(paused and hud.is_paused(), "Esc mette in pausa")
			m.heat = heat.value
		40:
			t.check(is_equal_approx(heat.value, m.heat), "in pausa il calore non sale")
			_press("pause")
		42:
			t.check(not paused and not hud.is_paused(), "Esc di nuovo riprende")
			# Mosche raccolte, poi si abbandona dalla pausa.
			main.add_flies(7)
			_press("pause")
		44:
			hud._pause.find_children("*", "Button", true, false)[1].pressed.emit()
			m.at = frame
		60:
			t.check(current_scene.name == "Menu", "abbandonare la run porta al menu")
			progress.load_from(PROGRESS)
			t.check(progress.flies == 7, "abbandonando, le mosche raccolte restano (%d)" % progress.flies)
			m.heat = heat.value
		150:
			t.check(heat.value == m.heat and not heat.running, "nel menu il calore non sale")
			# Lo stile nel menu: niente errori sui nodi della partita (li
			# controlla run.sh).
			heat.add(50.0)
			var style: Node = root.get_node("Style")
			style.set_style((style.current + 1) % style.styles.size())
		200:
			# Lo stagno: il rimborso chiede conferma.
			progress.add_flies(100)
			progress.buy_stat("health")
			var pond: Node = load("res://scripts/pond.gd").new()
			current_scene.add_child(pond)
			pond._refund_button.pressed.emit()
			t.check(progress.level("health") == 1, "il primo clic sul rimborso non rimborsa")
			pond._refund_button.pressed.emit()
			t.check(progress.level("health") == 0 and progress.flies == 107, "il secondo clic rimborsa")
			pond.queue_free()
			# Una partita nuova: il calore riparte e lo stile si ricollega.
			change_scene_to_file("res://scenes/main.tscn")
		215:
			t.check(heat.running, "una run nuova fa ripartire il calore")
			main = current_scene
			main.test_run = true
			var frog: Node3D = main.get_node("Frog")
			frog.take_hit(10000, Vector3.ZERO)
			m.flies = main.run_flies
			main.add_flies(5)
			main.add_golden(1)
			t.check(main.run_flies == m.flies and main.run_golden == 0, "da morta la rana non raccoglie più mosche")
			t.check(main.get_node("Hud")._game_over_text.text.contains("Run di prova"), "la fine di una run di prova dice che le mosche non contano")
		220:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
