extends SceneTree
## Le lingue: ogni testo del gioco ha la sua traduzione inglese, con gli
## stessi segnaposto (%d, %s, {slam}); scegliendo l'inglese nelle opzioni le
## scritte cambiano subito, anche quelle coi numeri, e tornano in italiano.
## Lo stesso controllo, fuori da Godot: tools/lingue/estrai.py.

const Lib := preload("res://tests/lib.gd")
const PATH := "user://opzioni_test.cfg"
## Strumenti da sviluppo, in italiano anche in inglese.
const DEV_SCRIPTS := ["test_mode.gd", "perf_overlay.gd"]
## Codici e nomi propri: uguali in tutte le lingue.
const SKIP := ["", "Frogger 3D", "Esc", "A", "B", "X", "Y", "LB", "RB", "LT", "RT", "L1", "R1",
	"L2", "R2", "L3", "R3", "Start", "Back", "Select", "Options", "Tab", "Alt", "Ctrl", "Super",
	"PS1", "Arcade", "Controller", "Menu", "Mouse 4", "Mouse 5", "Home", "Backspace", "%d/%d",
	"Lingua · Language", "Italiano", "English", "???"]

var t := Lib.new()
var main: Node
var hud: Node
var settings: Node
var en: Translation
var frame := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	hud = main.get_node("Hud")
	en = load("res://assets/lingue/en.po")


## I testi del gioco: quelli negli script (tr() e le scritte fisse dei
## costruttori dell'interfaccia) e quelli dei cataloghi.
func _texts() -> Dictionary:
	var texts := {}
	var string := "\"((?:[^\"\\\\]|\\\\.)*)\""
	var patterns: Array[RegEx] = []
	for pattern in ["\\btr\\(\\s*" + string,
			"\\b(?:_label|_button|_note)\\(\\s*" + string,
			"\\b_text\\(\\s*\"[^\"]*\",\\s*" + string,
			"\\b_page\\(\\s*(?:\\w+,\\s*)?" + string,
			"\\b(?:_slider|_toggle|_choice)\\(\\s*\\w+,\\s*" + string]:
		patterns.append(RegEx.create_from_string(pattern))
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd") or file in DEV_SCRIPTS:
			continue
		var source := FileAccess.get_file_as_string("res://scripts/" + file)
		for regex in patterns:
			for found in regex.search_all(source):
				texts[found.get_string(1).c_unescape()] = file
	var upgrades: GDScript = load("res://scripts/upgrades.gd")
	for id in upgrades.CATALOG:
		texts[upgrades.CATALOG[id].name] = "catalogo"
		texts[upgrades.CATALOG[id].text] = "catalogo"
	for slot in upgrades.SLOT_NAMES:
		texts[upgrades.SLOT_NAMES[slot]] = "slot"
	var progress: GDScript = load("res://scripts/progress.gd")
	for stat in progress.STATS:
		texts[progress.STATS[stat].name] = "statistiche"
		texts[progress.STATS[stat].text] = "statistiche"
	for card in progress.CARD_UPGRADES:
		for info in progress.CARD_UPGRADES[card]:
			for key in ["name", "text", "trial"]:
				texts[info[key]] = "maestria"
	var names: GDScript = load("res://scripts/settings.gd")
	for table in [names.ACTIONS, names.KEY_NAMES, names.MOUSE_NAMES]:
		for key in table:
			texts[table[key]] = "nomi"
	for table in [names.PAD_NAMES, names.TRIGGER_NAMES, names.UI_NAMES]:
		for key in table:
			for text in table[key]:
				texts[text] = "nomi"
	for text in names.WINDOW_MODES:
		texts[text] = "nomi"
	var new_power: Dictionary = load("res://scripts/hud.gd").NEW_POWER
	for slot in new_power:
		texts[new_power[slot]] = "carte"
	var rarity_names: Dictionary = load("res://scripts/hud.gd").RARITY_NAMES
	for kind in rarity_names:
		texts[rarity_names[kind]] = "rarità"
	var token_names: Dictionary = load("res://scripts/hud.gd").TOKEN_NAMES
	for kind in token_names:
		texts[token_names[kind]] = "gettoni"
	var powers: Dictionary = load("res://scripts/hud.gd").POWERS
	for power in powers:
		texts[powers[power][0]] = "poteri"
	for style in root.get_node("Style").styles:
		texts[style.name] = "stili"
	texts["Nessuno"] = "opzioni"
	texts["Quello della rana"] = "guardaroba"
	for text in load("res://scripts/drought.gd").LEVELS:
		texts[text] = "siccità"
	var cosmetics: GDScript = load("res://scripts/cosmetics.gd")
	for table in [cosmetics.HATS, cosmetics.COLORS, cosmetics.TIERS]:
		for id in table:
			texts[table[id].name] = "guardaroba"
	var frogs: Dictionary = load("res://scripts/frogs.gd").ALL
	for id in frogs:
		for key in ["name", "pro", "contro"]:
			texts[frogs[id][key]] = "rane"
	var feats: Dictionary = load("res://scripts/feats.gd").ALL
	for id in feats:
		for key in ["name", "text", "reward_name", "group"]:
			texts[feats[id][key]] = "imprese"
	for text in SKIP:
		texts.erase(text)
	return texts


## I segnaposto di un testo, in ordine.
func _placeholders(text: String) -> Array:
	var regex := RegEx.create_from_string("%0?\\d*[ds]|\\{\\w+\\}")
	return regex.search_all(text).map(func(found: RegExMatch) -> String: return found.get_string())


func _physics_process(_delta: float) -> bool:
	frame += 1
	settings = root.get_node("Settings")
	match frame:
		5:
			var texts := _texts()
			var missing: Array = []
			var mismatched: Array = []
			for text: String in texts:
				var english := String(en.get_message(text))
				if english == "":
					missing.append(text)
				elif _placeholders(english) != _placeholders(text):
					mismatched.append(text)
			t.check(texts.size() > 200, "trovati i testi del gioco (%d)" % texts.size())
			t.check(missing.is_empty(), "ogni testo ha la traduzione inglese (mancano: %s)" % ", ".join(missing))
			t.check(mismatched.is_empty(), "le traduzioni hanno gli stessi segnaposto (%s)" % ", ".join(mismatched))
			# Si parte in italiano.
			t.check(TranslationServer.get_locale() == "it" and hud._health_label.text.begins_with("VITA"), "nei test si parte in italiano")
			# L'inglese, dalle opzioni.
			settings.set_option("language", 1)
		7:
			t.check(TranslationServer.get_locale() == "en", "scelto l'inglese, la lingua cambia")
			t.check(hud._health_label.text.begins_with("HEALTH"), "la vita si legge in inglese (%s)" % hud._health_label.text)
			t.check(hud._heat_label.text.begins_with("HEAT"), "il calore si legge in inglese")
			t.check(hud._resume_button.text == "Resume (Esc)", "la pausa dice Resume (%s)" % hud._resume_button.text)
			t.check(settings.key_name("jump") == "Space" and settings.key_name("super_jump") == "Right click", "i tasti hanno il nome inglese")
			t.check(settings.with_keys(tr("In aria, {slam}: piombi giù e all'atterraggio un'onda ribalta le auto intorno.")).begins_with("In the air, Ctrl:"), "le carte in inglese col tasto assegnato")
			hud._open_options()
		9:
			var panel: Node = hud._options
			var language: Button = panel.find_child("language", true, false)
			t.check(language.text == "English", "il pulsante della lingua dice English")
			var vsync: Button = panel.find_child("vsync", true, false)
			t.check(vsync.text == "On", "i pulsanti delle opzioni in inglese (%s)" % vsync.text)
			# Si torna all'italiano dal pannello.
			language.pressed.emit()
		11:
			t.check(TranslationServer.get_locale() == "it" and hud._health_label.text.begins_with("VITA"), "di nuovo in italiano")
			var saved := ConfigFile.new()
			saved.load(PATH)
			t.check(saved.get_value("opzioni", "language") == "it", "la lingua si salva")
			settings.reset()
			t.check(settings.language == "it", "i valori predefiniti non cambiano la lingua")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progressi_test.cfg"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
