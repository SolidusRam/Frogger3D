extends Node
## Le opzioni del giocatore (autoload Settings): volumi, grafica, mouse,
## controller e tasti. Si applicano subito e si salvano in user://opzioni.cfg
## a ogni modifica. Senza schermo (i test headless) si parte dai valori
## predefiniti e si salva in un file a parte: i test non toccano le opzioni
## vere.
##
## I tasti: ogni azione della rana ha un comando da tastiera o mouse e uno
## dal controller, riassegnabili tutti e due. Se il comando nuovo era già di
## un'altra azione, le due si scambiano. Esc (pausa) e i tasti F restano
## fissi; sul controller restano fissi le levette (muoversi e guardare), la
## croce (muoversi), Start (pausa).
##
## Il controller: i suoi comandi predefiniti si aggiungono all'avvio (vedi
## PAD_DEFAULTS); A conferma e B torna indietro anche nei menu. Il gioco
## ricorda l'ultimo dispositivo usato (using_pad): l'HUD e le carte scrivono
## i comandi di quello ("A", "RT" oppure "Spazio", "Clic").

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
## Sul controller ci si muove con la levetta sinistra o la croce: quelle
## azioni non si riassegnano.
const MOVES := ["move_forward", "move_back", "move_left", "move_right"]
## I comandi del controller (nomi dei pulsanti alla Xbox). I grilletti sono
## assi: "rt" e "lt". Pugno e lingua sui grilletti, così il pollice destro
## resta sulla telecamera mentre si colpisce o si aggancia.
const PAD_DEFAULTS := {
	"jump": JOY_BUTTON_A,
	"slam": JOY_BUTTON_B,
	"super_jump": JOY_BUTTON_RIGHT_SHOULDER,
	"punch": "rt",
	"tongue": "lt",
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
## I pulsanti del controller: alla Xbox e alla PlayStation.
const PAD_NAMES := {
	JOY_BUTTON_A: ["A", "Croce"], JOY_BUTTON_B: ["B", "Cerchio"],
	JOY_BUTTON_X: ["X", "Quadrato"], JOY_BUTTON_Y: ["Y", "Triangolo"],
	JOY_BUTTON_LEFT_SHOULDER: ["LB", "L1"], JOY_BUTTON_RIGHT_SHOULDER: ["RB", "R1"],
	JOY_BUTTON_LEFT_STICK: ["L3", "L3"], JOY_BUTTON_RIGHT_STICK: ["R3", "R3"],
	JOY_BUTTON_BACK: ["Back", "Select"], JOY_BUTTON_START: ["Start", "Options"],
	JOY_BUTTON_DPAD_UP: ["Croce su", "Croce su"], JOY_BUTTON_DPAD_DOWN: ["Croce giù", "Croce giù"],
	JOY_BUTTON_DPAD_LEFT: ["Croce sinistra", "Croce sinistra"], JOY_BUTTON_DPAD_RIGHT: ["Croce destra", "Croce destra"],
}
const TRIGGER_NAMES := {JOY_AXIS_TRIGGER_LEFT: ["LT", "L2"], JOY_AXIS_TRIGGER_RIGHT: ["RT", "R2"]}
## I comandi fissi dei menu, per scriverli accanto ai pulsanti: tastiera e
## controller.
const UI_NAMES := {
	"ui_accept": ["Invio", "A"], "ui_cancel": ["Esc", "B"], "pause": ["Esc", "Start"],
}
## Quanto deve muoversi una levetta (o un grilletto) per dire "ora si gioca
## col controller", e quanto il mouse per tornare alla tastiera.
const PAD_THRESHOLD := 0.5
const MOUSE_THRESHOLD := 6.0

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
## Moltiplica la sensibilità della telecamera, col mouse e con la levetta.
var mouse_sensitivity := 1.0
var stick_sensitivity := 1.0
var invert_y := false
var vibration := true

## L'ultimo dispositivo usato è il controller (e quale).
var using_pad := false
var pad_device := 0

## I comandi predefiniti: [tastiera o mouse, controller] per azione.
var _defaults := {}
var _default_style := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_pad_defaults()
	for action: String in ACTIONS:
		_defaults[action] = [binding(action), binding(action, true)]
	_default_style = Style.current
	if DisplayServer.get_name() == "headless":
		path = "user://opzioni_test.cfg"
	else:
		load_from(path)
	apply()


## Si guarda l'ultimo dispositivo usato, senza fermare niente.
func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > PAD_THRESHOLD:
		pad = true
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		pad = false
	elif event is InputEventMouseMotion and event.relative.length() > MOUSE_THRESHOLD:
		pad = false
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if pad:
			pad_device = event.device
	if pad != using_pad:
		using_pad = pad
		changed.emit()


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
		if not action in MOVES:
			file.set_value("controller", action, _encode(binding(action, true)))
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
	for section in ["tasti", "controller"]:
		for action: String in ACTIONS:
			var event := _decode(file.get_value(section, action, ""))
			if event != null:
				_bind(action, event)


## Torna ai valori predefiniti (tutto, o solo i tasti).
func reset(only_keys := false) -> void:
	for action: String in ACTIONS:
		for event: InputEvent in _defaults[action]:
			_bind(action, event)
	if not only_keys:
		var fresh: Node = get_script().new()
		for option in _options():
			set(option, fresh.get(option))
		fresh.free()
		Style.set_style(_default_style)
	apply()
	save()


## Una vibrazione del controller, se lo si sta usando e le opzioni la
## vogliono. weak e strong da 0 a 1: il motore leggero e quello pesante.
func rumble(weak: float, strong: float, duration: float) -> void:
	if vibration and using_pad:
		Input.start_joy_vibration(pad_device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)


# --- Tasti ---------------------------------------------------------------------

## Il comando di un'azione da tastiera o mouse, oppure (pad) dal controller:
## un pulsante o un grilletto. null se non ne ha.
func binding(action: String, pad := false) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if not pad and (event is InputEventKey or event is InputEventMouseButton):
			return event
		if pad and _is_pad_command(event):
			return event
	return null


## Assegna un comando a un'azione. Se era di un'altra azione, le due si
## scambiano i comandi: nessuna azione resta senza.
func rebind(action: String, event: InputEvent) -> void:
	var pad := _is_pad_command(event)
	var old := binding(action, pad)
	for other: String in ACTIONS:
		if other != action and _same(binding(other, pad), event):
			_bind(other, old)
	_bind(action, event)
	apply()
	save()


## Il nome da mostrare per il comando di un'azione ("Spazio", "Clic dx"...),
## del dispositivo usato per ultimo (o di quello chiesto).
func key_name(action: String, pad: Variant = null) -> String:
	var on_pad: bool = using_pad if pad == null else pad
	if on_pad and action in MOVES:
		return "Levetta sinistra"
	return event_name(binding(action, on_pad))


## Il nome di un comando fisso dei menu (Invio/A, Esc/B, Esc/Start).
func ui_name(action: String) -> String:
	return UI_NAMES[action][1 if using_pad else 0]


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
	var family := 1 if _playstation() else 0
	if event is InputEventJoypadButton:
		return PAD_NAMES[event.button_index][family] if PAD_NAMES.has(event.button_index) else "Pulsante %d" % event.button_index
	if event is InputEventJoypadMotion and TRIGGER_NAMES.has(event.axis):
		return TRIGGER_NAMES[event.axis][family]
	return "—"


## Un testo con i tasti fra graffe ("{slam}: piombi giù") scritti come sono
## assegnati ora ("Ctrl: piombi giù").
func with_keys(text: String) -> String:
	if not "{" in text:
		return text
	for action: String in ACTIONS:
		text = text.replace("{%s}" % action, key_name(action))
	return text


## Un comando accettabile da tastiera o mouse: un tasto o un pulsante del
## mouse premuti. Esc e i tasti F no (sono della pausa e degli strumenti).
static func can_bind(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventKey:
		var code: Key = event.physical_keycode
		return event.pressed and not event.echo and code != KEY_ESCAPE and not (code >= KEY_F1 and code <= KEY_F35)
	return false


## Un comando accettabile dal controller: un pulsante premuto (non la croce,
## che muove, né Start, che è la pausa) o un grilletto premuto a fondo.
static func can_bind_pad(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var button: JoyButton = event.button_index
		return event.pressed and button != JOY_BUTTON_START and not (button >= JOY_BUTTON_DPAD_UP and button <= JOY_BUTTON_DPAD_RIGHT)
	if event is InputEventJoypadMotion:
		return TRIGGER_NAMES.has(event.axis) and event.axis_value > PAD_THRESHOLD
	return false


## I comandi del controller che si aggiungono a project.godot all'avvio: la
## rana, le levette, la pausa e A/B nei menu.
func _add_pad_defaults() -> void:
	for action: String in PAD_DEFAULTS:
		var spec: Variant = PAD_DEFAULTS[action]
		if spec is String:
			_add(action, _trigger(JOY_AXIS_TRIGGER_RIGHT if spec == "rt" else JOY_AXIS_TRIGGER_LEFT))
		else:
			_add(action, _button(spec))
	for move: Array in [["move_forward", JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP],
			["move_back", JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN],
			["move_left", JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT],
			["move_right", JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT]]:
		_add(move[0], _axis(move[1], move[2]))
		_add(move[0], _button(move[3]))
	# La telecamera: la levetta destra.
	for look: Array in [["look_left", JOY_AXIS_RIGHT_X, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0],
			["look_up", JOY_AXIS_RIGHT_Y, -1.0], ["look_down", JOY_AXIS_RIGHT_Y, 1.0]]:
		if not InputMap.has_action(look[0]):
			InputMap.add_action(look[0], 0.15)
		_add(look[0], _axis(look[1], look[2]))
	_add("pause", _button(JOY_BUTTON_START))
	_add("ui_accept", _button(JOY_BUTTON_A))
	_add("ui_cancel", _button(JOY_BUTTON_B))


func _add(action: String, event: InputEvent) -> void:
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _bind(action: String, event: InputEvent) -> void:
	if event == null:
		return
	var pad := _is_pad_command(event)
	for old in InputMap.action_get_events(action):
		if (pad and _is_pad_command(old)) or (not pad and (old is InputEventKey or old is InputEventMouseButton)):
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, _clean(event))


## Un comando del controller che si può riassegnare: un pulsante (non la
## croce) o un grilletto. Le levette no.
static func _is_pad_command(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return not (event.button_index >= JOY_BUTTON_DPAD_UP and event.button_index <= JOY_BUTTON_DPAD_RIGHT)
	return event is InputEventJoypadMotion and TRIGGER_NAMES.has(event.axis)


## Solo il tasto fisico (o il pulsante), senza modificatori: Ctrl da solo è
## un comando, Ctrl+W no. I comandi del controller valgono per tutti i
## controller.
func _clean(event: InputEvent) -> InputEvent:
	if event is InputEventMouseButton:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		return mouse
	if event is InputEventJoypadButton:
		return _button(event.button_index)
	if event is InputEventJoypadMotion:
		return _trigger(event.axis)
	var key := InputEventKey.new()
	key.physical_keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return key


static func _button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = index
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	return event


static func _trigger(axis: JoyAxis) -> InputEventJoypadMotion:
	return _axis(axis, 1.0)


func _same(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis
	return false


## Il controller in uso è di Sony: i pulsanti si chiamano Croce, Cerchio...
func _playstation() -> bool:
	var joy_name := Input.get_joy_name(pad_device).to_lower()
	for hint in ["playstation", "dualshock", "dualsense", "ps4", "ps5", "sony"]:
		if hint in joy_name:
			return true
	return false


func _encode(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	if event is InputEventKey:
		return "tasto:%d" % event.physical_keycode
	if event is InputEventJoypadButton:
		return "pulsante:%d" % event.button_index
	if event is InputEventJoypadMotion:
		return "grilletto:%d" % event.axis
	return ""


func _decode(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var value := parts[1].to_int()
	match parts[0]:
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = value as MouseButton
			return mouse
		"tasto":
			var key := InputEventKey.new()
			key.physical_keycode = value as Key
			return key
		"pulsante":
			return _button(value as JoyButton)
		"grilletto":
			if TRIGGER_NAMES.has(value):
				return _trigger(value as JoyAxis)
	return null


func _options() -> Array[String]:
	return ["master_volume", "effects_volume", "music_volume", "window_mode", "vsync",
		"fps_limit", "render_scale", "shake", "flashes", "mouse_sensitivity",
		"stick_sensitivity", "invert_y", "vibration"]
