class_name SlotIcon
extends Control
## L'icona di un attrezzo della rana, disegnata con poche forme piene come i
## modelli low-poly: guantone, molla, ala a delta, goccia (il corpo), lingua.
## Più tre icone che non sono attrezzi: "" (un potenziamento numerico: una
## freccia in su), "fusion" (due anelli intrecciati) e le mosche ("fly",
## "golden") e la fiamma dell'incendio ("fire"). Il colore viene da
## UiTheme.SLOT_COLORS.

var kind := "":
	set(value):
		kind = value
		queue_redraw()


static func make(icon_kind: String, side := 40.0) -> SlotIcon:
	var icon := SlotIcon.new()
	icon.kind = icon_kind
	icon.custom_minimum_size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s < 4.0:
		return
	var o := (size - Vector2(s, s)) / 2.0
	# Coordinate da 0 a 1 dentro il quadrato dell'icona.
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var ink := UiTheme.INK
	var color: Color = UiTheme.SLOT_COLORS.get(kind, UiTheme.GOLD)
	var line := maxf(2.0, s * 0.07)
	match kind:
		"gloves":
			# Polsino, pugno, pollice.
			draw_rect(Rect2(p.call(0.28, 0.66), Vector2(0.44, 0.24) * s), Color(0.95, 0.93, 0.86))
			draw_rect(Rect2(p.call(0.28, 0.66), Vector2(0.44, 0.24) * s), ink, false, line * 0.6)
			_circle(p.call(0.5, 0.42), 0.32 * s, color, ink, line)
			_circle(p.call(0.22, 0.52), 0.13 * s, color.darkened(0.15), ink, line * 0.8)
		"springs":
			var points := PackedVector2Array()
			for i in 7:
				points.append(p.call(0.25 if i % 2 == 0 else 0.75, 0.2 + i * 0.1))
			draw_polyline(points, ink, line * 2.2)
			draw_polyline(points, color, line * 1.2)
			for y in [0.14, 0.86]:
				var plate := Rect2(p.call(0.18, y - 0.05), Vector2(0.64, 0.1) * s)
				draw_rect(plate, color.darkened(0.25))
				draw_rect(plate, ink, false, line * 0.6)
		"wing":
			var delta := PackedVector2Array([p.call(0.5, 0.14), p.call(0.92, 0.78), p.call(0.08, 0.78)])
			draw_colored_polygon(delta, color)
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.14), p.call(0.62, 0.78), p.call(0.38, 0.78)]), Color(0.95, 0.92, 0.85))
			delta.append(delta[0])
			draw_polyline(delta, ink, line)
			draw_line(p.call(0.5, 0.78), p.call(0.5, 0.92), ink, line)
		"body":
			# Una goccia: la pelle e l'acqua. La punta, poi l'arco di sotto.
			var drop := PackedVector2Array([p.call(0.5, 0.08)])
			for i in 21:
				var a := lerpf(-PI / 2.0 + 0.75, 3.0 * PI / 2.0 - 0.75, i / 20.0)
				drop.append(p.call(0.5 + cos(a) * 0.27, 0.6 + sin(a) * 0.27))
			_shape(drop, color, ink, line)
			_circle(p.call(0.42, 0.6), 0.06 * s, Color(1, 1, 1, 0.7), Color(0, 0, 0, 0), 0.0)
		"tongue":
			# La bocca e la lingua che si srotola fino a un pallino.
			draw_line(p.call(0.08, 0.3), p.call(0.4, 0.3), ink, line * 1.4)
			var curl := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				curl.append(p.call(0.3 + t * 0.5, 0.3 + sin(t * PI) * 0.42))
			draw_polyline(curl, ink, line * 2.6)
			draw_polyline(curl, color, line * 1.5)
			_circle(curl[curl.size() - 1], 0.11 * s, color, ink, line)
		"fusion":
			draw_arc(p.call(0.38, 0.5), 0.24 * s, 0.0, TAU, 24, ink, line * 2.2)
			draw_arc(p.call(0.62, 0.5), 0.24 * s, 0.0, TAU, 24, ink, line * 2.2)
			draw_arc(p.call(0.38, 0.5), 0.24 * s, 0.0, TAU, 24, color, line * 1.2)
			draw_arc(p.call(0.62, 0.5), 0.24 * s, 0.0, TAU, 24, color.lightened(0.2), line * 1.2)
		"fire":
			# Una fiamma: due lingue, fuori rossa e dentro gialla.
			var outer := PackedVector2Array([
				p.call(0.5, 0.06), p.call(0.66, 0.32), p.call(0.76, 0.24), p.call(0.84, 0.58),
				p.call(0.72, 0.86), p.call(0.5, 0.94), p.call(0.28, 0.86), p.call(0.16, 0.58),
				p.call(0.3, 0.36), p.call(0.38, 0.46),
			])
			_shape(outer, Color(0.95, 0.32, 0.08), ink, line)
			draw_colored_polygon(PackedVector2Array([
				p.call(0.5, 0.42), p.call(0.64, 0.66), p.call(0.58, 0.84), p.call(0.42, 0.84), p.call(0.36, 0.66),
			]), Color(1.0, 0.82, 0.25))
		"fly", "golden":
			var body_color := UiTheme.GOLD if kind == "golden" else Color(0.16, 0.15, 0.14)
			for side in [-1.0, 1.0]:
				_ellipse(p.call(0.5 + side * 0.2, 0.36), Vector2(0.2, 0.13) * s, Color(0.92, 0.95, 1.0, 0.85), ink, line * 0.6)
			_ellipse(p.call(0.5, 0.58), Vector2(0.17, 0.25) * s, body_color, ink, line)
		_:
			# Un potenziamento numerico: una freccia in su.
			_shape(PackedVector2Array([
				p.call(0.5, 0.12), p.call(0.86, 0.5), p.call(0.64, 0.5), p.call(0.64, 0.88),
				p.call(0.36, 0.88), p.call(0.36, 0.5), p.call(0.14, 0.5),
			]), color, ink, line)


func _circle(center: Vector2, radius: float, fill: Color, outline: Color, width: float) -> void:
	draw_circle(center, radius, fill)
	if width > 0.0:
		draw_arc(center, radius, 0.0, TAU, 24, outline, width)


func _ellipse(center: Vector2, radii: Vector2, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	_shape(points, fill, outline, width)


func _shape(points: PackedVector2Array, fill: Color, outline: Color, width: float) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, outline, width)
