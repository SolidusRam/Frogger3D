class_name PerfOverlay
extends CanvasLayer
## F3: il contatore delle prestazioni, in alto al centro. Fotogrammi al
## secondo, millisecondi del fotogramma e della fisica, chiamate di disegno e oggetti
## disegnati. Resta acceso da una run all'altra finché il gioco è aperto.

static var shown := false

var _label: Label
var _refresh := 0.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.theme = UiTheme.get_theme()
	_label.theme_type_variation = "HudLabel"
	_label.add_theme_font_size_override("font_size", 15)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.offset_left = -360
	_label.offset_right = 360
	_label.offset_top = 34
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.visible = shown


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("perf"):
		shown = not shown
		_label.visible = shown


func _process(delta: float) -> void:
	if not shown:
		return
	# Quattro volte al secondo: i numeri si leggono senza sfarfallare.
	_refresh -= delta / maxf(Engine.time_scale, 0.001)
	if _refresh > 0.0:
		return
	_refresh = 0.25
	_label.text = "%d fps   ·   fotogramma %.1f ms   ·   fisica %.1f ms   ·   %d disegni   ·   %d oggetti" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	]
