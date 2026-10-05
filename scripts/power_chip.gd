class_name PowerChip
extends PanelContainer
## Un potere nell'HUD: l'icona e il colore del suo attrezzo, il nome, il tasto,
## il modificatore equipaggiato in quello slot e la barra di ricarica. Quando
## torna pronto lampeggia.

var _bar: ProgressBar
var _modifier: Label
var _fill_ready: StyleBoxFlat
var _fill_charging: StyleBoxFlat
var _is_ready := true
var _slot := ""
var _action := ""
var _key_label: Label
## Il "ding" di ogni potere ha il suo tono.
const READY_PITCH := {"gloves": 1.0, "springs": 1.12, "wing": 1.26, "tongue": 1.4, "body": 0.9}


## action: l'azione del potere, per mostrarne il tasto come è assegnato.
static func make(title: String, action: String, slot: String) -> PowerChip:
	var chip := PowerChip.new()
	chip._build(title, action, slot)
	return chip


func _build(title: String, action: String, slot: String) -> void:
	_slot = slot
	var color: Color = UiTheme.SLOT_COLORS[slot]
	custom_minimum_size.x = 240
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiTheme.box(Color(UiTheme.INK, 0.72), color, 0, 8)
	box.border_width_left = 4
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	row.add_child(SlotIcon.make(slot, 30.0))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	var title_label := Label.new()
	title_label.text = title
	title_label.theme_type_variation = "Strong"
	title_label.add_theme_font_size_override("font_size", 16)
	names.add_child(title_label)
	_modifier = Label.new()
	_modifier.theme_type_variation = "Note"
	_modifier.add_theme_font_size_override("font_size", 13)
	_modifier.add_theme_color_override("font_color", color)
	_modifier.visible = false
	names.add_child(_modifier)
	_action = action
	_key_label = Label.new()
	_key_label.theme_type_variation = "Note"
	_key_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_key_label)
	_update_key()
	# Riassegnato nelle opzioni (anche dalla pausa), il tasto si aggiorna.
	Settings.changed.connect(_update_key)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.value = 1.0
	_bar.custom_minimum_size.y = 6
	_fill_ready = UiTheme.box(color, color, 0, 2)
	_fill_charging = _fill_ready.duplicate()
	_fill_charging.bg_color = color.darkened(0.45)
	_bar.add_theme_stylebox_override("fill", _fill_ready)
	column.add_child(_bar)


## Da 0 (appena usato) a 1 (pronto).
func set_ratio(ratio: float) -> void:
	_bar.value = ratio
	var now_ready := ratio >= 0.999
	if now_ready == _is_ready:
		return
	_is_ready = now_ready
	_bar.add_theme_stylebox_override("fill", _fill_ready if now_ready else _fill_charging)
	if now_ready:
		# Di nuovo pronto: un lampo e un "ding".
		modulate = Color(1.8, 1.8, 1.8)
		Sfx.play(&"power_ready", 0.0, READY_PITCH.get(_slot, 1.0))
		create_tween().set_ignore_time_scale(true).tween_property(self, "modulate", Color.WHITE, 0.3)


## Il modificatore dello slot ("" se non c'è).
func set_modifier(text: String) -> void:
	_modifier.text = text
	_modifier.visible = text != ""


func _update_key() -> void:
	_key_label.text = Settings.key_name(_action)
