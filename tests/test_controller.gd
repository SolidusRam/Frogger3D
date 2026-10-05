extends SceneTree
## Il controller: i comandi predefiniti (A salto, B schianto, RB super salto,
## RT pugno, LT lingua); la levetta sinistra muove, la destra gira la
## telecamera; il gioco capisce quale dispositivo si sta usando e l'HUD ne
## scrive i comandi; i comandi del controller si riassegnano e si scambiano,
## anche dal pannello delle opzioni; Start mette in pausa e B riprende senza
## far piombare giù la rana; si salva tutto.

const Lib := preload("res://tests/lib.gd")
const PATH := "user://opzioni_test.cfg"

var t := Lib.new()
var main: Node
var hud: Node
var settings: Node
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	hud = main.get_node("Hud")


func _button(index: JoyButton, pressed := true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event


func _motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _physics_process(_delta: float) -> bool:
	frame += 1
	settings = root.get_node("Settings")
	match frame:
		5:
			t.check(settings.key_name("jump", true) == "A" and settings.key_name("slam", true) == "B", "A salta, B è lo schianto")
			t.check(settings.key_name("punch", true) == "RT" and settings.key_name("tongue", true) == "LT" and settings.key_name("super_jump", true) == "RB", "RT pugno, LT lingua, RB super salto")
			t.check(not settings.using_pad and hud._chips.glide._key_label.text == "Spazio", "si parte con la tastiera")
			Input.parse_input_event(_button(JOY_BUTTON_A))
		7:
			t.check(Input.is_action_pressed("jump"), "A è il salto")
			t.check(settings.using_pad and hud._chips.glide._key_label.text == "A", "premuto A, l'HUD scrive i comandi del controller")
			t.check(hud._chips.punch._key_label.text == "RT", "il pugno sul grilletto destro")
			Input.parse_input_event(_button(JOY_BUTTON_A, false))
			Input.parse_input_event(_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
		9:
			t.check(Input.is_action_pressed("punch"), "il grilletto destro è il pugno")
			Input.parse_input_event(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.0))
			# La levetta sinistra muove.
			Input.parse_input_event(_motion(JOY_AXIS_LEFT_Y, -1.0))
		11:
			var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			t.check(move.y < -0.9, "la levetta sinistra in avanti è avanti (%.2f)" % move.y)
			Input.parse_input_event(_motion(JOY_AXIS_LEFT_Y, 0.0))
			# La levetta destra gira la telecamera.
			m.yaw = main.get_node("Frog").camera_rig.rotation.y
			Input.parse_input_event(_motion(JOY_AXIS_RIGHT_X, 1.0))
		31:
			var yaw: float = main.get_node("Frog").camera_rig.rotation.y
			t.check(yaw < m.yaw - 0.5, "la levetta destra gira la telecamera (%.2f rad)" % (yaw - m.yaw))
			Input.parse_input_event(_motion(JOY_AXIS_RIGHT_X, 0.0))
			# Una tastiera premuta: si torna ai suoi nomi.
			var key := InputEventKey.new()
			key.physical_keycode = KEY_W
			key.pressed = true
			Input.parse_input_event(key)
		33:
			t.check(not settings.using_pad and hud._chips.glide._key_label.text == "Spazio", "premuto un tasto, l'HUD torna alla tastiera")
			var key := InputEventKey.new()
			key.physical_keycode = KEY_W
			Input.parse_input_event(key)
			# Riassegnare: lo schianto su X, poi il salto su X (si scambiano).
			settings.rebind("slam", _button(JOY_BUTTON_X))
			t.check(settings.key_name("slam", true) == "X" and settings.key_name("slam", false) == "Ctrl", "lo schianto su X; la tastiera resta Ctrl")
			settings.rebind("jump", _button(JOY_BUTTON_X))
			t.check(settings.key_name("jump", true) == "X" and settings.key_name("slam", true) == "A", "il salto su X: lo schianto prende A")
			t.check(not settings.can_bind_pad(_button(JOY_BUTTON_START)) and not settings.can_bind_pad(_button(JOY_BUTTON_DPAD_UP)), "Start e la croce non si assegnano")
			t.check(not settings.can_bind_pad(_motion(JOY_AXIS_LEFT_X, 1.0)), "le levette non si assegnano")
			settings.reset(true)
			t.check(settings.key_name("jump", true) == "A" and settings.key_name("slam", true) == "B", "i predefiniti rimettono A e B")
			# Start: pausa.
			Input.parse_input_event(_button(JOY_BUTTON_START))
		35:
			Input.parse_input_event(_button(JOY_BUTTON_START, false))
			t.check(paused and hud.is_paused(), "Start mette in pausa")
			t.check(hud._resume_button.text == "Riprendi (Start)", "in pausa il pulsante dice Start")
			# Le opzioni, e la lingua sul pulsante Y dalla colonna del controller.
			hud._open_options()
			var panel: Node = hud._options
			panel._key_buttons.tongue[1].pressed.emit()
			t.check(panel._key_buttons.move_forward[1].disabled, "la levetta per muoversi non si riassegna")
			Input.parse_input_event(_button(JOY_BUTTON_Y))
		37:
			Input.parse_input_event(_button(JOY_BUTTON_Y, false))
			var panel: Node = hud._options
			t.check(settings.key_name("tongue", true) == "Y" and panel._key_buttons.tongue[1].text == "Y", "dal pannello la lingua passa a Y")
			t.check(settings.key_name("tongue", false) == "E", "la lingua resta E sulla tastiera")
			# RB cambia scheda.
			var tabs: TabContainer = panel._tabs
			m.tab = tabs.current_tab
			Input.parse_input_event(_button(JOY_BUTTON_RIGHT_SHOULDER))
		39:
			Input.parse_input_event(_button(JOY_BUTTON_RIGHT_SHOULDER, false))
			t.check(hud._options._tabs.current_tab == (m.tab + 1) % 3, "RB passa alla scheda dopo")
			# B chiude le opzioni, poi riprende il gioco.
			Input.parse_input_event(_button(JOY_BUTTON_B))
		41:
			Input.parse_input_event(_button(JOY_BUTTON_B, false))
			t.check(not hud._options.visible and paused, "B chiude le opzioni e resta in pausa")
			var saved := ConfigFile.new()
			saved.load(PATH)
			t.check(saved.get_value("controller", "tongue") == "pulsante:%d" % JOY_BUTTON_Y, "i comandi del controller si salvano")
			Input.parse_input_event(_button(JOY_BUTTON_B))
		43:
			t.check(not paused, "B riprende il gioco")
			t.check(not Input.is_action_pressed("slam"), "il B che riprende non è uno schianto")
			Input.parse_input_event(_button(JOY_BUTTON_B, false))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progressi_test.cfg"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
