class_name FrogsPanel
extends PanelContainer
## La scelta della rana (vedi Frogs), a tutto schermo come lo stagno: una
## tessera per rana con l'attrezzo con cui parte, il pro e il contro. Quelle
## ancora chiuse dicono quale impresa le sblocca. La scelta si salva e vale
## anche per "Ricomincia". Esc (o B) chiude.

signal closed
## Scelta una rana (il menu la mostra subito sullo sfondo).
signal chosen(id: String)

const COLUMNS := 3
## L'icona dell'attrezzo iniziale di ogni rana.
const ICONS := {"comune": "gloves", "raganella": "springs", "paracadutista": "wing", "fiume": "body", "camaleonte": "tongue", "rospo": ""}

var _grid: GridContainer
var _scroll: ScrollContainer
var _esc_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	theme_type_variation = "Backdrop"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(_label("Le rane", "Title"))
	var note := _label("Ogni rana parte con un solo attrezzo: gli altri arrivano dalle carte delle tane.", "Note")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	_scroll = scroll
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 14)
	scroll.add_child(margin)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(_grid)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_esc_label = _label("", "Note")
	_esc_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_esc_label)
	footer.add_child(_button("Chiudi", _close))
	Settings.changed.connect(_update_esc)
	_update_esc()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _grid != null:
		refresh()


func open() -> void:
	refresh()
	visible = true
	var current := _grid.get_node_or_null(Frogs.selected())
	if current:
		(current.find_children("*", "Button", true, false)[0] as Button).grab_focus()
		# Una rana della prima fila: la griglia resta in cima, coi nomi in vista.
		if current.get_index() < COLUMNS:
			_top.call_deferred()


func _top() -> void:
	_scroll.scroll_vertical = 0


func refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for id: String in Frogs.ALL:
		_grid.add_child(_tile(id))


## Una rana: icona e nome, l'attrezzo con cui parte, il pro, il contro e il
## pulsante per sceglierla (o l'impresa che la sblocca).
func _tile(id: String) -> PanelContainer:
	var frog: Dictionary = Frogs.ALL[id]
	var open_frog := Frogs.unlocked(id)
	var chosen_now := id == Frogs.selected()
	var slot: String = ICONS[id]
	var color: Color = UiTheme.SLOT_COLORS[slot] if slot != "" else UiTheme.LINE
	var tile := PanelContainer.new()
	tile.name = id
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiTheme.box(UiTheme.INK_LIGHT, UiTheme.GOLD if chosen_now else color, 3 if chosen_now else 0, 10)
	box.border_width_top = 5
	box.set_content_margin_all(14)
	tile.add_theme_stylebox_override("panel", box)
	if not open_frog:
		tile.modulate = Color(1, 1, 1, 0.6)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	tile.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	if slot != "":
		head.add_child(SlotIcon.make(slot, 32.0))
	var title := _label(tr(frog.name), "Header")
	title.add_theme_font_size_override("font_size", 24)
	head.add_child(title)
	column.add_child(_line(tr("Parte con: %s") % Frogs.kit_text(id), UiTheme.TEXT_MUTED))
	column.add_child(_line("+ " + tr(frog.pro), UiTheme.DONE))
	column.add_child(_line("− " + tr(frog.contro), Color(1.0, 0.55, 0.45)))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)
	if open_frog:
		var pick := _button(tr("Scelta") if chosen_now else tr("Scegli"), _choose.bind(id), "PrimaryButton" if not chosen_now else "")
		column.add_child(pick)
	else:
		var feat: Dictionary = Feats.ALL[Frogs.unlock_feat(id)]
		var lock := _line(tr("Si sblocca con l'impresa «%s»: %s") % [tr(feat.name), tr(feat.text)], UiTheme.GOLD)
		column.add_child(lock)
		# Una rana chiusa resta raggiungibile col controller, ma non si sceglie.
		var locked := _button(tr("Chiusa"), func() -> void: pass)
		locked.disabled = true
		column.add_child(locked)
	return tile


func _choose(id: String) -> void:
	Progress.frog = id
	Progress.save()
	chosen.emit(id)
	refresh()
	var tile := _grid.get_node_or_null(id)
	if tile:
		(tile.find_children("*", "Button", true, false)[0] as Button).grab_focus()


func _line(text: String, color: Color) -> Label:
	var label := _label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	return label


func _update_esc() -> void:
	_esc_label.text = Settings.ui_name("ui_cancel")


func _close() -> void:
	visible = false
	closed.emit()


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
