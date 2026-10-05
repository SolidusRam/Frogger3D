extends SceneTree
## Le animazioni della rana: lontano dal fuoco la testa sta dritta, col fuoco
## vicino si gira a guardarlo; salendo le zampe spingono indietro e il corpo
## si inclina in su; da ferma, dopo qualche secondo, tira pugni all'aria; la
## lingua parte dalla bocca.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node
var frame := 0
var m := {"head": 0.0, "leg": 0.0, "pitch": 0.0, "glove": 0.0}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")


func _process(_delta: float) -> bool:
	frame += 1
	var head: Node3D = frog.model.get_node("Torso/Head")
	var fire: Node = main.get_node("Wildfire")
	match frame:
		60:
			t.check(absf(head.rotation.y) < 0.01, "col fuoco lontano la testa sta dritta")
			fire.stopped = false
			fire.burn = 0.0
			fire.set_physics_process(true)
			fire.front_z = frog.global_position.z + 8.0
		150:
			t.check(m.head > 1.0, "col fuoco vicino la rana si gira a guardarlo (%.2f rad)" % m.head)
			fire.stopped = true
			fire.set_physics_process(false)
			frog.launch(Vector3(0, 12, 0))
		240:
			t.check(m.leg > 0.3 and m.pitch > 0.1, "salendo le zampe spingono indietro e il corpo si inclina in su")
			m.rest = frog.model.get_node("GloveL").get_meta("rest")
		600:
			t.check(m.glove > 0.2, "da ferma, dopo qualche secondo, tira pugni all'aria")
			var mouth: Vector3 = frog.mouth_position()
			var local: Vector3 = frog.visual.global_transform.affine_inverse() * mouth
			t.check(local.z < -0.3 and local.y > 0.2 and local.y < 0.5, "la lingua parte dalla bocca, davanti alla testa")
			t.finish(self)
	if frame > 60 and frame < 150:
		m.head = maxf(m.head, absf(head.rotation.y))
	if frame > 150 and frame < 240 and frog.velocity.y > 3.0:
		m.leg = maxf(m.leg, frog.model.get_node("Torso/LegL").rotation.x)
		m.pitch = maxf(m.pitch, frog.model.rotation.x)
	if frame > 240 and m.has("rest"):
		m.glove = maxf(m.glove, m.rest.z - frog.model.get_node("GloveL").position.z)
	return false
