extends Node
## Le opzioni del giocatore (autoload Settings): volumi, grafica, mouse e
## tasti. Si applicano subito e si salvano in user://opzioni.cfg a ogni
## modifica. Senza schermo (i test headless) si parte dai valori predefiniti
## e si salva in un file a parte: i test non toccano le opzioni vere.
##
## I tasti: ogni azione della rana ha un solo comando da tastiera o mouse,
## riassegnabile. Se il comando nuovo era già di un'altra azione, le due si
## scambiano. Esc (pausa) e i tasti F restano fissi.

signal changed

## Le azioni riassegnabili, nell'ordine in cui si mostrano, col loro nome.
const ACTIONS := {
	"move_forward": "Avanti",
	"move_back": "Indietro",
	"move_left": "Sinistra",
	"move_right": "Destra",
	"jump": "Salto e deltaplano",
	"punch": "Pugno",
	"super_jump": "Super salto",
	"tongue": "Lingua",
	"slam": "Schianto e tuffo",
}
const WINDOW_MODES := ["Finestra", "Schermo intero"]
## Limiti ai fotogrammi al secondo (0: nessuno).
const FPS_LIMITS := [0, 30, 60, 120, 144, 240]
## Il nome italiano dei tasti che non sono una lettera.
const KEY_NAMES := {
	KEY_SPACE: "Spazio", KEY_CTRL: "Ctrl", KEY_SHIFT: "Maiusc", KEY_ALT: "Alt",
	KEY_TAB: "Tab", KEY_ENTER: "Invio", KEY_KP_ENTER: "Invio", KEY_BACKSPACE: "Backspace",
	KEY_CAPSLOCK: "Bloc Maiusc", KEY_UP: "Freccia su", KEY_DOWN: "Freccia giù",
	KEY_LEFT: "Freccia sinistra", KEY_RIGHT: "Freccia destra", KEY_DELETE: "Canc",
	KEY_INSERT: "Ins", KEY_HOME: "Home", KEY_END: "Fine", KEY_PAGEUP: "Pag su",
	KEY_PAGEDOWN: "Pag giù", KEY_META: "Super",
}
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Clic", MOUSE_BUTTON_RIGHT: "Clic dx",
	MOUSE_BUTTON_MIDDLE: "Clic centrale", MOUSE_BUTTON_WHEEL_UP: "Rotella su",
	MOUSE_BUTTON_WHEEL_DOWN: "Rotella giù", MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

var path := "user://opzioni.cfg"

## Volumi da 0 a 1.
var master_volume := 1.0
var effects_volume := 1.0
var music_volume := 0.8
var window_mode := 0
var vsync := true
## Indice in FPS_LIMITS.
var fps_limit := 0
## Risoluzione del mondo 3D rispetto allo schermo (l'interfaccia resta piena).
var render_scale := 1.0
## Quanto scuote la telecamera (0: per niente).
var shake := 1.0
## Il lampo invertito a ogni nuovo livello di calore.
var flashes := true
## Moltiplica la sensibilità della telecamera.
var mouse_sensitivity := 1.0
var invert_y := false

## I comandi predefiniti, presi da project.godot all'avvio.
var _defaults := {}
var _default_style := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in ACTIONS:
		_defaults[action] = binding(action)
	_default_style = Style.current
	if DisplayServer.get_name() == "headless":
		path = "user://opzioni_test.cfg"
	else:
		load_from(path)
	apply()


## Applica tutto: audio, grafica, tasti. Lo stile grafico lo tiene Style.
func apply() -> void:
	Sfx.set_volumes(master_volume, effects_volume, music_volume)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if window_mode == 1 else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		# Solo se cambia: rifare la catena di presentazione costa.
		var sync := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode() != sync:
			DisplayServer.window_set_vsync_mode(sync)
	Engine.max_fps = FPS_LIMITS[fps_limit]
	get_tree().root.scaling_3d_scale = render_scale
	changed.emit()


## Cambia un'opzione per nome e la applica; la salva subito, se non è un
## cursore che si sta trascinando (lo salva chi chiude le opzioni).
func set_option(option: String, value: Variant, save_now := true) -> void:
	if option == "style":
		Style.set_style(value)
	else:
		set(option, value)
	apply()
	if save_now:
		save()


func save() -> void:
	var file := ConfigFile.new()
	for option in _options():
		file.set_value("opzioni", option, get(option))
	file.set_value("opzioni", "style", Style.current)
	for action: String in ACTIONS:
		file.set_value("tasti", action, _encode(binding(action)))
	file.save(path)


func load_from(file_path: String) -> void:
	var file := ConfigFile.new()
	if file.load(file_path) != OK:
		return
	for option in _options():
		var value: Variant = file.get_value("opzioni", option, get(option))
		if typeof(value) == typeof(get(option)):
			set(option, value)
	fps_limit = clampi(fps_limit, 0, FPS_LIMITS.size() - 1)
	window_mode = clampi(window_mode, 0, WINDOW_MODES.size() - 1)
	var style: int = file.get_value("opzioni", "style", Style.current)
	if style >= 0 and style < Style.styles.size():
		Style.set_style(style)
	for action: String in ACTIONS:
		var event := _decode(file.get_value("tasti", action, ""))
		if event != null:
			_bind(action, event)


## Torna ai valori predefiniti (tutto, o solo i tasti).
func reset(only_keys := false) -> void:
	for action: String in ACTIONS:
		_bind(action, _defaults[action])
	if not only_keys:
		var fresh: Node = get_script().new()
		for option in _options():
			set(option, fresh.get(option))
		fresh.free()
		Style.set_style(_default_style)
	apply()
	save()


# --- Tasti ---------------------------------------------------------------------

## Il comando da tastiera o mouse di un'azione (null se non ne ha).
func binding(action: String) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return event
	return null


## Assegna un comando a un'azione. Se era di un'altra azione, le due si
## scambiano i comandi: nessuna azione resta senza.
func rebind(action: String, event: InputEvent) -> void:
	var old := binding(action)
	for other: String in ACTIONS:
		if other != action and _same(binding(other), event):
			_bind(other, old)
	_bind(action, event)
	apply()
	save()


## Il nome da mostrare per il comando di un'azione ("Spazio", "Clic dx"...).
func key_name(action: String) -> String:
	return event_name(binding(action))


func event_name(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return MOUSE_NAMES.get(event.button_index, "Mouse %d" % event.button_index)
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if KEY_NAMES.has(code):
			return KEY_NAMES[code]
		# La lettera che quel tasto ha sulla tastiera del giocatore (senza
		# schermo non si sa: quella americana).
		var label := KEY_NONE if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(label if label != KEY_NONE else code)
	return "—"


## Un testo con i tasti fra graffe ("{slam}: piombi giù") scritti come sono
## assegnati ora ("Ctrl: piombi giù").
func with_keys(text: String) -> String:
	if not "{" in text:
		return text
	for action: String in ACTIONS:
		text = text.replace("{%s}" % action, key_name(action))
	return text


## Un comando accettabile per le azioni: un tasto o un pulsante del mouse
## premuti. Esc e i tasti F no (sono della pausa e degli strumenti).
static func can_bind(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventKey:
		var code: Key = event.physical_keycode
		return event.pressed and not event.echo and code != KEY_ESCAPE and not (code >= KEY_F1 and code <= KEY_F35)
	return false


func _bind(action: String, event: InputEvent) -> void:
	if event == null:
		return
	for old in InputMap.action_get_events(action):
		if old is InputEventKey or old is InputEventMouseButton:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, _clean(event))


## Solo il tasto fisico (o il pulsante), senza modificatori: Ctrl da solo è
## un comando, Ctrl+W no.
func _clean(event: InputEvent) -> InputEvent:
	if event is InputEventMouseButton:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		return mouse
	var key := InputEventKey.new()
	key.physical_keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return key


func _same(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	return false


func _encode(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	if event is InputEventKey:
		return "tasto:%d" % event.physical_keycode
	return ""


func _decode(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	if parts[0] == "mouse":
		var mouse := InputEventMouseButton.new()
		mouse.button_index = parts[1].to_int() as MouseButton
		return mouse
	if parts[0] == "tasto":
		var key := InputEventKey.new()
		key.physical_keycode = parts[1].to_int() as Key
		return key
	return null


func _options() -> Array[String]:
	return ["master_volume", "effects_volume", "music_volume", "window_mode", "vsync",
		"fps_limit", "render_scale", "shake", "flashes", "mouse_sensitivity", "invert_y"]
