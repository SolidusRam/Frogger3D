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
## la barra di avanzamento delle prove. Esc (o B) chiude; col controller LB e
## RB cambiano scheda.

signal closed
## Il puntatore (o la selezione col controller) è su una tessera: la vetrina
## fa vedere l'attrezzo sulla rana. group: lo slot ("" per le statistiche
## generali); title e detail: cosa scrivere.
signal previewed(group: String, title: String, detail: String)

## L'attrezzo di ogni statistica: colore e icona della tessera ("" per quelle
## che non riguardano un attrezzo). Le tessere seguono quest'ordine.
const STAT_GROUPS := {
	"health": "body", "armor": "body", "regen": "body", "invuln": "body", "swim": "body",
	"speed": "springs", "jump": "springs", "super_jump": "springs",
	"punch": "gloves", "glide": "wing",
	"magnet": "tongue", "greed": "tongue", "luck": "tongue",
	"cooldown": "", "calm": "", "fire": "", "choice": "", "revival": "", "eye": "",
}
const COLUMNS := 3

## La vetrina in alto a destra (vedi Showcase): la rana mostra l'attrezzo
## della tessera sotto il puntatore. Senza una rana (la fine della corsa) non
## c'è.
var showcase: Showcase

var _flies_label: Label
var _golden_label: Label
var _stats_box: GridContainer
var _cards_box: GridContainer
var _refund_button: Button
var _market_box: GridContainer
## Il nome dei gradi di rarità degli oggetti.
const RARITY_NAMES := {"common": "Comune", "rare": "Raro", "epic": "Epico"}
var _tabs: TabContainer
var _esc_label: Label
## Il rimborso chiede conferma: il primo clic lo prepara, il secondo (entro
## qualche secondo) lo fa.
var _refund_armed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	theme_type_variation = "PondBackdrop"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	# In alto: a sinistra titolo, mosche e spiegazione, a destra la vetrina.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	box.add_child(top)
	var intro := VBoxContainer.new()
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_theme_constant_override("separation", 12)
	top.add_child(intro)
	showcase = Showcase.new()
	top.add_child(showcase)
	previewed.connect(_show_in_showcase)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	intro.add_child(header)
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
	var note := _label("Le mosche comprano statistiche; le mosche d'oro attivano i miglioramenti delle carte, una volta superata la loro prova.", "Note")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_child(note)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tabs)
	_stats_box = _page(_tabs, "Statistiche")
	_cards_box = _page(_tabs, "Maestria delle carte")
	_market_box = _page(_tabs, "Mercatino")

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	_refund_button = _button("", _refund, "DangerButton")
	footer.add_child(_refund_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_esc_label = _label("", "Note")
	_esc_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_esc_label)
	footer.add_child(_button("Chiudi", _close))
	Settings.changed.connect(_update_esc)
	_update_esc()
	# Aperto, la selezione parte dalle schede: col controller ci si muove.
	visibility_changed.connect(func() -> void:
		if visible:
			_tabs.get_tab_bar().grab_focus())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		get_viewport().set_input_as_handled()
		_tabs.current_tab = 1 - _tabs.current_tab
		_tabs.get_tab_bar().grab_focus()


## Dove sta il pulsante selezionato: [tessera, indice fra i suoi pulsanti].
func _focused_place() -> Array:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused == null:
		return []
	for grid in [_stats_box, _cards_box, _market_box]:
		for tile in grid.get_children():
			if tile.is_ancestor_of(focused):
				return [tile.name, tile.find_children("*", "Button", true, false).find(focused)]
	return []


## Seleziona il pulsante nello stesso posto (o il primo della tessera, se
## quello non c'è più: un miglioramento appena attivato perde il pulsante).
func _restore_focus(place: Array) -> void:
	if place.is_empty():
		return
	for grid in [_stats_box, _cards_box, _market_box]:
		var tile: Node = grid.get_node_or_null(NodePath(place[0]))
		if tile == null:
			continue
		var buttons: Array[Node] = tile.find_children("*", "Button", true, false)
		if not buttons.is_empty():
			(buttons[clampi(place[1], 0, buttons.size() - 1)] as Button).grab_focus()
		else:
			_tabs.get_tab_bar().grab_focus()
		return


## Cambiata la lingua, le tessere si rifanno (le scritte fisse si traducono
## da sole).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _stats_box != null:
		refresh()


## La vetrina: la rana si gira e mostra l'attrezzo, sotto nome e livello.
func _show_in_showcase(group: String, title: String, detail: String) -> void:
	if showcase.target == null:
		return
	showcase.face_target()
	showcase.target.demo(group, 0.0)
	showcase.caption(title, detail)


## Passando su una tessera (o su un suo pulsante col controller), la rana
## della vetrina mostra l'attrezzo.
func _preview_on(tile: Control, group: String, title: String, detail: String) -> void:
	tile.mouse_entered.connect(previewed.emit.bind(group, title, detail))
	for button in tile.find_children("*", "Button", true, false):
		button.focus_entered.connect(previewed.emit.bind(group, title, detail))
		button.mouse_entered.connect(previewed.emit.bind(group, title, detail))


func _update_esc() -> void:
	_esc_label.text = Settings.ui_name("ui_cancel")


func refresh() -> void:
	_flies_label.text = str(Progress.flies)
	_golden_label.text = str(Progress.golden)
	# Il pulsante selezionato (comprando col controller) sparisce con la sua
	# tessera: si ricorda quale era, per selezionare quello nuovo.
	var focus := _focused_place()
	# Le tessere vecchie escono subito, ma si cancellano a fine fotogramma: il
	# pulsante appena premuto sta ancora mandando il suo segnale.
	for grid in [_stats_box, _cards_box, _market_box]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	for stat: String in STAT_GROUPS:
		_stats_box.add_child(_stat_tile(stat))
	for card: String in Progress.CARD_UPGRADES:
		_cards_box.add_child(_card_tile(card))
	for item: Array in Market.stock():
		_market_box.add_child(_market_tile(item[0], item[1]))
	_market_box.add_child(_egg_tile())
	_restore_focus(focus)
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
	var name_label := _label(tr(info.name), "Strong")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(UiPips.make(Progress.level(stat), info.max, color))
	var effect := _label(tr(info.text))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect.add_theme_font_size_override("font_size", 16)
	effect.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	box.add_child(effect)
	var cost := Progress.stat_cost(stat)
	var buy := _button(tr("Al massimo") if cost < 0 else tr("%d mosche") % cost, _buy_stat.bind(stat))
	buy.disabled = cost < 0 or cost > Progress.flies
	buy.add_theme_font_size_override("font_size", 20)
	box.add_child(buy)
	_preview_on(tile, group, tr(info.name), tr("Livello %d di %d") % [Progress.level(stat), info.max])
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
	var title := _label(tr(Upgrades.CATALOG[card].name), "Header")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", color)
	top.add_child(title)
	for index in Progress.CARD_UPGRADES[card].size():
		box.add_child(HSeparator.new())
		box.add_child(_upgrade(card, index, color))
	var active := [0, 1].filter(func(index: int) -> bool: return Progress.upgrade_active(card, index)).size()
	_preview_on(tile, slot, tr(Upgrades.CATALOG[card].name), tr("Miglioramenti attivi: %d di 2") % active)
	return tile


func _upgrade(card: String, index: int, color: Color) -> VBoxContainer:
	var info: Dictionary = Progress.CARD_UPGRADES[card][index]
	var done := Progress.trial_done(card, index)
	var active := Progress.upgrade_active(card, index)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := _label(tr(info.name), "Strong")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	if active:
		var on := _label(tr("Attivo"), "Strong")
		on.add_theme_color_override("font_color", UiTheme.DONE)
		head.add_child(on)
	elif done:
		var activate := _button(tr("Attiva: %d d'oro") % info.cost, _activate.bind(card, index), "PrimaryButton")
		activate.add_theme_font_size_override("font_size", 18)
		activate.disabled = info.cost > Progress.golden
		head.add_child(activate)
	var effect := _label(Settings.with_keys(tr(info.text)))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", 16)
	box.add_child(effect)
	var value: float = minf(Progress.trial_value(card, index), info.goal)
	var trial := _label(tr("Prova: %s") % tr(info.trial), "Note")
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


## Un oggetto del mercatino: nome, rarità e prezzo. Passandoci sopra la rana
## della vetrina lo indossa.
func _market_tile(kind: String, id: String) -> PanelContainer:
	var rarity := Cosmetics.rarity_of(id)
	var color: Color = UiTheme.RARITY[rarity]
	var tile := _tile(color, true)
	tile.name = id
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	tile.add_child(box)
	var name_label := _label(Cosmetics.name_of(kind, id), "Header")
	name_label.add_theme_font_size_override("font_size", 24)
	box.add_child(name_label)
	var what := _label(tr("Cappello") if kind == "hat" else tr("Colore"), "Note")
	box.add_child(what)
	var tag := _label(tr(RARITY_NAMES[rarity]), "Strong")
	tag.add_theme_color_override("font_color", color)
	box.add_child(tag)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	var cost := Market.price(id)
	var buy := _button(tr("Compra: %d mosche") % cost, _buy_item.bind(kind, id), "PrimaryButton")
	buy.disabled = cost > Progress.flies
	box.add_child(buy)
	var preview := func() -> void: _wear_preview(kind, id, Cosmetics.name_of(kind, id), tr(RARITY_NAMES[rarity]))
	tile.mouse_entered.connect(preview)
	buy.mouse_entered.connect(preview)
	buy.focus_entered.connect(preview)
	return tile


## L'uovo di rana: a prezzo fisso, un oggetto a caso fra quelli che mancano.
func _egg_tile() -> PanelContainer:
	var tile := _tile(UiTheme.GOLD, true)
	tile.name = "egg"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	tile.add_child(box)
	var name_label := _label(tr("Uovo di rana"), "Header")
	name_label.add_theme_font_size_override("font_size", 24)
	box.add_child(name_label)
	var text := _label(tr("Si schiude in un cappello o un colore a caso, fra quelli che non hai. I rari e gli epici escono meno spesso."))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 16)
	box.add_child(text)
	var left := Cosmetics.missing_items().size()
	box.add_child(_label(tr("Ancora da trovare: %d") % left, "Note"))
	var hatch := _button(tr("Schiudi: %d mosche") % Market.EGG_PRICE, _hatch, "PrimaryButton")
	hatch.disabled = not Market.egg_ready()
	box.add_child(hatch)
	return tile


## La rana della vetrina indossa l'oggetto, per vederlo.
func _wear_preview(kind: String, id: String, title: String, detail: String) -> void:
	if showcase.target == null:
		return
	showcase.face_target()
	if kind == "hat":
		showcase.target.set_hat(id)
	else:
		showcase.target.skin = Cosmetics.palette_of(id)
	showcase.caption(title, detail)


func _buy_item(kind: String, id: String) -> void:
	if not Market.buy(id):
		return
	Sfx.play(&"ui_buy")
	# Comprato: lo indossa la rana scelta.
	Cosmetics.choose(Frogs.selected(), kind, id)
	refresh()
	_wear_preview(kind, id, Cosmetics.name_of(kind, id), tr("Tuo! Lo indossa la rana scelta."))


func _hatch() -> void:
	var item := Market.hatch()
	if item.is_empty():
		return
	Sfx.play(&"ui_record")
	Cosmetics.choose(Frogs.selected(), item[0], item[1])
	refresh()
	var rarity := Cosmetics.rarity_of(item[1])
	_wear_preview(item[0], item[1], tr("Dall'uovo: %s!") % Cosmetics.name_of(item[0], item[1]), tr(RARITY_NAMES[rarity]))


## Il fondo di una tessera: colore dell'attrezzo a sinistra (statistiche) o
## in alto (carte).
func _tile(color: Color, top: bool) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiTheme.box(UiTheme.POND_TILE, color, 0, 10)
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
	_refund_button.text = tr("Rimborsa tutto (+%d, +%d d'oro)") % [spent, spent_golden]
	if _refund_armed:
		_refund_button.text = tr("Sicura? Premi di nuovo: si azzera tutto")
	_refund_button.disabled = spent == 0 and spent_golden == 0


func _buy_stat(stat: String) -> void:
	Progress.buy_stat(stat)
	Sfx.play(&"ui_buy")
	refresh()


func _activate(card: String, index: int) -> void:
	Progress.activate(card, index)
	Sfx.play(&"ui_buy", 0.0, 1.2)
	refresh()


func _refund() -> void:
	if not _refund_armed:
		_refund_armed = true
		_update_refund_button()
		# Senza conferma, dopo 3 s torna com'era (il timer va anche in pausa).
		get_tree().create_timer(3.0, true).timeout.connect(_disarm_refund)
		return
	Progress.refund()
	Sfx.play(&"ui_refund")
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
	# Spostandosi coi tasti o col controller, la tessera scelta resta in vista.
	scroll.follow_focus = true
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
