class_name OptionsPanel
extends PanelContainer
## Le opzioni, a tutto schermo come lo stagno: quattro schede (generale,
## audio, grafica, controlli). Ogni modifica si applica subito; i cursori salvano quando si
## chiude. I tasti si riassegnano cliccando e premendo il tasto nuovo (o un
## pulsante del mouse, o un pulsante del controller nella sua colonna); Esc
## o Start annullano. Col controller LB e RB cambiano scheda. Lo usano il
## menu iniziale e la pausa.

signal closed

## Larghezza della colonna dei comandi, a destra di ogni riga.
const CONTROL_WIDTH := 420
const KEY_WIDTH := 204

## Chi rimette ogni comando al valore delle opzioni (dopo un ripristino).
var _updaters: Array[Callable] = []
## I pulsanti dei comandi: per azione, [tastiera e mouse, controller].
var _key_buttons := {}
## L'azione che aspetta il comando nuovo ("" se nessuna), e da quale
## dispositivo.
var _waiting := ""
var _waiting_pad := false
var _esc_label: Label
var _reset_button: Button
var _reset_armed := false
var _tabs: TabContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	theme_type_variation = "Backdrop"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(_label("Opzioni", "Title"))

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tabs)
	_build_general(_page("Generale"))
	_build_audio(_page("Audio"))
	_build_graphics(_page("Grafica"))
	_build_controls(_page("Controlli"))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	_reset_button = _button("", _reset, "DangerButton")
	footer.add_child(_reset_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_esc_label = _label("", "Note")
	_esc_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_esc_label)
	footer.add_child(_button("Chiudi", _close))
	Style.style_changed.connect(refresh.unbind(1))
	# Anche quando si passa dalla tastiera al controller: cambiano i nomi.
	Settings.changed.connect(_refresh_names)
	refresh()


## Mentre si aspetta un tasto nuovo, il primo tasto o pulsante premuto è
## quello: non arriva né ai pulsanti né al gioco.
func _input(event: InputEvent) -> void:
	if _waiting == "" or not visible:
		return
	var cancel: bool = (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	if cancel:
		get_viewport().set_input_as_handled()
		_stop_waiting()
		Sfx.play(&"ui_back")
	elif (Settings.can_bind_pad(event) if _waiting_pad else Settings.can_bind(event)):
		get_viewport().set_input_as_handled()
		Settings.rebind(_waiting, event)
		_stop_waiting()
		Sfx.play(&"ui_click")
	elif _waiting_pad and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		# La croce e le levette, mentre si aspetta, non spostano la selezione.
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		get_viewport().set_input_as_handled()
		var step := -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1
		_tabs.current_tab = wrapi(_tabs.current_tab + step, 0, _tabs.get_tab_count())
		_tabs.get_tab_bar().grab_focus()


func open() -> void:
	refresh()
	visible = true
	_tabs.get_tab_bar().grab_focus()


## Rimette ogni comando al valore attuale delle opzioni.
func refresh() -> void:
	_refresh_names()
	_reset_armed = false
	_update_reset_button()


func _refresh_names() -> void:
	for updater in _updaters:
		updater.call()
	_esc_label.text = Settings.ui_name("ui_cancel")
	_update_reset_button()


## Cambiata la lingua, si riscrivono i valori (le scritte fisse si traducono
## da sole).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _esc_label != null:
		_refresh_names()


# --- Le schede -----------------------------------------------------------------

func _build_general(page: VBoxContainer) -> void:
	# I nomi delle lingue non si traducono: ognuna si chiama come si chiama.
	# Scritta in tutte e due le lingue: la trova anche chi non legge quella
	# attuale.
	_choice(page, "Lingua · Language", "language", Settings.LANGUAGE_NAMES, func() -> int: return Settings.LANGUAGES.find(Settings.language))
	_slider(page, "Scossa della telecamera", "shake", 0.0, 1.0, 0.05, _percent)
	_toggle(page, "Lampo a ogni livello di calore", "flashes")
	_toggle(page, "Suggerimenti", "hints")
	var again := _button("Rivedi i suggerimenti", _reset_hints, "FlatButton")
	again.name = "hints_again"
	again.size_flags_horizontal = Control.SIZE_SHRINK_END
	page.add_child(again)
	page.add_child(_note("I suggerimenti del primo minuto spariscono dopo che li hai eseguiti in due corse. Rivederli li rimette tutti."))
	_toggle(page, "Tutto sbloccato (per provare)", "unlock_everything")
	page.add_child(_note("Tutte le rane e tutte le carte, subito. Le run contano come prove: niente record, mosche né imprese. Spento, torna tutto com'era."))


func _build_audio(page: VBoxContainer) -> void:
	_slider(page, "Volume generale", "master_volume", 0.0, 1.0, 0.05, _percent)
	var effects := _slider(page, "Effetti", "effects_volume", 0.0, 1.0, 0.05, _percent)
	# Lasciando il cursore, un gracidio per sentire il volume nuovo.
	effects.drag_ended.connect(func(_changed: bool) -> void: Sfx.play(&"frog_croak", 0.0, 1.0, true))
	_slider(page, "Musica", "music_volume", 0.0, 1.0, 0.05, _percent)
	page.add_child(_note("La musica arriverà più avanti."))


func _build_graphics(page: VBoxContainer) -> void:
	var names: Array = Style.styles.map(func(style: Dictionary) -> String: return style.name)
	_choice(page, "Stile grafico", "style", names, func() -> int: return Style.current)
	page.add_child(_note("Si cambia anche in gioco, con F2."))
	_choice(page, "Schermo", "window_mode", Settings.WINDOW_MODES)
	# Nel browser la sincronia la decide il browser.
	if not OS.has_feature("web"):
		_toggle(page, "Sincronia verticale (V-Sync)", "vsync")
	var limits: Array = Settings.FPS_LIMITS.map(func(fps: int) -> String: return "Nessuno" if fps == 0 else "%d fps" % fps)
	_choice(page, "Limite dei fotogrammi", "fps_limit", limits)
	_slider(page, "Risoluzione del mondo", "render_scale", 0.5, 1.0, 0.05, _percent)
	page.add_child(_note("Più bassa, il gioco va più veloce sui computer lenti; l'interfaccia resta nitida."))


func _build_controls(page: VBoxContainer) -> void:
	_slider(page, "Sensibilità del mouse", "mouse_sensitivity", 0.25, 3.0, 0.05, _percent)
	_slider(page, "Sensibilità della levetta", "stick_sensitivity", 0.25, 3.0, 0.05, _percent)
	_toggle(page, "Inverti l'asse verticale", "invert_y")
	_toggle(page, "Vibrazione del controller", "vibration")
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	page.add_child(gap)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	page.add_child(head)
	var title := _label("Comandi", "Header")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for name_label in [_label("Tastiera e mouse", "Note"), _label("Controller", "Note")]:
		name_label.custom_minimum_size.x = KEY_WIDTH
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(name_label)
	page.add_child(_note("Scegli un comando e premi il tasto nuovo (nella colonna del controller, un pulsante o un grilletto); Esc o Start annullano. Se era già di un'altra azione, le due si scambiano."))
	for action: String in Settings.ACTIONS:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 12)
		var keys := _button("", _start_waiting.bind(action, false))
		keys.custom_minimum_size.x = KEY_WIDTH
		pair.add_child(keys)
		var pad := _button("", _start_waiting.bind(action, true))
		pad.custom_minimum_size.x = KEY_WIDTH
		# Sul controller ci si muove con la levetta (o la croce): fisso.
		pad.disabled = action in Settings.MOVES
		pair.add_child(pad)
		_key_buttons[action] = [keys, pad]
		_row(page, Settings.ACTIONS[action], pair)
		_updaters.append(_update_key.bind(action))
	var keys_reset := _button("Rimetti i comandi predefiniti", _reset_keys, "FlatButton")
	keys_reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	page.add_child(keys_reset)
	page.add_child(_note("Fissi: Esc (pausa), 1-4 (carte della tana), F1 (modalità prova), F2 (stile grafico). Sul controller: la levetta destra guarda intorno, Start è la pausa, A conferma e B torna indietro nei menu, LB e RB cambiano scheda."))


# --- I comandi -----------------------------------------------------------------

## Un cursore con il valore scritto accanto. Applica a ogni passo e salva
## quando si chiude il pannello.
func _slider(page: VBoxContainer, title: String, option: String, low: float, high: float, step: float, format: Callable) -> HSlider:
	var box := HBoxContainer.new()
	box.custom_minimum_size.x = CONTROL_WIDTH
	box.add_theme_constant_override("separation", 14)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.name = option
	box.add_child(slider)
	var value := _label("", "Strong")
	value.custom_minimum_size.x = 64
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(value)
	slider.value_changed.connect(func(amount: float) -> void:
		value.text = format.call(amount)
		if not is_equal_approx(amount, Settings.get(option)):
			Settings.set_option(option, amount, false))
	_updaters.append(func() -> void:
		slider.set_value_no_signal(Settings.get(option))
		value.text = format.call(slider.value))
	_row(page, title, box)
	return slider


## Un pulsante che passa al valore successivo a ogni clic. current dice il
## valore attuale (di norma l'opzione stessa). I valori si traducono.
func _choice(page: VBoxContainer, title: String, option: String, values: Array, current := Callable()) -> Button:
	var read := current if current.is_valid() else func() -> int: return Settings.get(option)
	var button := _button("", func() -> void: Settings.set_option(option, (read.call() + 1) % values.size()))
	button.name = option
	button.custom_minimum_size.x = CONTROL_WIDTH
	_updaters.append(func() -> void: button.text = tr(values[read.call()]))
	button.pressed.connect(refresh)
	_row(page, title, button)
	return button


func _toggle(page: VBoxContainer, title: String, option: String) -> Button:
	var button := _button("", func() -> void: Settings.set_option(option, not Settings.get(option)))
	button.name = option
	button.custom_minimum_size.x = CONTROL_WIDTH
	_updaters.append(func() -> void: button.text = tr("Sì") if Settings.get(option) else tr("No"))
	button.pressed.connect(refresh)
	_row(page, title, button)
	return button


## Una riga: il nome a sinistra, il comando a destra.
func _row(page: VBoxContainer, title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	page.add_child(row)
	var label := _label(title, "Strong")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)


# --- I tasti -------------------------------------------------------------------

func _start_waiting(action: String, pad: bool) -> void:
	_stop_waiting()
	_waiting = action
	_waiting_pad = pad
	var button: Button = _key_buttons[action][1 if pad else 0]
	button.text = tr("Premi un pulsante…") if pad else tr("Premi un tasto…")
	button.add_theme_color_override("font_color", UiTheme.GOLD)
	button.add_theme_color_override("font_focus_color", UiTheme.GOLD)


func _stop_waiting() -> void:
	var action := _waiting
	_waiting = ""
	if action != "":
		for button: Button in _key_buttons[action]:
			button.remove_theme_color_override("font_color")
			button.remove_theme_color_override("font_focus_color")
	refresh()


func _update_key(action: String) -> void:
	for pad in [false, true]:
		if action != _waiting or pad != _waiting_pad:
			(_key_buttons[action][1 if pad else 0] as Button).text = Settings.key_name(action, pad)


func _reset_hints() -> void:
	Progress.reset_hints()
	Sfx.play(&"ui_refund")


func _reset_keys() -> void:
	Settings.reset(true)
	refresh()


# --- Ripristino e chiusura -----------------------------------------------------

## Il ripristino di tutto chiede conferma, come il rimborso dello stagno.
func _reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_update_reset_button()
		get_tree().create_timer(3.0, true).timeout.connect(_disarm_reset)
		return
	Settings.reset()
	Sfx.play(&"ui_refund")
	refresh()


func _disarm_reset() -> void:
	if _reset_armed:
		_reset_armed = false
		_update_reset_button()


func _update_reset_button() -> void:
	_reset_button.text = tr("Sicura? Premi di nuovo") if _reset_armed else tr("Valori predefiniti")


func _close() -> void:
	if _waiting != "":
		_stop_waiting()
	_disarm_reset()
	Settings.save()
	visible = false
	closed.emit()


# --- Pezzi ---------------------------------------------------------------------

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Spostandosi coi tasti o col controller, la riga scelta resta in vista.
	scroll.follow_focus = true
	_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Spazio per la barra di scorrimento.
	margin.add_theme_constant_override("margin_right", 14)
	scroll.add_child(margin)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	return page


static func _percent(amount: float) -> String:
	return "%d%%" % roundi(amount * 100.0)


func _note(text: String) -> Label:
	var label := _label(text, "Note")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(text: String, variation := "") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _button(text: String, action: Callable, variation := "") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	return button
