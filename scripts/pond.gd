class_name Pond
extends PanelContainer
## Lo stagno: dove si spendono le mosche, fra una run e l'altra. Due schede:
## le statistiche, comprate con le mosche (a livelli, il prezzo sale a ogni
## livello), e la maestria delle carte: ogni carta ha due miglioramenti
## speciali, ognuno con la sua prova; superata la prova si attiva con le
## mosche d'oro. Si può chiedere il rimborso di tutto. Lo usano il menu
## iniziale e la fine della run.

signal closed

var _flies_label: Label
var _stats_box: VBoxContainer
var _cards_box: VBoxContainer
var _refund_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.06)
	style.set_content_margin_all(28)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _label("Lo stagno", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_flies_label = _label("", 26)
	_flies_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_child(_flies_label)
	box.add_child(_label("Le mosche comprano statistiche; le mosche d'oro attivano i miglioramenti delle carte, una volta superata la loro prova.", 16))

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_stats_box = _page(tabs, "Statistiche")
	_cards_box = _page(tabs, "Maestria delle carte")

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	_refund_button = _button("", _refund)
	footer.add_child(_refund_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	footer.add_child(_button("Chiudi", _close))
	refresh()


func refresh() -> void:
	_flies_label.text = "Mosche: %d   d'oro: %d" % [Progress.flies, Progress.golden]
	# Le righe vecchie escono subito, ma si cancellano a fine fotogramma: il
	# pulsante appena premuto sta ancora mandando il suo segnale.
	for box in [_stats_box, _cards_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for stat: String in Progress.STATS:
		var info: Dictionary = Progress.STATS[stat]
		var level := Progress.level(stat)
		var cost := Progress.stat_cost(stat)
		_stats_box.add_child(_row(info.name, info.text, "%d/%d" % [level, info.max], cost, _buy_stat.bind(stat)))
	for card: String in Progress.CARD_UPGRADES:
		var title := _label(Upgrades.CATALOG[card].name, 22)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_cards_box.add_child(title)
		for index in Progress.CARD_UPGRADES[card].size():
			_cards_box.add_child(_upgrade_row(card, index))
	var spent := Progress.spent()
	var spent_golden := Progress.spent_golden()
	_refund_button.text = "Rimborsa tutto (+%d, +%d d'oro)" % [spent, spent_golden]
	_refund_button.disabled = spent == 0 and spent_golden == 0


func _buy_stat(stat: String) -> void:
	Progress.buy_stat(stat)
	refresh()


func _activate(card: String, index: int) -> void:
	Progress.activate(card, index)
	refresh()


## Un miglioramento: nome ed effetto, la prova col suo avanzamento, e il
## pulsante per attivarlo.
func _upgrade_row(card: String, index: int) -> HBoxContainer:
	var info: Dictionary = Progress.CARD_UPGRADES[card][index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var effect := _label("%s: %s" % [info.name, info.text], 17)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(effect)
	var value: float = minf(Progress.trial_value(card, index), info.goal)
	var trial := _label("Prova: %s (%d/%d)" % [info.trial, floori(value), info.goal], 15)
	trial.modulate = Color(0.6, 1.0, 0.6) if Progress.trial_done(card, index) else Color(1, 1, 1, 0.7)
	text.add_child(trial)
	row.add_child(text)
	var label := "Prova da superare"
	if Progress.upgrade_active(card, index):
		label = "Attivo"
	elif Progress.trial_done(card, index):
		label = "Attiva (%d d'oro)" % info.cost
	var button := _button(label, _activate.bind(card, index))
	button.custom_minimum_size.x = 190
	button.disabled = label != "Attiva (%d d'oro)" % info.cost or info.cost > Progress.golden
	row.add_child(button)
	return row


func _refund() -> void:
	Progress.refund()
	refresh()


func _close() -> void:
	visible = false
	closed.emit()


func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list


## Una riga: nome, effetto, livello, e il pulsante col prezzo (cost < 0: già
## al massimo).
func _row(name_text: String, effect: String, level: String, cost: int, buy: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _label(name_text, 20)
	name_label.custom_minimum_size.x = 210
	row.add_child(name_label)
	var effect_label := _label(effect, 16)
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(effect_label)
	var level_label := _label(level, 18)
	level_label.custom_minimum_size.x = 50
	row.add_child(level_label)
	var button := _button("Fatto" if cost < 0 else "%d mosche" % cost, buy)
	button.custom_minimum_size.x = 140
	button.disabled = cost < 0 or cost > Progress.flies
	row.add_child(button)
	return row


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	return button
