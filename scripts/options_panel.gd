class_name OptionsPanel
extends PanelContainer
## Le opzioni, a tutto schermo come lo stagno: tre schede (audio, grafica,
## controlli). Ogni modifica si applica subito; i cursori salvano quando si
## chiude. I tasti si riassegnano cliccando e premendo il tasto nuovo (o un
## pulsante del mouse); Esc annulla. Lo usano il menu iniziale e la pausa.

signal closed

## Larghezza della colonna dei comandi, a destra di ogni riga.
const CONTROL_WIDTH := 420

## Chi rimette ogni comando al valore delle opzioni (dopo un ripristino).
var _updaters: Array[Callable] = []
var _key_buttons := {}
## L'azione che aspetta il tasto nuovo ("" se nessuna).
var _waiting := ""
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
	var esc := _label("Esc", "Note")
	esc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(esc)
	footer.add_child(_button("Chiudi", _close))
	Style.style_changed.connect(refresh.unbind(1))
	refresh()


## Mentre si aspetta un tasto nuovo, il primo tasto o pulsante premuto è
## quello: non arriva né ai pulsanti né al gioco.
func _input(event: InputEvent) -> void:
	if _waiting == "" or not visible:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_stop_waiting()
		Sfx.play(&"ui_back")
	elif Settings.can_bind(event):
		get_viewport().set_input_as_handled()
		Settings.rebind(_waiting, event)
		_stop_waiting()
		Sfx.play(&"ui_click")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func open() -> void:
	refresh()
	visible = true
	_tabs.get_tab_bar().grab_focus()


## Rimette ogni comando al valore attuale delle opzioni.
func refresh() -> void:
	for updater in _updaters:
		updater.call()
	_reset_armed = false
	_update_reset_button()


# --- Le schede -----------------------------------------------------------------

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
	_toggle(page, "Sincronia verticale (V-Sync)", "vsync")
	var limits: Array = Settings.FPS_LIMITS.map(func(fps: int) -> String: return "Nessuno" if fps == 0 else "%d al secondo" % fps)
	_choice(page, "Limite dei fotogrammi", "fps_limit", limits)
	_slider(page, "Risoluzione del mondo", "render_scale", 0.5, 1.0, 0.05, _percent)
	page.add_child(_note("Più bassa, il gioco va più veloce sui computer lenti; l'interfaccia resta nitida."))
	_slider(page, "Scossa della telecamera", "shake", 0.0, 1.0, 0.05, _percent)
	_toggle(page, "Lampo a ogni livello di calore", "flashes")


func _build_controls(page: VBoxContainer) -> void:
	_slider(page, "Sensibilità del mouse", "mouse_sensitivity", 0.25, 3.0, 0.05, _percent)
	_toggle(page, "Inverti l'asse verticale", "invert_y")
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	page.add_child(gap)
	page.add_child(_label("Tasti", "Header"))
	page.add_child(_note("Clicca un comando e premi il tasto o il pulsante del mouse nuovo; Esc annulla. Se il tasto era già di un'altra azione, le due si scambiano."))
	for action: String in Settings.ACTIONS:
		var button := _button("", _start_waiting.bind(action))
		button.custom_minimum_size.x = CONTROL_WIDTH
		_key_buttons[action] = button
		_row(page, Settings.ACTIONS[action], button)
		_updaters.append(_update_key.bind(action))
	var keys_reset := _button("Rimetti i tasti predefiniti", _reset_keys, "FlatButton")
	keys_reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	page.add_child(keys_reset)
	page.add_child(_note("Fissi: Esc (pausa), 1-4 (carte della tana), F1 (modalità prova), F2 (stile grafico)."))


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
## valore attuale (di norma l'opzione stessa).
func _choice(page: VBoxContainer, title: String, option: String, values: Array, current := Callable()) -> Button:
	var read := current if current.is_valid() else func() -> int: return Settings.get(option)
	var button := _button("", func() -> void: Settings.set_option(option, (read.call() + 1) % values.size()))
	button.name = option
	button.custom_minimum_size.x = CONTROL_WIDTH
	_updaters.append(func() -> void: button.text = values[read.call()])
	button.pressed.connect(refresh)
	_row(page, title, button)
	return button


func _toggle(page: VBoxContainer, title: String, option: String) -> Button:
	var button := _button("", func() -> void: Settings.set_option(option, not Settings.get(option)))
	button.name = option
	button.custom_minimum_size.x = CONTROL_WIDTH
	_updaters.append(func() -> void: button.text = "Sì" if Settings.get(option) else "No")
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

func _start_waiting(action: String) -> void:
	_stop_waiting()
	_waiting = action
	var button: Button = _key_buttons[action]
	button.text = "Premi un tasto…"
	button.add_theme_color_override("font_color", UiTheme.GOLD)
	button.add_theme_color_override("font_focus_color", UiTheme.GOLD)


func _stop_waiting() -> void:
	var action := _waiting
	_waiting = ""
	if action != "":
		var button: Button = _key_buttons[action]
		button.remove_theme_color_override("font_color")
		button.remove_theme_color_override("font_focus_color")
	refresh()


func _update_key(action: String) -> void:
	if action != _waiting:
		(_key_buttons[action] as Button).text = Settings.key_name(action)


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
	_reset_button.text = "Sicura? Premi di nuovo" if _reset_armed else "Valori predefiniti"


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
