class_name Hud
extends CanvasLayer
## L'HUD: vita e calore in alto a sinistra, distanza e tane in alto a destra,
## poteri in basso a sinistra, messaggi al centro e schermata di fine run.
## Costruito da codice per restare in un solo file finché i modelli e la
## grafica definitiva non arrivano.

signal restart_requested
signal menu_requested

const HEALTH_COLOR := Color(0.35, 0.8, 0.35)
const HEALTH_LOW_COLOR := Color(0.9, 0.25, 0.2)
const HEAT_COLORS: Array[Color] = [
	Color(0.95, 0.85, 0.3), Color(0.98, 0.7, 0.2), Color(0.98, 0.5, 0.15),
	Color(0.95, 0.3, 0.1), Color(0.85, 0.1, 0.1), Color(0.6, 0.0, 0.15),
]
const POWER_COLOR := Color(0.4, 0.7, 1.0)

@export var frog: Frog
@export var course: Course

var _health_bar: ProgressBar
var _health_label: Label
var _heat_bar: ProgressBar
var _heat_label: Label
var _distance_label: Label
var _dens_label: Label
var _record_label: Label
var _flies_label: Label
var _super_jump_bar: ProgressBar
var _glide_bar: ProgressBar
## Lingua e schianto: si vedono solo quando sono equipaggiati.
var _tongue_row: VBoxContainer
var _tongue_bar: ProgressBar
var _slam_row: VBoxContainer
var _slam_bar: ProgressBar
var _message: Label
var _fire_label: Label
var _vignette: ColorRect
var _game_over: PanelContainer
var _game_over_text: Label
var _pond: Pond
var _chain_label: Label
var _offer: PanelContainer
var _offer_title: Label
var _offer_buttons: Array[Button] = []
var _upgrades: Upgrades
var _equipment_label: Label
var _last_heat_level := 0


func _ready() -> void:
	# La scelta dei power-up avviene a gioco fermo: l'HUD deve restare attivo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_top_left()
	_build_top_right()
	_build_powers()
	_build_message()
	_build_fire()
	_build_chain_label()
	_build_offer()
	_build_equipment()
	_build_game_over()
	frog.health_changed.connect(_on_health_changed)
	_on_health_changed(frog.health, frog.max_health)
	Heat.changed.connect(_on_heat_changed)
	_on_heat_changed(Heat.value, Heat.level())
	course.den_reached.connect(_on_den_reached)
	Style.style_changed.connect(_on_style_changed)
	_last_heat_level = Heat.level()


func _process(_delta: float) -> void:
	_distance_label.text = "%d m" % roundi(course.distance())
	_dens_label.text = "Tane: %d" % course.dens_reached
	_super_jump_bar.value = frog.super_jump_power.ready_ratio()
	_glide_bar.value = frog.glide_charge_ratio()
	_tongue_row.visible = frog.tongue_power.enabled
	_tongue_bar.value = frog.tongue_power.ready_ratio()
	_slam_row.visible = frog.slam_power.enabled
	_slam_bar.value = frog.slam_power.ready_ratio()


## L'incendio dietro la rana: la distanza, e il bordo dello schermo che si
## arrossa (danger da 0 a 1) quando è vicino.
func set_fire_distance(distance: float, danger: float) -> void:
	_fire_label.text = "Fuoco: %d m" % maxi(roundi(distance), 0)
	_fire_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6).lerp(Color(1.0, 0.25, 0.1), danger))
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", danger)


func set_flies(count: int, golden := 0) -> void:
	_flies_label.text = "Mosche: %d" % count + ("   d'oro: %d" % golden if golden > 0 else "")


func set_record(distance: float) -> void:
	if _record_label:
		_record_label.text = "Record: %d m" % roundi(distance)


func show_game_over(stats: Dictionary) -> void:
	var lines := [
		"Distanza: %d m" % roundi(stats.distance),
		"Tane raggiunte: %d" % stats.dens,
		"Tempo: %d:%02d" % [floori(stats.time / 60.0), floori(stats.time) % 60],
		"Calore massimo: livello %d" % stats.heat_level,
		"Nuovo record!" if stats.new_record else "Record: %d m" % roundi(stats.record),
		"Mosche: +%d (in tutto %d)" % [stats.flies, stats.total_flies],
		"Mosche d'oro: +%d (in tutto %d)" % [stats.golden, stats.total_golden],
	]
	_game_over_text.text = "\n".join(lines)
	_game_over.visible = true


func _on_health_changed(health: int, max_health: int) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_label.text = "Vita %d / %d" % [health, max_health]
	var low := float(health) / max_health < 0.3
	_set_fill(_health_bar, HEALTH_LOW_COLOR if low else HEALTH_COLOR)


func _on_heat_changed(value: float, level: int) -> void:
	_heat_bar.value = value
	if level > _last_heat_level:
		_show_message("Calore: livello %d" % level)
	_last_heat_level = level
	_heat_label.text = "Calore: livello %d / %d" % [level, Heat.LEVELS]
	_set_fill(_heat_bar, HEAT_COLORS[level])


func _on_den_reached(count: int, distance: float) -> void:
	_show_message("Tana %d raggiunta! %d m" % [count, roundi(distance)])


func _on_style_changed(style_name: String) -> void:
	_show_message("Stile: %s   (F2 per cambiare)" % style_name)


## "CATENA ×N" sotto il centro, che pulsa a ogni rottame in più.
func show_chain(count: int) -> void:
	_chain_label.text = "CATENA ×%d" % count
	_chain_label.modulate.a = 1.0
	_chain_label.scale = Vector2(1.4, 1.4)
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_chain_label, "scale", Vector2.ONE, 0.2)
	tween.tween_interval(1.0)
	tween.tween_property(_chain_label, "modulate:a", 0.0, 0.4)


func announce(text: String) -> void:
	_show_message(text)


## Le tre carte della tana. Si sceglie con 1, 2, 3 o col mouse.
func show_offer(options: Array[String], upgrades: Upgrades) -> void:
	_upgrades = upgrades
	_offer_title.text = "Tana %d: scegli un potenziamento" % course.dens_reached
	for i in _offer_buttons.size():
		var button := _offer_buttons[i]
		button.visible = i < options.size()
		if not button.visible:
			continue
		var id := options[i]
		var item: Dictionary = Upgrades.CATALOG[id]
		var slot := "Potenziamento (si somma)"
		if item.slot == "fusion":
			slot = "Fusione: %s" % " + ".join(Upgrades.slots_of(id).map(func(sl): return Upgrades.SLOT_NAMES[sl]))
		elif item.slot != "":
			slot = "Slot: %s (resta fino a fine run)" % Upgrades.SLOT_NAMES[item.slot]
		button.text = "%d.  %s\n%s\n\n%s" % [i + 1, item.name, slot, item.text]
	_offer.visible = true
	_offer_buttons[0].grab_focus()


func hide_offer() -> void:
	_offer.visible = false


## L'equipaggiamento in basso a destra: un modificatore per slot e i
## potenziamenti numerici presi.
func show_equipment(upgrades: Upgrades) -> void:
	var lines: Array[String] = []
	var listed := {}
	for slot: String in Upgrades.SLOT_NAMES:
		var id: String = upgrades.slots[slot]
		if id == "" or listed.has(id):
			continue
		listed[id] = true
		var names := " + ".join(Upgrades.slots_of(id).map(func(sl): return Upgrades.SLOT_NAMES[sl]))
		lines.append("%s: %s" % [names, Upgrades.CATALOG[id].name])
	for id: String in upgrades.stacks:
		lines.append("%s ×%d" % [Upgrades.CATALOG[id].name, upgrades.stacks[id]])
	_equipment_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not _offer.visible or not event is InputEventKey or not event.pressed:
		return
	var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
	if index >= 0 and _offer_buttons[index].visible:
		get_viewport().set_input_as_handled()
		_upgrades.choose(index)


func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_interval(1.5)
	tween.tween_property(_message, "modulate:a", 0.0, 0.5)


func _build_top_left() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_health_label = _label(20)
	box.add_child(_health_label)
	_health_bar = _bar(Vector2(300, 18), HEALTH_COLOR)
	box.add_child(_health_bar)
	_heat_label = _label(20)
	box.add_child(_heat_label)
	_heat_bar = _bar(Vector2(300, 18), HEAT_COLORS[0])
	_heat_bar.max_value = Heat.MAX
	box.add_child(_heat_bar)


func _build_top_right() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -260
	box.offset_right = -16
	box.offset_top = 12
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(box)
	_distance_label = _label(40)
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_distance_label)
	_dens_label = _label(20)
	_dens_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_dens_label)
	_record_label = _label(16)
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_record_label.modulate = Color(1, 1, 1, 0.7)
	box.add_child(_record_label)
	_flies_label = _label(20, "Mosche: 0")
	_flies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_flies_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(_flies_label)


func _build_powers() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 16
	# Cresce verso l'alto quando si aggiungono lingua e schianto.
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_top = -16
	box.offset_bottom = -16
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	box.add_child(_label(16, "Super salto (tasto destro)"))
	_super_jump_bar = _bar(Vector2(220, 10), POWER_COLOR)
	_super_jump_bar.max_value = 1.0
	box.add_child(_super_jump_bar)
	box.add_child(_label(16, "Deltaplano (Spazio in aria)"))
	_glide_bar = _bar(Vector2(220, 10), POWER_COLOR)
	_glide_bar.max_value = 1.0
	box.add_child(_glide_bar)
	_tongue_row = VBoxContainer.new()
	_tongue_row.add_theme_constant_override("separation", 2)
	_tongue_row.add_child(_label(16, "Lingua (E)"))
	_tongue_bar = _bar(Vector2(220, 10), POWER_COLOR)
	_tongue_bar.max_value = 1.0
	_tongue_row.add_child(_tongue_bar)
	box.add_child(_tongue_row)
	_slam_row = VBoxContainer.new()
	_slam_row.add_theme_constant_override("separation", 2)
	_slam_row.add_child(_label(16, "Schianto (Ctrl in aria)"))
	_slam_bar = _bar(Vector2(220, 10), POWER_COLOR)
	_slam_bar.max_value = 1.0
	_slam_row.add_child(_slam_bar)
	box.add_child(_slam_row)
	box.add_child(_label(14, "F2: cambia stile grafico"))


func _build_fire() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float edge = smoothstep(0.35, 0.75, length(UV - vec2(0.5)) * 1.2);
	COLOR = vec4(0.9, 0.15, 0.0, edge * strength * 0.75);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_vignette.material = material
	add_child(_vignette)
	move_child(_vignette, 0)
	_fire_label = _label(20, "Fuoco")
	_fire_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_fire_label.offset_left = -120
	_fire_label.offset_right = 120
	_fire_label.offset_top = -44
	_fire_label.offset_bottom = -14
	_fire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_fire_label)


func _build_message() -> void:
	_message = _label(40)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.offset_left = -400
	_message.offset_right = 400
	_message.offset_top = 90
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	add_child(_message)


func _build_chain_label() -> void:
	_chain_label = _label(48)
	_chain_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_chain_label.offset_left = -300
	_chain_label.offset_right = 300
	_chain_label.offset_top = 60
	_chain_label.offset_bottom = 120
	_chain_label.pivot_offset = Vector2(300, 30)
	_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chain_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_chain_label.modulate.a = 0.0
	add_child(_chain_label)


func _build_offer() -> void:
	_offer = PanelContainer.new()
	_offer.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_offer.offset_left = -470
	_offer.offset_right = 470
	_offer.offset_top = -190
	_offer.offset_bottom = 190
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.92)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	_offer.add_theme_stylebox_override("panel", style)
	_offer.visible = false
	add_child(_offer)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_offer.add_child(box)
	_offer_title = _label(28)
	_offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_offer_title)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	box.add_child(cards)
	for i in 3:
		var button := Button.new()
		button.custom_minimum_size = Vector2(290, 260)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_card_pressed.bind(i))
		cards.add_child(button)
		_offer_buttons.append(button)


func _on_card_pressed(index: int) -> void:
	_upgrades.choose(index)


func _build_equipment() -> void:
	_equipment_label = _label(16)
	_equipment_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_equipment_label.offset_left = -360
	_equipment_label.offset_right = -16
	_equipment_label.offset_top = -130
	_equipment_label.offset_bottom = -16
	_equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_equipment_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_equipment_label)


func _build_game_over() -> void:
	_game_over = PanelContainer.new()
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_game_over.offset_left = -220
	_game_over.offset_right = 220
	_game_over.offset_top = -230
	_game_over.offset_bottom = 230
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.9)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	_game_over.add_theme_stylebox_override("panel", style)
	_game_over.visible = false
	add_child(_game_over)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_game_over.add_child(box)
	var title := _label(36, "Fine della corsa")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_game_over_text = _label(20)
	_game_over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_game_over_text)
	var button := Button.new()
	button.text = "Ricomincia (Invio)"
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(restart_requested.emit)
	box.add_child(button)
	var pond_button := Button.new()
	pond_button.text = "Lo stagno"
	pond_button.add_theme_font_size_override("font_size", 22)
	pond_button.pressed.connect(_open_pond)
	box.add_child(pond_button)
	var menu_button := Button.new()
	menu_button.text = "Menu"
	menu_button.add_theme_font_size_override("font_size", 22)
	menu_button.pressed.connect(menu_requested.emit)
	box.add_child(menu_button)
	_pond = Pond.new()
	_pond.visible = false
	add_child(_pond)


func _open_pond() -> void:
	_pond.refresh()
	_pond.visible = true


func _label(font_size: int, text := "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _bar(size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.5)
	background.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	_set_fill(bar, color)
	return bar


func _set_fill(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
