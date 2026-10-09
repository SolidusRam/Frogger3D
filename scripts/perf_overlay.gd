class_name PerfOverlay
extends CanvasLayer
## F3: il contatore delle prestazioni, in alto al centro. Prima riga: fotogrammi
## al secondo, millisecondi di script e fisica, chiamate di disegno e oggetti
## disegnati. Seconda riga: dove va il tempo di un fotogramma (il totale, il
## lavoro della CPU per la grafica, la GPU se il browser la misura, e il resto,
## cioè browser, audio e attese). Resta acceso da una run all'altra finché il
## gioco è aperto.
## Con il contatore acceso, per capire cosa costa: 1 spegne e riaccende le ombre
## del sole, 2 le luci puntiformi (incendio, portale), 3 le particelle; F2
## cambia stile, cioè toglie o mette il post-processing.

static var shown := false

var _label: Label
var _refresh := 0.0
var _frames := 0
var _frame_usec := 0
var _last_usec := 0
var _off := {}


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.theme = UiTheme.get_theme()
	_label.theme_type_variation = "HudLabel"
	_label.add_theme_font_size_override("font_size", 15)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.offset_left = -420
	_label.offset_right = 420
	_label.offset_top = 34
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_show(shown)


func _show(on: bool) -> void:
	shown = on
	_label.visible = on
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), on)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("perf"):
		_show(not shown)
	elif shown and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _toggle("ombre")
			KEY_2: _toggle("luci")
			KEY_3: _toggle("particelle")


## Spegne o riaccende un gruppo di cose, per vedere quanto costano.
func _toggle(what: String) -> void:
	var off: bool = not _off.get(what, false)
	_off[what] = off
	match what:
		"ombre":
			for light in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
				light.shadow_enabled = not off
		"luci":
			for light in get_tree().root.find_children("*", "OmniLight3D", true, false):
				light.visible = not off
		"particelle":
			for particles in get_tree().root.find_children("*", "CPUParticles3D", true, false):
				particles.visible = not off


func _process(delta: float) -> void:
	if not shown:
		return
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frame_usec += now - _last_usec
		_frames += 1
	_last_usec = now
	# Quattro volte al secondo: i numeri si leggono senza sfarfallare.
	_refresh -= delta / maxf(Engine.time_scale, 0.001)
	if _refresh > 0.0:
		return
	_refresh = 0.25
	var viewport := get_viewport().get_viewport_rid()
	var frame_ms := _frame_usec / 1000.0 / maxi(_frames, 1)
	_frame_usec = 0
	_frames = 0
	var script_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var render_cpu := RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu()
	var render_gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	var rest := frame_ms - script_ms - physics_ms - render_cpu
	var off: Array = _off.keys().filter(func(key: String) -> bool: return _off[key])
	_label.text = "%d fps   ·   script %.1f ms   ·   fisica %.1f ms   ·   %d disegni   ·   %d oggetti\nfotogramma %.0f ms = grafica CPU %.1f + script e fisica + resto %.0f   ·   GPU %s%s" % [
		Engine.get_frames_per_second(),
		script_ms,
		physics_ms,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		frame_ms,
		render_cpu,
		rest,
		"%.1f ms" % render_gpu if render_gpu > 0.0 else "n.d.",
		("   ·   spenti: " + ", ".join(off)) if not off.is_empty() else "",
	]
