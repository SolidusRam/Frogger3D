class_name HeatMeter
extends Control
## Il calore nell'HUD: cinque gradini, uno per livello, dal giallo al rosso
## scuro. Si riempiono man mano; quello in corso è pieno solo in parte.

const COLORS: Array[Color] = [
	Color(0.98, 0.82, 0.28), Color(0.98, 0.64, 0.18), Color(0.96, 0.44, 0.14),
	Color(0.88, 0.22, 0.1), Color(0.62, 0.04, 0.14),
]
const GAP := 4.0

var value := 0.0:
	set(new_value):
		value = new_value
		queue_redraw()


func _draw() -> void:
	var levels := COLORS.size()
	var width := (size.x - GAP * (levels - 1)) / levels
	var per_level := Heat.MAX / levels
	for i in levels:
		var rect := Rect2(i * (width + GAP), 0.0, width, size.y)
		draw_rect(rect, Color(0, 0, 0, 0.55))
		var fill := clampf((value - i * per_level) / per_level, 0.0, 1.0)
		if fill > 0.0:
			draw_rect(Rect2(rect.position, Vector2(width * fill, size.y)), COLORS[i])
