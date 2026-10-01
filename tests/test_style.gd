extends SceneTree
## Stile: PS1 predefinito, F2 cambia stile e colori, materiali condivisi,
## lampo invertito a ogni nuovo livello di calore.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var style: Node
var heat: Node
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	style = root.get_node("Style")
	heat = root.get_node("Heat")


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		10:
			t.check(style.style_name() == "PS1", "lo stile predefinito è il PS1")
			t.check(style.material("grass") == style.material("grass"), "i materiali della tavolozza sono condivisi")
			m.grass = style.material("grass").albedo_color
			var press := InputEventAction.new()
			press.action = "style_next"
			press.pressed = true
			Input.parse_input_event(press)
		20:
			t.check(style.style_name() != "PS1", "F2 passa allo stile successivo (%s)" % style.style_name())
			t.check(style.material("grass").albedo_color != m.grass, "cambiando stile cambiano i colori")
			heat.add(25.0)
		22:
			var post: Node = main.get_node("PostFX/Screen")
			t.check(post.visible and float(post.material.get_shader_parameter("flash")) > 0.3, "nuovo livello di calore: lampo invertito")
			t.finish(self)
	return false
