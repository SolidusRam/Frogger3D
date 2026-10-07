class_name FeatsPanel
extends PanelContainer
## Le imprese (vedi Feats), a tutto schermo come lo stagno: per sezione, ogni
## impresa col suo nome, cosa chiede e cosa sblocca. Le fatte hanno il bordo
## verde; le segrete non fatte non dicono niente. Esc (o B) chiude.
## In alto a destra la vetrina (vedi Showcase): passando su un'impresa, la
## rana del menu fa vedere la ricompensa (la rana nuova, il cappello, il
## colore, l'attrezzo della carta).

signal closed
## Il puntatore (o la selezione col controller) è su un'impresa: il menu fa
## vedere la ricompensa nella vetrina.
signal previewed(id: String)

const COLUMNS := 3

## La vetrina in alto a destra: la rana del menu.
var showcase: Showcase

var _count: Label
var _list: VBoxContainer
var _esc_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	theme_type_variation = "Backdrop"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var header := HBoxContainer.new()
	# In alto: a sinistra titolo e spiegazione, a destra la vetrina.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	box.add_child(top)
	var intro := VBoxContainer.new()
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_theme_constant_override("separation", 12)
	top.add_child(intro)
	showcase = Showcase.new()
	top.add_child(showcase)
	intro.add_child(header)
	var title := _label("Imprese", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_count = _label("", "Money")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_count)
	intro.add_child(_note("Ogni impresa sblocca una cosa: una carta che entra nelle tane, una rana, un gettone o qualcosa da vedere. Si fanno giocando, anche morendo."))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 14)
	scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	margin.add_child(_list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_esc_label = _label("", "Note")
	_esc_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_esc_label)
	var close := _button("Chiudi", _close)
	footer.add_child(close)
	Settings.changed.connect(_update_esc)
	_update_esc()
	visibility_changed.connect(func() -> void:
		if visible:
			close.grab_focus())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


## Cambiata la lingua, la lista si rifà.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _list != null:
		refresh()


func refresh() -> void:
	_count.text = "%d / %d" % [Feats.count_done(), Feats.ALL.size()]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for group: String in Feats.GROUPS:
		_list.add_child(_label(group, "Header"))
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		_list.add_child(grid)
		for id: String in Feats.ALL:
			if Feats.ALL[id].group == group:
				grid.add_child(_tile(id))


## Un'impresa: nome, cosa chiede, cosa sblocca. Fatta: bordo verde.
func _tile(id: String) -> PanelContainer:
	var feat: Dictionary = Feats.ALL[id]
	var done := Feats.done(id)
	var hidden: bool = feat.get("secret", false) and not done
	var tile := PanelContainer.new()
	tile.name = id
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiTheme.box(UiTheme.INK_LIGHT, UiTheme.DONE if done else UiTheme.LINE, 0, 10)
	box.border_width_left = 5
	box.set_content_margin_all(14)
	tile.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	tile.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var name_label := _label("???" if hidden else tr(feat.name), "Strong")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if done:
		name_label.add_theme_color_override("font_color", UiTheme.DONE)
	head.add_child(name_label)
	if done:
		head.add_child(_label(tr("Fatta"), "Note"))
	var text := _label(tr("Impresa segreta: si scopre facendola") if hidden else tr(feat.text))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 16)
	column.add_child(text)
	var reward := _label(tr("Sblocca: %s") % ("?" if hidden else tr(feat.reward_name)), "Note")
	reward.add_theme_color_override("font_color", UiTheme.GOLD)
	column.add_child(reward)
	if not hidden and not Feats.reward_ready(id):
		column.add_child(_label(tr("Arriva più avanti nello sviluppo"), "Note"))
	# Una tessera senza pulsanti: si seleziona anche col controller, e
	# selezionata (o sotto il puntatore) mostra la ricompensa.
	tile.focus_mode = Control.FOCUS_ALL
	tile.mouse_entered.connect(previewed.emit.bind(id))
	tile.focus_entered.connect(previewed.emit.bind(id))
	tile.focus_entered.connect(_highlight.bind(tile, true))
	tile.focus_exited.connect(_highlight.bind(tile, false))
	return tile


## La tessera selezionata col controller: bordo dorato tutto intorno.
func _highlight(tile: PanelContainer, on: bool) -> void:
	var box := tile.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var width := 3 if on else 0
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width
	if on:
		box.border_color = UiTheme.GOLD
	else:
		box.border_color = UiTheme.DONE if Feats.done(tile.name) else UiTheme.LINE
	tile.add_theme_stylebox_override("panel", box)


func _update_esc() -> void:
	_esc_label.text = Settings.ui_name("ui_cancel")


func _close() -> void:
	visible = false
	closed.emit()


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
