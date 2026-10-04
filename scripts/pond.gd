class_name Pond
extends PanelContainer
## Lo stagno: dove si spendono le mosche, fra una run e l'altra. Due schede:
## le statistiche (a livelli, il prezzo sale a ogni livello) e le carte
## migliorate (due miglioramenti per ogni carta con slot). Si può chiedere
## il rimborso di tutto. Lo usano il menu iniziale e la fine della run.

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
	box.add_child(_label("Le mosche raccolte comprano forza per le prossime run.", 16))

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_stats_box = _page(tabs, "Statistiche")
	_cards_box = _page(tabs, "Carte")

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
	_flies_label.text = "Mosche: %d" % Progress.flies
	for child in _stats_box.get_children():
		child.free()
	for child in _cards_box.get_children():
		child.free()
	for stat: String in Progress.STATS:
		var info: Dictionary = Progress.STATS[stat]
		var level := Progress.level(stat)
		var cost := Progress.stat_cost(stat)
		_stats_box.add_child(_row(info.name, info.text, "%d/%d" % [level, info.max], cost, _buy_stat.bind(stat)))
	for card: String in Progress.CARD_UPGRADES:
		var upgrades: Array = Progress.CARD_UPGRADES[card]
		var level := Progress.card_level(card)
		var next: String = upgrades[level].text if level < upgrades.size() else "Migliorata del tutto"
		_cards_box.add_child(_row(Upgrades.CATALOG[card].name, next, "%d/%d" % [level, upgrades.size()], Progress.card_cost(card), _buy_card.bind(card)))
	var spent := Progress.spent()
	_refund_button.text = "Rimborsa tutto (+%d)" % spent
	_refund_button.disabled = spent == 0


func _buy_stat(stat: String) -> void:
	Progress.buy_stat(stat)
	refresh()


func _buy_card(card: String) -> void:
	Progress.buy_card(card)
	refresh()


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
