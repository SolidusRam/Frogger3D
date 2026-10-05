extends SceneTree
## Le animazioni della rana: a scatti, 15 pose al secondo; salendo le zampe
## spingono indietro e il corpo si inclina in su; da ferma, dopo qualche
## secondo, tira pugni all'aria; la lingua parte dalla bocca.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node
var frame := 0
var m := {"leg": 0.0, "pitch": 0.0, "glove": 0.0}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		60:
			t.check(load("res://scripts/frog_animator.gd").pose_fps == 15.0, "le pose della rana vanno a scatti, 15 al secondo")
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
	if frame > 60 and frame < 240 and frog.velocity.y > 3.0:
		m.leg = maxf(m.leg, frog.model.get_node("Torso/LegL").rotation.x)
		m.pitch = maxf(m.pitch, frog.model.rotation.x)
	if frame > 240 and m.has("rest"):
		m.glove = maxf(m.glove, m.rest.z - frog.model.get_node("GloveL").position.z)
	return false
