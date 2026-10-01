class_name Hud
extends CanvasLayer
## L'HUD: vita e calore in alto a sinistra, distanza e tane in alto a destra,
## poteri in basso a sinistra, messaggi al centro e schermata di fine run.
## Costruito da codice per restare in un solo file finché i modelli e la
## grafica definitiva non arrivano.

signal restart_requested

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
var _super_jump_bar: ProgressBar
var _glide_bar: ProgressBar
var _message: Label
var _game_over: PanelContainer
var _game_over_text: Label
var _chain_label: Label
var _last_heat_level := 0


func _ready() -> void:
	_build_top_left()
	_build_top_right()
	_build_powers()
	_build_message()
	_build_chain_label()
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
	var cooldown := frog.super_jump_cooldown_left()
	_super_jump_bar.value = 1.0 - cooldown / frog.super_jump_cooldown
	_glide_bar.value = frog.glide_charge_ratio()


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


func _build_powers() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 16
	box.offset_top = -110
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
	box.add_child(_label(14, "F2: cambia stile grafico"))


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


func _build_game_over() -> void:
	_game_over = PanelContainer.new()
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_game_over.offset_left = -220
	_game_over.offset_right = 220
	_game_over.offset_top = -170
	_game_over.offset_bottom = 170
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
