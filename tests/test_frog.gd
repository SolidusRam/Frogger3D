extends SceneTree
## Movimento, salto e ripartenza della rana, nella zona di partenza.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var frog: Node3D
var frame := 0
var m := {}


func _initialize() -> void:
	frog = Lib.load_main(self).get_node("Frog")


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		30:
			t.check(frog.is_on_floor() and absf(frog.global_position.y) < 0.05, "da ferma resta a terra")
			m.z = frog.global_position.z
			Input.action_press("move_forward")
		90:
			Input.action_release("move_forward")
			t.check(m.z - frog.global_position.z > 5.5, "in 1 s avanza più di 5,5 m (%.1f)" % (m.z - frog.global_position.z))
			t.check(absf(-frog.velocity.z - frog.move_speed) < 0.3, "arriva alla velocità massima (%.1f m/s)" % -frog.velocity.z)
		120:
			m.top = 0.0
			Input.action_press("jump")
		180:
			Input.action_release("jump")
			t.check(m.top > 1.6 and m.top < 1.9, "salto tenuto alto circa 1,8 m (%.2f)" % m.top)
			m.held = m.top
		200:
			m.top = 0.0
			Input.action_press("jump")
		203:
			Input.action_release("jump")
		260:
			t.check(m.top < m.held - 0.3, "salto breve più basso del salto tenuto (%.2f)" % m.top)
			t.check(frog.is_on_floor(), "dopo il salto torna a terra")
			frog.global_position = Vector3(0, -30, 0)
		263:
			t.check(frog.global_position.distance_to(Vector3.ZERO) < 0.5, "caduta fuori dal mondo: torna alla partenza")
			t.finish(self)
	if frame >= 120:
		m.top = maxf(m.get("top", 0.0), frog.global_position.y)
	return false
