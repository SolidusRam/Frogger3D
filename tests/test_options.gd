extends SceneTree
## Le opzioni: i volumi arrivano ai bus (e quello degli effetti convive col
## mondo ovattato); i tasti si riassegnano, si scambiano, si vedono nell'HUD e
## nei testi delle carte; la scossa si può togliere; tutto si salva e si
## ricarica; il pannello cambia le opzioni e riassegna i tasti; dalla pausa si
## aprono e Esc le chiude senza riprendere il gioco.

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


func _key(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	# Come un tasto vero: fisico e logico.
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


func _bus_db(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func _physics_process(_delta: float) -> bool:
	frame += 1
	settings = root.get_node("Settings")
	match frame:
		5:
			t.check(settings.path == PATH, "nei test le opzioni hanno un file loro")
			# Volumi: a metà corsa -12 dB (il cursore va al quadrato).
			settings.set_option("effects_volume", 0.5)
			settings.set_option("master_volume", 1.0)
			t.check(absf(_bus_db("Interfaccia") + 12.04) < 0.1, "effetti a metà: l'interfaccia a -12 dB (%.1f)" % _bus_db("Interfaccia"))
			t.check(absf(_bus_db("Effetti") + 12.04) < 0.1, "effetti a metà: il mondo a -12 dB (%.1f)" % _bus_db("Effetti"))
			t.check(absf(_bus_db("Master")) < 0.01, "volume generale pieno: 0 dB")
			settings.set_option("music_volume", 0.0)
			t.check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica")), "musica a zero: il bus tace")
			# Il mondo ovattato si somma al volume scelto (l'ovattato va in
			# tempo reale: qui lo si mette già pieno).
			var sfx: Node = root.get_node("Sfx")
			sfx._muffle = 1.0
			sfx._muffle_target = 1.0
			settings.apply()
			t.check(absf(_bus_db("Effetti") + 12.04 + 16.0) < 0.2, "ovattato e a metà: -28 dB (%.1f)" % _bus_db("Effetti"))
			sfx._muffle = 0.0
			sfx._muffle_target = 0.0
			settings.apply()
		70:
			# I tasti: il salto su J.
			settings.rebind("jump", _key(KEY_J))
			t.check(settings.key_name("jump") == "J", "il salto passa a J")
			t.check(hud._chips.glide._key_label.text == "J", "l'HUD mostra J sotto il deltaplano")
			# Il pugno su J: si scambiano, il salto prende il clic.
			settings.rebind("punch", _key(KEY_J))
			t.check(settings.key_name("punch") == "J" and settings.key_name("jump") == "Clic", "pugno su J: il salto prende il clic (%s)" % settings.key_name("jump"))
			t.check(InputMap.action_get_events("punch").size() == 1, "il pugno ha un solo comando")
			Input.parse_input_event(_key(KEY_J))
		72:
			t.check(Input.is_action_pressed("punch") and not Input.is_action_pressed("jump"), "premere J è il pugno")
			Input.parse_input_event(_key(KEY_J, false))
			t.check(settings.with_keys("In aria, {slam}: piombi giù") == "In aria, Ctrl: piombi giù", "i testi delle carte scrivono il tasto assegnato")
			t.check(not settings.can_bind(_key(KEY_ESCAPE)) and not settings.can_bind(_key(KEY_F1)), "Esc e i tasti F non si assegnano")
			# La scossa tolta.
			settings.set_option("shake", 0.0)
			var rig: Node = main.get_node("Frog").camera_rig
			rig.shake(1.0, 1.0)
			t.check(rig._shake_strength == 0.0, "scossa a zero: la telecamera non trema")
			settings.set_option("shake", 1.0)
			# Salvate e ricaricate.
			settings.set_option("invert_y", true)
			settings.set_option("render_scale", 0.75)
			var fresh: Node = load("res://scripts/settings.gd").new()
			fresh.load_from(PATH)
			t.check(fresh.invert_y and is_equal_approx(fresh.render_scale, 0.75) and is_equal_approx(fresh.effects_volume, 0.5), "le opzioni si ricaricano dal file")
			fresh.free()
			t.check(is_equal_approx(root.scaling_3d_scale, 0.75), "la risoluzione del mondo arriva al viewport")
			# I predefiniti.
			settings.reset()
			t.check(settings.key_name("jump") == "Spazio" and settings.key_name("punch") == "Clic", "i predefiniti rimettono Spazio e clic")
			t.check(not settings.invert_y and is_equal_approx(settings.effects_volume, 1.0), "i predefiniti rimettono le opzioni")
			# Il pannello dalla pausa.
			hud.pause()
		75:
			t.check(paused, "pausa")
			hud._open_options()
			var panel: Node = hud._options
			t.check(panel.visible, "dalla pausa si aprono le opzioni")
			var slider: HSlider = panel.find_child("master_volume", true, false)
			slider.value = 0.4
			t.check(is_equal_approx(settings.master_volume, 0.4), "il cursore cambia il volume generale")
			var toggle: Button = panel.find_child("flashes", true, false)
			toggle.pressed.emit()
			t.check(not settings.flashes and toggle.text == "No", "il pulsante toglie il lampo")
			# Riassegnare la lingua dal pannello: clic sul comando, poi K.
			panel._key_buttons.tongue.pressed.emit()
			Input.parse_input_event(_key(KEY_K))
		77:
			var panel: Node = hud._options
			t.check(settings.key_name("tongue") == "K" and panel._key_buttons.tongue.text == "K", "dal pannello la lingua passa a K")
			# Esc mentre aspetta: annulla e non chiude.
			panel._key_buttons.slam.pressed.emit()
			Input.parse_input_event(_key(KEY_ESCAPE))
		79:
			var panel: Node = hud._options
			t.check(settings.key_name("slam") == "Ctrl" and panel.visible, "Esc annulla la riassegnazione e lascia aperte le opzioni")
			Input.parse_input_event(_key(KEY_ESCAPE))
		81:
			t.check(not hud._options.visible and paused and hud.is_paused(), "Esc chiude le opzioni e resta in pausa")
			var saved := ConfigFile.new()
			saved.load(PATH)
			t.check(is_equal_approx(saved.get_value("opzioni", "master_volume"), 0.4) and saved.get_value("tasti", "tongue") == "tasto:%d" % KEY_K, "chiudendo le opzioni si salvano")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progressi_test.cfg"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
