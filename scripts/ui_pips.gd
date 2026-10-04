class_name UiPips
extends Control
## I livelli di una statistica come pallini: pieni fino al livello raggiunto.

var filled := 0
var total := 1
var color := UiTheme.GOLD


static func make(level: int, max_level: int, pip_color: Color) -> UiPips:
	var pips := UiPips.new()
	pips.filled = level
	pips.total = max_level
	pips.color = pip_color
	pips.custom_minimum_size = Vector2(max_level * 18, 16)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pips


func _draw() -> void:
	for i in total:
		var center := Vector2(8 + i * 18, size.y / 2.0)
		if i < filled:
			draw_circle(center, 6.0, color)
		draw_arc(center, 6.0, 0.0, TAU, 16, color if i < filled else UiTheme.LINE, 2.0)
