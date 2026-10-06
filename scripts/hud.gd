class_name Hud
extends CanvasLayer
## L'HUD: vita e calore (a cinque gradini) in alto a sinistra; distanza, tana,
## record e mosche in alto a destra; i poteri in basso a sinistra, ognuno col
## colore e l'icona del suo attrezzo, il tasto, il modificatore equipaggiato e
## la ricarica; l'incendio in basso al centro; gli attrezzi senza potere (il
## corpo) e i potenziamenti numerici in basso a destra. Poi messaggi, catene,
## carte della tana, pausa (Esc) e la schermata di fine run.

## Un gettone della tana (vedi Upgrades.TOKENS); index: la carta esiliata.
signal token_used(kind: String, index: int)
## Lo stagno aperto dalla fine della corsa (per i suggerimenti).
signal pond_opened
signal restart_requested
signal menu_requested
## Dalla pausa: la run finisce qui (le mosche raccolte restano) e si torna al
## menu.
signal abandon_requested

## Carte al massimo in una tana (tre, quattro con la statistica "Più scelta").
const MAX_CARDS := 4

const HEALTH_COLOR := Color(0.4, 0.8, 0.3)
const HEALTH_LOW_COLOR := Color(0.9, 0.25, 0.2)
## Sotto questa frazione la barra della vita diventa rossa e pulsa.
const HEALTH_LOW := 0.3
## I gettoni della tana, nell'ordine dei pulsanti.
const TOKEN_NAMES := {"reroll": "Rilancia", "skip": "Salta", "banish": "Esilia"}
## La riga della carta quando lo slot è vuoto: la carta dà l'attrezzo.
const NEW_POWER := {
	"gloves": "Nuovo attrezzo: il pugno", "springs": "Nuovo attrezzo: il super salto",
	"wing": "Nuovo attrezzo: il deltaplano", "tongue": "Nuovo attrezzo: la lingua",
}
## I poteri: nome, azione (il tasto lo dicono le opzioni), attrezzo. L'ordine
## è quello dall'alto in basso.
const POWERS := {
	"punch": ["Pugno", "punch", "gloves"],
	"super_jump": ["Super salto", "super_jump", "springs"],
	"glide": ["Deltaplano", "jump", "wing"],
	"tongue": ["Lingua", "tongue", "tongue"],
	"slam": ["Schianto", "slam", "springs"],
}

@export var frog: Frog
@export var course: Course

var _health_bar: ProgressBar
var _health_label: Label
var _heat_meter: HeatMeter
var _heat_label: Label
var _distance_label: Label
var _dens_label: Label
var _record_label: Label
var _flies_label: Label
var _golden_label: Label
var _golden_icon: SlotIcon
## I poteri nell'HUD, per nome (vedi POWERS).
var _chips := {}
var _message: Label
var _fire_label: Label
var _fire_box: HBoxContainer
var _vignette: ColorRect
var _game_over: PanelContainer
var _game_over_text: Label
var _game_over_distance: Label
var _game_over_record: Label
var _game_over_flies: Label
var _pond: Pond
var _chain_label: Label
var _offer: PanelContainer
var _offer_title: Label
var _offer_buttons: Array[Button] = []
## I gettoni sotto le carte, e Esilia in attesa della carta da togliere.
var _token_buttons := {}
var _banishing := false
var _offer_hint: Label
## Le parti di ogni carta: icona, nome dello slot, nome, durata, effetto.
var _card_parts: Array[Dictionary] = []
var _upgrades: Upgrades
## In basso a destra: il corpo e i potenziamenti numerici.
var _extras: VBoxContainer
var _pause: Control
var _options: OptionsPanel
## Radice di tutti i controlli: porta il tema.
var _root: Control
var _resume_button: Button
var _restart_button: Button
var _record_distance := 0.0
## Il suggerimento del primo minuto (vedi Hints), in basso al centro.
var _hint: PanelContainer
var _hint_text: RichTextLabel
var _hint_tween: Tween
## L'impresa appena fatta: un riquadro d'oro in alto al centro.
var _feat: PanelContainer
var _feat_title: Label
var _feat_reward: Label
var _feat_tween: Tween
## Alla fine della corsa: lo stagno messo in evidenza.
var _pond_button: Button
var _pond_note: Label
var _pond_tween: Tween
var _last_heat_level := 0


func _ready() -> void:
	# La scelta dei power-up avviene a gioco fermo: l'HUD deve restare attivo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_build_top_left()
	_build_top_right()
	_build_powers()
	_build_message()
	_build_fire()
	_build_chain_label()
	_build_hint()
	_build_feat()
	_build_offer()
	_build_equipment()
	_build_game_over()
	_build_pause()
	frog.health_changed.connect(_on_health_changed)
	_on_health_changed(frog.health, frog.max_health)
	Heat.changed.connect(_on_heat_changed)
	_on_heat_changed(Heat.value, Heat.level())
	course.den_reached.connect(_on_den_reached)
	Style.style_changed.connect(_on_style_changed)
	Settings.changed.connect(_update_prompts)
	_update_prompts()
	_last_heat_level = Heat.level()


## Cambiata la lingua (dalle opzioni in pausa), si riscrivono le scritte che
## non si aggiornano da sole.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_on_health_changed(frog.health, frog.max_health)
		_heat_label.text = tr("CALORE  %d / %d") % [Heat.level(), Heat.LEVELS]
		_update_prompts()
		if _record_label.text != "":
			set_record(_record_distance)
		if _upgrades != null:
			show_equipment(_upgrades)


func _process(_delta: float) -> void:
	_distance_label.text = "%d m" % roundi(course.distance())
	_dens_label.text = tr("Tana %d") % course.dens_reached
	var punch := frog.punch_power
	_chips.punch.set_ratio(1.0 - punch.cooldown_left / maxf(punch.cooldown, 0.001))
	_chips.super_jump.set_ratio(frog.super_jump_power.ready_ratio())
	_chips.glide.set_ratio(frog.glide_charge_ratio())
	# Si vedono solo i poteri degli attrezzi che la rana ha.
	_chips.punch.visible = punch.enabled
	_chips.super_jump.visible = frog.super_jump_power.enabled
	_chips.glide.visible = frog.glider_power.enabled
	_chips.tongue.visible = frog.tongue_power.enabled
	_chips.tongue.set_ratio(frog.tongue_power.ready_ratio())
	_chips.slam.visible = frog.slam_power.enabled
	_chips.slam.set_ratio(frog.slam_power.ready_ratio())
	# Poca vita: la barra pulsa.
	var low := float(frog.health) / frog.max_health < HEALTH_LOW and not frog.is_dead
	_health_bar.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012) if low else 1.0


## L'incendio dietro la rana: la distanza, e il bordo dello schermo che si
## arrossa (danger da 0 a 1) quando è vicino.
func set_fire_distance(distance: float, danger: float) -> void:
	_fire_label.text = "%d m" % maxi(roundi(distance), 0)
	_fire_label.add_theme_color_override("font_color", UiTheme.TEXT.lerp(Color(1.0, 0.3, 0.1), danger))
	# Vicino, l'indicatore pulsa.
	var pulse := 1.0 + 0.12 * danger * absf(sin(Time.get_ticks_msec() * 0.008))
	_fire_box.scale = Vector2(pulse, pulse)
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", danger)


func set_flies(count: int, golden := 0) -> void:
	_flies_label.text = str(count)
	_golden_label.text = str(golden)
	_golden_label.visible = golden > 0
	_golden_icon.visible = golden > 0


func set_record(distance: float) -> void:
	_record_distance = distance
	if _record_label:
		_record_label.text = tr("Record %d m") % roundi(distance)


func show_game_over(stats: Dictionary) -> void:
	_game_over_distance.text = "%d m" % roundi(stats.distance)
	if stats.new_record:
		_game_over_record.text = tr("Nuovo record!")
		_game_over_record.add_theme_color_override("font_color", UiTheme.GOLD)
	else:
		_game_over_record.text = tr("Record: %d m") % roundi(stats.record)
	_game_over_text.text = tr("Tane %d   ·   Tempo %d:%02d   ·   Calore massimo %d") % [
		stats.dens, floori(stats.time / 60.0), floori(stats.time) % 60, stats.heat_level]
	if stats.get("test_run", false):
		_game_over_flies.text = tr("Run di prova: le mosche non contano")
	else:
		_game_over_flies.text = tr("+%d mosche, +%d d'oro   (in tutto %d e %d)") % [
			stats.flies, stats.golden, stats.total_flies, stats.total_golden]
	_game_over.visible = true
	# Selezionato, così col controller ci si sposta su Stagno e Menu.
	_restart_button.grab_focus()


## Tutte le scritte della schermata di fine, per i test.
func game_over_text() -> String:
	return "\n".join(_game_over.find_children("*", "Label", true, false).map(func(label): return label.text))


func _on_health_changed(health: int, max_health: int) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_label.text = tr("VITA  %d / %d") % [health, max_health]
	_set_fill(_health_bar, HEALTH_LOW_COLOR if float(health) / max_health < HEALTH_LOW else HEALTH_COLOR)


func _on_heat_changed(value: float, level: int) -> void:
	_heat_meter.value = value
	if level > _last_heat_level:
		_show_message(tr("Calore: livello %d") % level)
		Sfx.play(&"heat_up", 0.0, 1.0 + 0.05 * level)
		# Un nuovo gradino: il calore lampeggia.
		_heat_meter.modulate = Color(2.0, 2.0, 2.0)
		create_tween().set_ignore_time_scale(true).tween_property(_heat_meter, "modulate", Color.WHITE, 0.5)
	_last_heat_level = level
	_heat_label.text = tr("CALORE  %d / %d") % [level, Heat.LEVELS]


func _on_den_reached(count: int, distance: float) -> void:
	_show_message(tr("Tana %d raggiunta! %d m") % [count, roundi(distance)])


func _on_style_changed(style_name: String) -> void:
	_show_message(tr("Stile: %s") % tr(style_name))


## "CATENA ×N" sotto il centro, che pulsa a ogni rottame in più.
func show_chain(count: int) -> void:
	Sfx.play(&"chain_ding", 0.0, minf(1.0 + 0.08 * (count - 4), 2.0))
	_chain_label.text = tr("CATENA ×%d") % count
	_chain_label.modulate.a = 1.0
	_chain_label.scale = Vector2(1.4, 1.4)
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_chain_label, "scale", Vector2.ONE, 0.2)
	tween.tween_interval(1.0)
	tween.tween_property(_chain_label, "modulate:a", 0.0, 0.4)


func announce(text: String) -> void:
	_show_message(text)


## Le carte della tana (tre, o quattro con "Più scelta"). Si sceglie coi
## tasti numerici o col mouse. Ogni carta ha il colore e l'icona del suo
## attrezzo; le carte entrano una dopo l'altra.
func show_offer(options: Array[String], upgrades: Upgrades) -> void:
	_upgrades = upgrades
	_offer_title.text = tr("Tana %d") % course.dens_reached
	for i in _offer_buttons.size():
		var button := _offer_buttons[i]
		button.visible = i < options.size()
		if not button.visible:
			continue
		var id := options[i]
		var item: Dictionary = Upgrades.CATALOG[id]
		var slot: String = item.slot
		var parts: Dictionary = _card_parts[i]
		var color: Color = UiTheme.SLOT_COLORS[slot]
		(parts.icon as SlotIcon).kind = slot
		var slot_label: Label = parts.slot
		slot_label.add_theme_color_override("font_color", color)
		(parts.name as Label).text = tr(item.name)
		(parts.text as Label).text = Settings.with_keys(tr(item.text))
		var tag: Label = parts.tag
		if slot == "fusion":
			slot_label.text = tr("FUSIONE")
			tag.text = tr("Unisce %s e %s") % item.parts.map(func(part): return tr(Upgrades.CATALOG[part].name))
			tag.remove_theme_color_override("font_color")
		elif slot != "":
			slot_label.text = tr(Upgrades.SLOT_NAMES[slot]).to_upper()
			# Uno slot vuoto: la carta dà anche l'attrezzo, cioè un potere nuovo.
			if not upgrades.has_tool(slot) and NEW_POWER.has(slot):
				tag.text = tr(NEW_POWER[slot])
				tag.add_theme_color_override("font_color", UiTheme.GOLD)
			else:
				tag.text = tr("Occupa lo slot fino a fine run")
				tag.remove_theme_color_override("font_color")
		else:
			slot_label.text = tr("POTENZIAMENTO")
			tag.text = tr("Si somma: %d di %d") % [upgrades.stacks.get(id, 0) + 1, item.max]
			tag.remove_theme_color_override("font_color")
		_style_card(button, color)
		# L'entrata: dal basso, una dopo l'altra.
		button.pivot_offset = button.custom_minimum_size / 2.0
		button.modulate.a = 0.0
		button.scale = Vector2(0.85, 0.85)
		var tween := create_tween().set_ignore_time_scale(true).set_parallel()
		tween.tween_property(button, "modulate:a", 1.0, 0.18).set_delay(i * 0.07)
		tween.tween_callback(Sfx.play.bind(&"ui_card_in", 0.0, 1.0 + 0.06 * i)).set_delay(i * 0.07)
		tween.tween_property(button, "scale", Vector2.ONE, 0.28).set_delay(i * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banishing = false
	_update_tokens()
	# Il suggerimento in corso non spunta da sotto le carte.
	_hint.visible = false
	_offer.visible = true
	_offer_buttons[0].grab_focus()


## Il fondo della carta col bordo nel colore dell'attrezzo, più spesso in
## alto; passandoci sopra si schiarisce.
func _style_card(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := UiTheme.box(UiTheme.INK_LIGHT if state.begins_with("hover") else UiTheme.INK_SOFT,
				color if state != "normal" else color.darkened(0.25), 2, 12)
		box.border_width_top = 6
		button.add_theme_stylebox_override(state, box)


func hide_offer() -> void:
	_offer.visible = false


func is_offer_open() -> bool:
	return _offer.visible


## L'equipaggiamento: il modificatore di ogni slot va sotto il suo potere
## (una fusione sotto entrambi); il corpo, che non ha un potere, e i
## potenziamenti numerici in basso a destra.
func show_equipment(upgrades: Upgrades) -> void:
	_upgrades = upgrades
	for power: String in POWERS:
		var slot: String = POWERS[power][2]
		var id: String = upgrades.modifier(slot)
		# Lingua e schianto sono loro stessi il modificatore.
		var shown := id != "" and id != power and not (power == "super_jump" and id == "slam")
		_chips[power].set_modifier(tr(Upgrades.CATALOG[id].name) if shown else "")
	for child in _extras.get_children():
		child.queue_free()
	var body: String = upgrades.modifier("body")
	if body != "":
		_extras.add_child(_extra("body", tr(Upgrades.CATALOG[body].name)))
	for id: String in upgrades.stacks:
		_extras.add_child(_extra("", "%s ×%d" % [tr(Upgrades.CATALOG[id].name), upgrades.stacks[id]]))


func _extra(slot: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	var label := _label(15, text)
	row.add_child(label)
	row.add_child(SlotIcon.make(slot, 22.0))
	return row


func _unhandled_input(event: InputEvent) -> void:
	# Esc mette in pausa solo durante il gioco: non con le carte della tana, la
	# modalità prova aperta (il gioco è già fermo) o a run finita.
	if event.is_action_pressed("pause"):
		# Le opzioni aperte si chiudono da sé con Esc.
		if _options.visible:
			return
		if _pause.visible:
			get_viewport().set_input_as_handled()
			resume()
		# HUD nascosto: la partita fa da sfondo al menu.
		elif visible and not get_tree().paused and not _game_over.visible and not frog.is_dead:
			get_viewport().set_input_as_handled()
			pause()
		return
	# In pausa anche B (indietro) riprende. B è anche lo schianto: la
	# pressione che riprende non deve far piombare giù la rana.
	if _pause.visible and not _options.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		for action: String in Settings.ACTIONS:
			if event.is_action(action):
				Input.action_release(action)
		resume()
		return
	if not _offer.visible or not event is InputEventKey or not event.pressed:
		return
	var index: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(event.physical_keycode)
	if index >= 0 and _offer_buttons[index].visible:
		get_viewport().set_input_as_handled()
		_on_card_pressed(index)


## I comandi scritti sui pulsanti seguono il dispositivo usato per ultimo.
func _update_prompts() -> void:
	_resume_button.text = tr("Riprendi (%s)") % Settings.ui_name("pause")
	_restart_button.text = tr("Ricomincia (%s)") % Settings.ui_name("ui_accept")


## La pausa: il gioco si ferma, il mouse si libera.
func pause() -> void:
	Sfx.play(&"ui_pause")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause.visible = true
	_resume_button.grab_focus()


func resume() -> void:
	Sfx.play(&"ui_resume")
	_pause.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_paused() -> bool:
	return _pause.visible


func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_interval(1.5)
	tween.tween_property(_message, "modulate:a", 0.0, 0.5)


func _build_top_left() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(20, 18)
	box.add_theme_constant_override("separation", 8)
	_root.add_child(box)
	_health_bar = _bar(Vector2(300, 26), HEALTH_COLOR)
	box.add_child(_health_bar)
	_health_label = _inside(_health_bar)
	_heat_meter = HeatMeter.new()
	_heat_meter.custom_minimum_size = Vector2(300, 26)
	box.add_child(_heat_meter)
	_heat_label = _inside(_heat_meter)


## Una scritta dentro una barra, a sinistra.
func _inside(bar: Control) -> Label:
	var label := _label(15)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 10
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)
	return label


func _build_top_right() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -360
	box.offset_right = -20
	box.offset_top = 10
	box.add_theme_constant_override("separation", 2)
	_root.add_child(box)
	_distance_label = _label(46)
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_distance_label)
	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_END
	info.add_theme_constant_override("separation", 14)
	box.add_child(info)
	_dens_label = _label(16)
	info.add_child(_dens_label)
	_record_label = _label(16)
	_record_label.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	info.add_child(_record_label)
	var flies := HBoxContainer.new()
	flies.alignment = BoxContainer.ALIGNMENT_END
	flies.add_theme_constant_override("separation", 6)
	box.add_child(flies)
	flies.add_child(SlotIcon.make("fly", 28.0))
	_flies_label = _label(22, "0")
	_flies_label.add_theme_color_override("font_color", UiTheme.GOLD)
	flies.add_child(_flies_label)
	_golden_icon = SlotIcon.make("golden", 28.0)
	_golden_icon.visible = false
	flies.add_child(_golden_icon)
	_golden_label = _label(22, "0")
	_golden_label.add_theme_color_override("font_color", UiTheme.GOLD)
	_golden_label.visible = false
	flies.add_child(_golden_label)


func _build_powers() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 20
	# Cresce verso l'alto quando si aggiungono lingua e schianto.
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_top = -20
	box.offset_bottom = -20
	box.add_theme_constant_override("separation", 6)
	_root.add_child(box)
	for power: String in POWERS:
		var chip := PowerChip.make(POWERS[power][0], POWERS[power][1], POWERS[power][2])
		box.add_child(chip)
		_chips[power] = chip


func _build_fire() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float edge = smoothstep(0.35, 0.75, length(UV - vec2(0.5)) * 1.2);
	COLOR = vec4(0.9, 0.15, 0.0, edge * strength * 0.75);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_vignette.material = material
	_root.add_child(_vignette)
	_root.move_child(_vignette, 0)
	# L'incendio, in basso al centro: la fiamma e i metri che mancano.
	_fire_box = HBoxContainer.new()
	_fire_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_fire_box.offset_left = -80
	_fire_box.offset_right = 80
	_fire_box.offset_top = -56
	_fire_box.offset_bottom = -20
	_fire_box.pivot_offset = Vector2(80, 18)
	_fire_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_fire_box.add_theme_constant_override("separation", 6)
	_root.add_child(_fire_box)
	_fire_box.add_child(SlotIcon.make("fire", 32.0))
	_fire_label = _label(22, "")
	_fire_box.add_child(_fire_label)


func _build_message() -> void:
	_message = _label(42)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.offset_left = -400
	_message.offset_right = 400
	_message.offset_top = 90
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	_root.add_child(_message)


func _build_chain_label() -> void:
	_chain_label = _label(52)
	_chain_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_chain_label.offset_left = -300
	_chain_label.offset_right = 300
	_chain_label.offset_top = 60
	_chain_label.offset_bottom = 120
	_chain_label.pivot_offset = Vector2(300, 30)
	_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chain_label.add_theme_color_override("font_color", UiTheme.GOLD)
	_chain_label.modulate.a = 0.0
	_root.add_child(_chain_label)


func _build_offer() -> void:
	# Il pannello si adatta al numero di carte e resta al centro.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_offer = PanelContainer.new()
	_offer.visible = false
	center.add_child(_offer)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_offer.add_child(box)
	_offer_title = _text("Title")
	box.add_child(_offer_title)
	_offer_hint = _text("Note")
	box.add_child(_offer_hint)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	box.add_child(cards)
	for i in MAX_CARDS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(264, 330)
		button.pressed.connect(_on_card_pressed.bind(i))
		# La scelta suona in Game (anche coi tasti numerici): niente clic.
		button.set_meta("sfx", "")
		cards.add_child(button)
		_offer_buttons.append(button)
		_card_parts.append(_build_card(button, i))
	# I gettoni: solo quelli sbloccati, con gli usi rimasti.
	var tokens := HBoxContainer.new()
	tokens.alignment = BoxContainer.ALIGNMENT_CENTER
	tokens.add_theme_constant_override("separation", 14)
	box.add_child(tokens)
	for kind: String in TOKEN_NAMES:
		var token := _button("", _on_token.bind(kind), "DangerButton" if kind == "banish" else "")
		token.add_theme_font_size_override("font_size", 20)
		tokens.add_child(token)
		_token_buttons[kind] = token


## Il contenuto di una carta, sopra il pulsante (che riceve i clic).
func _build_card(button: Button, index: int) -> Dictionary:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 20)
	button.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var band := HBoxContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_constant_override("separation", 10)
	box.add_child(band)
	var icon := SlotIcon.make("", 44.0)
	band.add_child(icon)
	var slot := _text("Strong")
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(slot)
	var name_label := _text("Header")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var tag := _text("Note")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tag)
	var text := _text("")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 17)
	box.add_child(text)
	var key := _text("Strong", str(index + 1))
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	box.add_child(key)
	return {"icon": icon, "slot": slot, "name": name_label, "tag": tag, "text": text}


func _on_card_pressed(index: int) -> void:
	if _banishing:
		_banishing = false
		token_used.emit("banish", index)
		return
	_upgrades.choose(index)


func _on_token(kind: String) -> void:
	if kind == "banish":
		# Esilia aspetta la carta; di nuovo, annulla.
		_banishing = not _banishing
		_update_tokens()
		return
	_banishing = false
	token_used.emit(kind, -1)


## I gettoni: visibili se sbloccati, coi loro usi; Esilia dice cosa aspetta.
func _update_tokens() -> void:
	for kind: String in _token_buttons:
		var button: Button = _token_buttons[kind]
		var left: int = _upgrades.tokens.get(kind, 0) if _upgrades else 0
		var unlocked := Feats.all_open() or Feats.done(Upgrades.TOKENS[kind])
		button.visible = unlocked
		button.disabled = left <= 0
		button.text = tr("%s (%d)") % [tr(TOKEN_NAMES[kind]), left]
	if _banishing:
		_token_buttons.banish.text = tr("Esilia: scegli la carta (annulla)")
		_offer_hint.text = tr("Esilia: la carta che scegli esce dal mazzo per il resto della run")
	else:
		_offer_hint.text = tr("Scegli un potenziamento: tasti 1-%d o clic") % MAX_CARDS


func _build_equipment() -> void:
	_extras = VBoxContainer.new()
	_extras.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_extras.offset_left = -360
	_extras.offset_right = -20
	_extras.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_extras.offset_top = -20
	_extras.offset_bottom = -20
	_extras.add_theme_constant_override("separation", 4)
	_root.add_child(_extras)


func _build_game_over() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_game_over = PanelContainer.new()
	_game_over.visible = false
	center.add_child(_game_over)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 460
	box.add_theme_constant_override("separation", 10)
	_game_over.add_child(box)
	box.add_child(_text("Header", "Fine della corsa"))
	# La distanza in grande: è il numero della run.
	_game_over_distance = _text("Logo")
	box.add_child(_game_over_distance)
	_game_over_record = _text("Strong")
	_game_over_record.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	box.add_child(_game_over_record)
	_game_over_text = _text("Note")
	box.add_child(_game_over_text)
	var flies := HBoxContainer.new()
	flies.alignment = BoxContainer.ALIGNMENT_CENTER
	flies.add_theme_constant_override("separation", 8)
	box.add_child(flies)
	flies.add_child(SlotIcon.make("fly", 30.0))
	_game_over_flies = _text("Strong")
	_game_over_flies.add_theme_color_override("font_color", UiTheme.GOLD)
	flies.add_child(_game_over_flies)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	box.add_child(gap)
	_restart_button = _button("", restart_requested.emit, "PrimaryButton")
	box.add_child(_restart_button)
	_pond_note = _text("Note")
	_pond_note.add_theme_color_override("font_color", UiTheme.GOLD)
	_pond_note.visible = false
	box.add_child(_pond_note)
	_pond_button = _button("Lo stagno", _open_pond)
	box.add_child(_pond_button)
	box.add_child(_button("Menu", menu_requested.emit, "FlatButton"))
	_pond = Pond.new()
	_pond.visible = false
	_root.add_child(_pond)


func _build_pause() -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0, 0, 0, 0.55)
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_root.add_child(_pause)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 360
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_text("Title", "Pausa"))
	_resume_button = _button("", resume, "PrimaryButton")
	box.add_child(_resume_button)
	box.add_child(_button("Opzioni", _open_options))
	box.add_child(_button("Abbandona la run", abandon_requested.emit))
	box.add_child(_text("Note", "Abbandonando, le mosche raccolte restano."))
	# Le opzioni coprono la pausa; chiuse, si torna a Riprendi.
	_options = OptionsPanel.new()
	_options.visible = false
	_options.closed.connect(_resume_button.grab_focus)
	_pause.add_child(_options)


func _open_options() -> void:
	_options.open()


## Il suggerimento: un riquadro in basso al centro, sopra l'incendio, coi
## comandi in oro (BBCode). Entra dal basso.
func show_hint(text: String) -> void:
	_set_hint_text(text)
	if _hint_tween:
		_hint_tween.kill()
	_hint.visible = true
	_hint.modulate = Color.WHITE
	_hint.modulate.a = 0.0
	_hint.position.y = _hint_rest_y() + 16.0
	_hint_tween = create_tween().set_ignore_time_scale(true).set_parallel()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.25)
	_hint_tween.tween_property(_hint, "position:y", _hint_rest_y(), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"ui_card_in", -4.0, 1.3)


## Il suggerimento se ne va: eseguito (un lampo verde) o scaduto.
func clear_hint(done: bool) -> void:
	if not _hint.visible:
		return
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween().set_ignore_time_scale(true)
	if done:
		_hint.modulate = Color(UiTheme.DONE, 1.0) * 1.4
		Sfx.play(&"power_ready", -2.0, 1.5)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.5 if done else 0.35)
	_hint_tween.tween_callback(func() -> void: _hint.visible = false)


## Lo stesso suggerimento, riscritto (comandi o lingua cambiati).
func update_hint(text: String) -> void:
	_set_hint_text(text)
	_place_hint()


## Il testo nuovo, e il riquadro che si stringe attorno (non si restringe da
## solo: un testo lungo prima di uno corto lo lascerebbe alto).
func _set_hint_text(text: String) -> void:
	_hint_text.text = "[center]%s[/center]" % text
	_hint.reset_size()


func hint_text() -> String:
	return _hint_text.get_parsed_text() if _hint.visible else ""


## Alla fine della corsa, con le mosche in tasca: lo stagno pulsa d'oro e una
## riga dice perché ("" per spegnerlo).
func highlight_pond(note: String) -> void:
	_pond_note.text = note
	_pond_note.visible = note != ""
	if _pond_tween:
		_pond_tween.kill()
	_pond_button.modulate = Color.WHITE
	if note == "":
		return
	_pond_tween = create_tween().set_ignore_time_scale(true).set_loops()
	_pond_tween.tween_property(_pond_button, "modulate", Color(1.5, 1.25, 0.6), 0.5)
	_pond_tween.tween_property(_pond_button, "modulate", Color.WHITE, 0.5)


## Un'impresa fatta: scende dall'alto, resta qualche secondo e risale. Non
## ferma il gioco. ready: quello che sblocca c'è già nel gioco.
func show_feat(title: String, reward: String, ready: bool) -> void:
	_feat_title.text = tr("Impresa: %s") % title
	_feat_reward.text = (tr("Sbloccata: %s") if ready else tr("Sbloccata (arriva più avanti): %s")) % reward
	_feat.reset_size()
	_feat.position.x = (_root.size.x - _feat.size.x) / 2.0
	if _feat_tween:
		_feat_tween.kill()
	_feat.visible = true
	_feat.position.y = -_feat.size.y
	_feat_tween = create_tween().set_ignore_time_scale(true)
	_feat_tween.tween_property(_feat, "position:y", 150.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feat_tween.tween_interval(3.2)
	_feat_tween.tween_property(_feat, "position:y", -_feat.size.y, 0.3).set_ease(Tween.EASE_IN)
	_feat_tween.tween_callback(func() -> void: _feat.visible = false)
	Sfx.play(&"ui_record")


func feat_text() -> String:
	return "%s\n%s" % [_feat_title.text, _feat_reward.text] if _feat.visible else ""


func _build_feat() -> void:
	_feat = PanelContainer.new()
	_feat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiTheme.box(Color(UiTheme.INK, 0.92), UiTheme.GOLD, 3, 12)
	box.set_content_margin_all(14)
	box.content_margin_left = 26
	box.content_margin_right = 26
	_feat.add_theme_stylebox_override("panel", box)
	_feat.visible = false
	_root.add_child(_feat)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_feat.add_child(column)
	_feat_title = _text("Header")
	_feat_title.add_theme_color_override("font_color", UiTheme.GOLD)
	column.add_child(_feat_title)
	_feat_reward = _text("Strong")
	column.add_child(_feat_reward)


func _hint_rest_y() -> float:
	return _root.size.y - 84.0 - _hint.size.y


func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiTheme.box(Color(UiTheme.INK, 0.88), UiTheme.GOLD, 0, 10)
	box.border_width_left = 4
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	_hint.add_theme_stylebox_override("panel", box)
	_hint.visible = false
	_root.add_child(_hint)
	_hint_text = RichTextLabel.new()
	_hint_text.bbcode_enabled = true
	_hint_text.fit_content = true
	_hint_text.scroll_active = false
	_hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# La larghezza fissa dice dove andare a capo; l'altezza segue il testo.
	_hint_text.custom_minimum_size.x = 680
	_hint_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_text.add_theme_font_override("normal_font", UiTheme.bold_font())
	_hint_text.add_theme_font_size_override("normal_font_size", 20)
	_hint_text.add_theme_color_override("default_color", UiTheme.TEXT)
	_hint.add_child(_hint_text)
	# Centrato in orizzontale, appoggiato sopra l'incendio.
	_hint.resized.connect(_place_hint)
	_root.resized.connect(_place_hint)


func _place_hint() -> void:
	_hint.position.x = (_root.size.x - _hint.size.x) / 2.0
	if not (_hint_tween and _hint_tween.is_running()):
		_hint.position.y = _hint_rest_y()


func _open_pond() -> void:
	_pond.refresh()
	_pond.visible = true
	pond_opened.emit()


## Una scritta sopra il mondo, col bordo scuro (grande da 36 in su).
func _label(font_size: int, text := "") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "HudBig" if font_size >= 36 else "HudLabel"
	label.add_theme_font_size_override("font_size", font_size)
	return label


## Una scritta dentro un pannello, con una variante del tema ("Title"...).
func _text(variation: String, text := "") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(text: String, action: Callable, variation := "") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.pressed.connect(action)
	return button


func _bar(size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	_set_fill(bar, color)
	return bar


func _set_fill(bar: ProgressBar, color: Color) -> void:
	var fill := UiTheme.box(color, color, 0, 4)
	bar.add_theme_stylebox_override("fill", fill)
