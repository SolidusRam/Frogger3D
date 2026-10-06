extends Node
## Il menu iniziale, sopra il gioco vivo: dietro c'è la partita vera (in
## modalità attract), col traffico che passa e la telecamera che gira attorno
## alla rana sulla striscia di partenza. A sinistra Gioca, la rana scelta,
## Lo stagno, Imprese, Opzioni, Esci;
## in basso mosche e record. Gioca fa partire la run sul posto: la telecamera
## torna dietro la rana e il menu sparisce.
## Avviato con le opzioni della modalità prova (tools/prova.sh), salta il
## menu e parte subito.

const GAME := "res://scenes/main.tscn"

@export var progress_path := "user://progressi.cfg"
@export var record_path := "user://record.cfg"

var _game: Node
var _ui: Control
var _flies_label: Label
var _golden_label: Label
var _play_button: Button
var _record_label: Label
var _pond: Pond
var _options: OptionsPanel
var _feats: FeatsPanel
var _frogs: FrogsPanel
var _frog_button: Button
var _unlocked_label: Label
## Il nome della rana in anteprima, a destra sopra lo sfondo.
var _preview_label: Label


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		get_tree().change_scene_to_file.call_deferred(GAME)
		return
	get_tree().paused = false
	# Senza schermo (i test) mai i file veri del giocatore: i test che aprono
	# il menu non possono impostarne i percorsi prima che parta.
	if DisplayServer.get_name() == "headless":
		progress_path = "user://progressi_test.cfg"
		record_path = "user://record_test.cfg"
	Progress.load_from(progress_path)
	_game = load(GAME).instantiate()
	_game.attract = true
	_game.progress_path = progress_path
	_game.record_path = record_path
	add_child(_game)
	_build()
	_refresh()


func _build() -> void:
	# Sopra l'HUD e sopra il post-processing: le scritte del menu non si
	# sgranano con lo stile PS1.
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = UiTheme.get_theme()
	layer.add_child(_ui)

	# Un'ombra da sinistra: il menu si legge sopra qualsiasi cosa passi.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UiTheme.INK, 0.9))
	gradient.set_color(1, Color(UiTheme.INK, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.62
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left = 72
	column.offset_right = 72 + 420
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	_ui.add_child(column)
	column.add_child(_label("Frogger 3D", "Logo"))
	var subtitle := _label("La rana scappa dall'incendio", "Strong")
	subtitle.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	column.add_child(gap)
	var play := _button("Gioca", _play, "PrimaryButton")
	_play_button = play
	play.custom_minimum_size = Vector2(340, 64)
	play.add_theme_font_size_override("font_size", 32)
	column.add_child(play)
	_frog_button = _button("", _open_frogs)
	column.add_child(_frog_button)
	column.add_child(_button("Lo stagno", _open_pond))
	column.add_child(_button("Imprese", _open_feats))
	column.add_child(_button("Opzioni", _open_options))
	column.add_child(_button("Esci", get_tree().quit, "FlatButton"))
	play.grab_focus()

	# In basso a sinistra: quello che ti porti dietro fra una run e l'altra.
	var stats := HBoxContainer.new()
	stats.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	stats.offset_left = 72
	stats.offset_top = -72
	stats.offset_bottom = -40
	stats.grow_horizontal = Control.GROW_DIRECTION_END
	stats.add_theme_constant_override("separation", 28)
	_ui.add_child(stats)
	_flies_label = _label("", "Money")
	stats.add_child(_flies_label)
	_golden_label = _label("", "Money")
	stats.add_child(_golden_label)
	_record_label = _label("", "Strong")
	stats.add_child(_record_label)

	# "Tutto sbloccato" acceso: lo si dice, le run sono prove.
	_unlocked_label = _label("Tutto sbloccato: le run sono prove", "Money")
	_unlocked_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_unlocked_label.offset_left = -520
	_unlocked_label.offset_right = -32
	_unlocked_label.offset_top = 28
	_unlocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(_unlocked_label)
	Settings.changed.connect(_on_settings_changed)

	var hint := _label("F2: cambia stile grafico", "Note")
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -320
	hint.offset_right = -32
	hint.offset_top = -56
	hint.offset_bottom = -32
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(hint)

	_pond = Pond.new()
	_pond.visible = false
	_pond.closed.connect(_on_pond_closed)
	_ui.add_child(_pond)

	_preview_label = _label("", "Title")
	_preview_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_preview_label.offset_left = -500
	_preview_label.offset_right = -40
	_preview_label.offset_top = -120
	_preview_label.offset_bottom = -60
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_preview_label.add_theme_constant_override("outline_size", 10)
	_preview_label.visible = false
	_ui.add_child(_preview_label)

	_frogs = FrogsPanel.new()
	_frogs.visible = false
	_frogs.closed.connect(_frog_button.grab_focus)
	_frogs.chosen.connect(_on_frog_chosen)
	_frogs.previewed.connect(_on_frog_previewed)
	_frogs.closed.connect(_end_frog_preview)
	_ui.add_child(_frogs)

	_feats = FeatsPanel.new()
	_feats.visible = false
	_feats.closed.connect(_play_button.grab_focus)
	_ui.add_child(_feats)

	_options = OptionsPanel.new()
	_options.visible = false
	_options.closed.connect(_play_button.grab_focus)
	_ui.add_child(_options)


## Cambiata la lingua nelle opzioni, si riscrivono le scritte coi numeri (le
## altre si traducono da sole).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(_flies_label):
		_refresh()


func _refresh() -> void:
	_flies_label.text = tr("Mosche: %d") % Progress.flies
	_golden_label.text = tr("Mosche d'oro: %d") % Progress.golden
	_frog_button.text = tr("Rana: %s") % tr(Frogs.ALL[Frogs.selected()].name)
	var level := Drought.selected(Frogs.selected())
	if level > 0:
		_frog_button.text += "   " + tr("Siccità %d") % level
	_unlocked_label.visible = Settings.unlock_everything
	var record: float = _game.record_distance
	_record_label.text = tr("Record: %d m") % roundi(record) if record > 0.0 else tr("Nessun record")
	_golden_label.visible = Progress.golden > 0


## Il menu sparisce e la run parte sul posto.
func _play() -> void:
	# Da qui in poi le opzioni (anche dalla pausa) non riguardano più il menu:
	# le sue scritte se ne vanno, e la rana non va più cambiata a run partita.
	Settings.changed.disconnect(_on_settings_changed)
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_ui, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_ui.get_parent().queue_free)
	_game.start_run()


func _open_pond() -> void:
	_pond.refresh()
	_pond.visible = true


## Acceso o spento "Tutto sbloccato": la scritta, e la rana scelta che magari
## non si può più usare (torna la comune).
func _on_settings_changed() -> void:
	_refresh()
	if _game.frog_kind != Frogs.selected():
		_game.preview_frog(Frogs.selected())


func _open_frogs() -> void:
	_frogs.open()
	_game.frog.camera_rig.frame_preview(true)


## Anteprima: la rana sotto il puntatore compare sullo sfondo; se è chiusa,
## come silhouette, col suo nome e un punto di domanda.
func _on_frog_previewed(id: String) -> void:
	var open_frog := Frogs.unlocked(id)
	_game.preview_frog(id, not open_frog)
	_preview_label.text = tr(Frogs.ALL[id].name) + ("" if open_frog else "  ?")
	_preview_label.visible = true


## Chiusa la scelta, sullo sfondo torna la rana scelta.
func _end_frog_preview() -> void:
	_preview_label.visible = false
	_game.frog.camera_rig.frame_preview(false)
	_game.preview_frog(Frogs.selected())


## La rana scelta compare subito sullo sfondo, coi suoi colori e attrezzi.
func _on_frog_chosen(id: String) -> void:
	_game.preview_frog(id)
	_refresh()


func _open_feats() -> void:
	_feats.refresh()
	_feats.visible = true


func _open_options() -> void:
	_options.open()


func _on_pond_closed() -> void:
	_refresh()
	_play_button.grab_focus()


## Le scritte del menu stanno sopra il mondo: bordo scuro, come nell'HUD.
func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	if variation != "Logo":
		label.add_theme_constant_override("outline_size", 6)
	return label


func _button(text: String, action: Callable, variation := "") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	return button
