class_name Pond
extends PanelContainer
## Lo stagno: dove si spendono le mosche, fra una run e l'altra. Due schede:
## le statistiche, comprate con le mosche (a livelli, il prezzo sale a ogni
## livello), e la maestria delle carte: ogni carta ha due miglioramenti
## speciali, ognuno con la sua prova; superata la prova si attiva con le
## mosche d'oro. Si può chiedere il rimborso di tutto. Lo usano il menu
## iniziale e la fine della run.
## Le statistiche sono tessere raggruppate per attrezzo, col suo colore e la
## sua icona; ogni carta della maestria è una scheda col colore del suo slot e
## la barra di avanzamento delle prove. Esc chiude.

signal closed

## L'attrezzo di ogni statistica: colore e icona della tessera ("" per quelle
## che non riguardano un attrezzo). Le tessere seguono quest'ordine.
const STAT_GROUPS := {
	"health": "body", "armor": "body", "regen": "body", "invuln": "body", "swim": "body",
	"speed": "springs", "jump": "springs", "super_jump": "springs",
	"punch": "gloves", "glide": "wing",
	"magnet": "tongue", "greed": "tongue", "luck": "tongue",
	"cooldown": "", "calm": "", "fire": "", "choice": "", "revival": "",
}
const COLUMNS := 3

var _flies_label: Label
var _golden_label: Label
var _stats_box: GridContainer
var _cards_box: GridContainer
var _refund_button: Button
## Il rimborso chiede conferma: il primo clic lo prepara, il secondo (entro
## qualche secondo) lo fa.
var _refund_armed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	theme_type_variation = "Backdrop"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	var title := _label("Lo stagno", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(SlotIcon.make("fly", 36.0))
	_flies_label = _label("", "Money")
	header.add_child(_flies_label)
	var gap := Control.new()
	gap.custom_minimum_size.x = 18
	header.add_child(gap)
	header.add_child(SlotIcon.make("golden", 36.0))
	_golden_label = _label("", "Money")
	header.add_child(_golden_label)
	box.add_child(_label("Le mosche comprano statistiche; le mosche d'oro attivano i miglioramenti delle carte, una volta superata la loro prova.", "Note"))

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_stats_box = _page(tabs, "Statistiche")
	_cards_box = _page(tabs, "Maestria delle carte")

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	_refund_button = _button("", _refund, "DangerButton")
	footer.add_child(_refund_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var esc := _label("Esc", "Note")
	esc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(esc)
	footer.add_child(_button("Chiudi", _close))
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func refresh() -> void:
	_flies_label.text = str(Progress.flies)
	_golden_label.text = str(Progress.golden)
	# Le tessere vecchie escono subito, ma si cancellano a fine fotogramma: il
	# pulsante appena premuto sta ancora mandando il suo segnale.
	for grid in [_stats_box, _cards_box]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	for stat: String in STAT_GROUPS:
		_stats_box.add_child(_stat_tile(stat))
	for card: String in Progress.CARD_UPGRADES:
		_cards_box.add_child(_card_tile(card))
	_refund_armed = false
	_update_refund_button()


## Una statistica: icona e nome nel colore dell'attrezzo, effetto, livelli a
## pallini, e il pulsante col prezzo.
func _stat_tile(stat: String) -> PanelContainer:
	var info: Dictionary = Progress.STATS[stat]
	var group: String = STAT_GROUPS[stat]
	var color: Color = UiTheme.SLOT_COLORS[group]
	var tile := _tile(color, false)
	tile.name = stat
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	tile.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	top.add_child(SlotIcon.make(group, 30.0))
	var name_label := _label(info.name, "Strong")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(UiPips.make(Progress.level(stat), info.max, color))
	var effect := _label(info.text)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect.add_theme_font_size_override("font_size", 16)
	effect.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	box.add_child(effect)
	var cost := Progress.stat_cost(stat)
	var buy := _button("Al massimo" if cost < 0 else "%d mosche" % cost, _buy_stat.bind(stat))
	buy.disabled = cost < 0 or cost > Progress.flies
	buy.add_theme_font_size_override("font_size", 20)
	box.add_child(buy)
	return tile


## Una carta della maestria: i suoi due miglioramenti, ognuno con la prova,
## la barra di avanzamento e lo stato (da superare, da attivare, attivo).
func _card_tile(card: String) -> PanelContainer:
	var slot: String = Upgrades.CATALOG[card].slot
	var color: Color = UiTheme.SLOT_COLORS[slot]
	var tile := _tile(color, true)
	tile.name = card
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	tile.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	top.add_child(SlotIcon.make(slot, 34.0))
	var title := _label(Upgrades.CATALOG[card].name, "Header")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", color)
	top.add_child(title)
	for index in Progress.CARD_UPGRADES[card].size():
		box.add_child(HSeparator.new())
		box.add_child(_upgrade(card, index, color))
	return tile


func _upgrade(card: String, index: int, color: Color) -> VBoxContainer:
	var info: Dictionary = Progress.CARD_UPGRADES[card][index]
	var done := Progress.trial_done(card, index)
	var active := Progress.upgrade_active(card, index)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := _label(info.name, "Strong")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	if active:
		var on := _label("Attivo", "Strong")
		on.add_theme_color_override("font_color", UiTheme.DONE)
		head.add_child(on)
	elif done:
		var activate := _button("Attiva: %d d'oro" % info.cost, _activate.bind(card, index), "PrimaryButton")
		activate.add_theme_font_size_override("font_size", 18)
		activate.disabled = info.cost > Progress.golden
		head.add_child(activate)
	var effect := _label(info.text)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", 16)
	box.add_child(effect)
	var value: float = minf(Progress.trial_value(card, index), info.goal)
	var trial := _label("Prova: %s" % info.trial, "Note")
	trial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(trial)
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 10)
	box.add_child(progress)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = info.goal
	bar.value = value
	var fill := UiTheme.box(UiTheme.DONE if done else color, color, 0, 4)
	bar.add_theme_stylebox_override("fill", fill)
	progress.add_child(bar)
	var count := _label("%d/%d" % [floori(value), info.goal], "Note")
	if done:
		count.add_theme_color_override("font_color", UiTheme.DONE)
	progress.add_child(count)
	return box


## Il fondo di una tessera: colore dell'attrezzo a sinistra (statistiche) o
## in alto (carte).
func _tile(color: Color, top: bool) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiTheme.box(UiTheme.INK_LIGHT, color, 0, 10)
	if top:
		box.border_width_top = 5
	else:
		box.border_width_left = 5
	box.set_content_margin_all(14)
	tile.add_theme_stylebox_override("panel", box)
	return tile


func _update_refund_button() -> void:
	var spent := Progress.spent()
	var spent_golden := Progress.spent_golden()
	_refund_button.text = "Rimborsa tutto (+%d, +%d d'oro)" % [spent, spent_golden]
	if _refund_armed:
		_refund_button.text = "Sicura? Premi di nuovo: si azzera tutto"
	_refund_button.disabled = spent == 0 and spent_golden == 0


func _buy_stat(stat: String) -> void:
	Progress.buy_stat(stat)
	refresh()


func _activate(card: String, index: int) -> void:
	Progress.activate(card, index)
	refresh()


func _refund() -> void:
	if not _refund_armed:
		_refund_armed = true
		_update_refund_button()
		# Senza conferma, dopo 3 s torna com'era (il timer va anche in pausa).
		get_tree().create_timer(3.0, true).timeout.connect(_disarm_refund)
		return
	Progress.refund()
	refresh()


func _disarm_refund() -> void:
	if _refund_armed:
		_refund_armed = false
		_update_refund_button()


func _close() -> void:
	_disarm_refund()
	visible = false
	closed.emit()


func _page(tabs: TabContainer, title: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Spazio per la barra di scorrimento.
	margin.add_theme_constant_override("margin_right", 14)
	scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(grid)
	return grid


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
