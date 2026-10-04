class_name TestMode
extends CanvasLayer
## La modalità prova, per provare il gioco senza doverci arrivare giocando.
## F1 apre il pannello (il gioco si ferma): livello di calore, calore
## bloccato, salto a un bioma, rana invincibile, poteri sempre carichi, una
## tana per scegliere un power-up. Le stesse cose si chiedono anche
## all'avvio, dalla riga di comando (vedi tools/prova.sh):
##   --bioma=strada|fiume|ferrovia|aeroporto|porto|tana  --calore=0..5
##   --blocca-calore  --invincibile  --poteri
## Le opzioni restano attive anche dopo "Ricomincia". Una run in cui si usa
## la modalità prova non salva il record, e in alto compare PROVA.

const BIOMES := {
	"strada": Course.Kind.ROAD, "fiume": Course.Kind.RIVER, "ferrovia": Course.Kind.RAIL,
	"aeroporto": Course.Kind.AIRPORT, "porto": Course.Kind.PORT, "tana": Course.Kind.DEN,
}

## Restano da una run all'altra (finché il gioco è aperto).
static var invincible := false
static var charged := false
static var heat_locked := false
static var locked_level := 0
static var _command_line_read := false

var _game: Node
var _panel: PanelContainer
var _tag: Label
var _toggles := {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent()
	_build()
	if not _command_line_read:
		_command_line_read = true
		_read_command_line.call_deferred()
	_apply_options()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_mode"):
		get_viewport().set_input_as_handled()
		_set_open(not _panel.visible)


func _physics_process(_delta: float) -> void:
	var frog: Frog = _game.frog
	frog.invincible = invincible
	if charged:
		frog.super_jump_power.cooldown_left = 0.0
		frog.punch_power.cooldown_left = 0.0
		frog.glider_power.charge = frog.glider_power.duration
	if heat_locked and Heat.level() != locked_level:
		Heat.set_value(_heat_for(locked_level))
	_tag.visible = _game.test_run


# --- Le azioni --------------------------------------------------------------

func set_heat_level(level: int) -> void:
	locked_level = level
	Heat.set_value(_heat_for(level))
	_mark_test_run()


func jump_to(biome: String) -> void:
	_game.course.jump_to(BIOMES[biome])
	_mark_test_run()


func offer_upgrade() -> void:
	_set_open(false)
	_mark_test_run()
	_game.offer_upgrade()


func set_invincible(on: bool) -> void:
	invincible = on
	_apply_options()


func set_charged(on: bool) -> void:
	charged = on
	_apply_options()


func set_heat_locked(on: bool) -> void:
	heat_locked = on
	locked_level = Heat.level()
	_apply_options()


func _apply_options() -> void:
	Heat.running = not heat_locked
	_game.frog.invincible = invincible
	var states := {"invincible": invincible, "charged": charged, "heat_locked": heat_locked}
	for key in _toggles:
		_toggles[key].set_pressed_no_signal(states[key])
	if invincible or charged or heat_locked:
		_mark_test_run()


func _mark_test_run() -> void:
	_game.test_run = true


## Il calore a metà del livello dato (0 = appena partiti).
static func _heat_for(level: int) -> float:
	return 0.0 if level == 0 else level * Heat.MAX / Heat.LEVELS + 1.0


func _read_command_line() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=")
		match parts[0]:
			"invincibile":
				set_invincible(true)
			"poteri":
				set_charged(true)
			"calore":
				set_heat_level(clampi(int(parts[1]), 0, Heat.LEVELS))
			"blocca-calore":
				set_heat_locked(true)
			"bioma":
				if BIOMES.has(parts[1]):
					jump_to(parts[1])
				else:
					push_warning("Bioma sconosciuto: %s" % parts[1])
	# Il calore bloccato vale al livello chiesto, anche se scritto prima.
	if heat_locked:
		locked_level = Heat.level()


# --- Il pannello ------------------------------------------------------------

func _set_open(open: bool) -> void:
	_panel.visible = open
	var offer_open: bool = _game.hud._offer.visible
	get_tree().paused = open or offer_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open or offer_open else Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_tag = Label.new()
	_tag.text = "PROVA (F1)"
	_tag.add_theme_font_size_override("font_size", 18)
	_tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tag.offset_top = 8
	_tag.offset_left = -60
	_tag.offset_right = 60
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_tag)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -270
	_panel.offset_right = 270
	_panel.offset_top = -220
	_panel.offset_bottom = 220
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	box.add_child(_title("Modalità prova  (F1 per chiudere)"))

	box.add_child(_title("Livello di calore", 16))
	var heat_row := HBoxContainer.new()
	for level in Heat.LEVELS + 1:
		heat_row.add_child(_button(str(level), set_heat_level.bind(level)))
	box.add_child(heat_row)

	box.add_child(_title("Vai a", 16))
	var biome_row := HFlowContainer.new()
	for biome in BIOMES:
		biome_row.add_child(_button(biome.capitalize(), _jump_and_close.bind(biome)))
	box.add_child(biome_row)

	box.add_child(_toggle("Invincibile", "invincible", set_invincible))
	box.add_child(_toggle("Poteri sempre carichi", "charged", set_charged))
	box.add_child(_toggle("Blocca il calore al livello attuale", "heat_locked", set_heat_locked))
	box.add_child(_button("Apri una tana: scegli un power-up", offer_upgrade))
	var note := _title("Una run di prova non salva il record.", 14)
	note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(note)


func _jump_and_close(biome: String) -> void:
	_set_open(false)
	jump_to(biome)


func _title(text: String, size := 20) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _toggle(text: String, option: String, action: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(action)
	_toggles[option] = toggle
	return toggle
