extends Control
## Il menu iniziale: Gioca, Lo stagno, Esci, e le mosche messe da parte.
## Avviato con le opzioni della modalità prova (tools/prova.sh), salta il
## menu e parte subito.

const GAME := "res://scenes/main.tscn"

@export var progress_path := "user://progressi.cfg"

var _flies_label: Label
var _pond: Pond


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		get_tree().change_scene_to_file.call_deferred(GAME)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Heat.running = false
	Progress.load_from(progress_path)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.06, 0.12, 0.08)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -220
	box.offset_right = 220
	box.offset_top = -200
	box.offset_bottom = 200
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var title := _label("Frogger 3D", 56)
	box.add_child(title)
	var subtitle := _label("La rana scappa dall'incendio", 20)
	subtitle.modulate = Color(1, 1, 1, 0.7)
	box.add_child(subtitle)
	_flies_label = _label("", 22)
	_flies_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(_flies_label)
	var play := _button("Gioca", _play)
	box.add_child(play)
	box.add_child(_button("Lo stagno", _open_pond))
	box.add_child(_button("Esci", get_tree().quit))
	play.grab_focus()

	_pond = Pond.new()
	_pond.visible = false
	_pond.closed.connect(_refresh)
	add_child(_pond)
	_refresh()


func _refresh() -> void:
	_flies_label.text = "Mosche: %d" % Progress.flies


func _play() -> void:
	get_tree().change_scene_to_file(GAME)


func _open_pond() -> void:
	_pond.refresh()
	_pond.visible = true


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(action)
	return button
