extends SceneTree
## L'arrivo in tana: i fiori sono boccioli finché la rana non arriva; poi si
## aprono, si alzano le lucciole, la rana si ferma e alza i guantoni; dopo la
## festa arrivano le carte, e scelta la carta la rana riparte.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	main.den_celebration_seconds = 0.9


func _den_chunk() -> Node3D:
	for chunk in main.get_node("Course").get_children():
		if chunk.has_meta("den"):
			return chunk
	return null


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		5:
			m.chunk = _den_chunk()
			var flowers: Array = m.chunk.get_meta("den").find_children("Flower_*", "", false, false)
			m.flower = flowers[0]
			t.check(flowers.size() > 0 and m.flower.scale.x < 0.5, "prima di arrivare i fiori sono boccioli (%d fiori)" % flowers.size())
			Lib.place(frog, Vector3(0, 0.5, m.chunk.global_position.z + 0.1))
		20:
			t.check(frog.asleep and not main.get_node("Hud").is_offer_open(), "in tana la rana si ferma a fare festa, le carte non ancora")
			var glove: Node3D = frog.model.get_node("GloveL")
			t.check(glove.position.y > glove.get_meta("rest").y + 0.5, "e alza i guantoni")
			t.check(m.flower.scale.x > 0.9, "i fiori si aprono")
			var fireflies: Array = m.chunk.get_meta("den").find_children("*", "CPUParticles3D", false, false)
			t.check(fireflies.size() == 2, "dai laghetti si alzano le lucciole")
		90:
			t.check(paused and main.get_node("Hud").is_offer_open(), "dopo la festa arrivano le carte, a gioco fermo")
			main.get_node("Upgrades").choose(0)
		95:
			t.check(not paused and not frog.asleep, "scelta la carta, la rana riparte")
			t.finish(self)
	return false
