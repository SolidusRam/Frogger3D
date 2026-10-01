extends SceneTree
## Super salto e deltaplano, nella zona di partenza, volando lungo +X.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var frog: Node3D
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	frog = Lib.load_main(self).get_node("Frog")


func _next(to_step: int, at: Vector3) -> void:
	step = to_step
	start = frame
	m = {}
	Lib.place(frog, at)


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	match step:
		0:
			if frame == 10:
				# Telecamera verso +X: lungo la zona di partenza c'è più spazio.
				frog.get_node("CameraRig").rotation.y = -PI / 2.0
				_next(1, Vector3(-30, 0.1, 0))
		1: # super salto da fermi
			if f == 20:
				m.x = frog.global_position.x
				m.top = 0.0
				Input.action_press("super_jump")
			if f == 21:
				Input.action_release("super_jump")
			if f > 20:
				m.top = maxf(m.top, frog.global_position.y)
			if f == 30:
				Input.action_press("super_jump")
			if f == 31:
				Input.action_release("super_jump")
				m.cooldown = frog.super_jump_cooldown_left()
			if f > 25 and frog.is_on_floor() and not m.has("landed"):
				m.landed = true
				t.check(m.top > 4.6 and m.top < 5.1, "super salto alto circa 5 m (%.2f)" % m.top)
				var forward: float = frog.global_position.x - m.x
				t.check(forward > 8.0 and forward < 9.5, "super salto porta avanti circa 9 m (%.1f)" % forward)
				t.check(m.cooldown > 2.0, "un secondo super salto durante la ricarica è bloccato")
			if f == 250:
				_next(2, Vector3(-30, 0.1, 6))
		2: # salto tenuto: non deve aprire il deltaplano
			if f == 20:
				Input.action_press("jump")
				m.glided = false
			if f > 20 and frog.is_gliding():
				m.glided = true
			if f == 90:
				Input.action_release("jump")
				t.check(not m.glided, "Spazio tenuto in un salto normale non apre il deltaplano")
				_next(3, Vector3(-30, 0.1, -6))
		3: # super salto + deltaplano
			if f == 20:
				m.x = frog.global_position.x
				Input.action_press("super_jump")
			if f == 21:
				Input.action_release("super_jump")
			if f == 50:
				Input.action_press("jump")
			if f > 50 and frog.is_gliding():
				m.glide_frames = m.get("glide_frames", 0) + 1
				if m.glide_frames == 60:
					m.descent = -frog.velocity.y
			if f > 55 and frog.is_on_floor() and not m.has("landed"):
				m.landed = true
				Input.action_release("jump")
				var distance: float = frog.global_position.x - m.x
				t.check(m.get("glide_frames", 0) / 60.0 > 2.3, "il deltaplano vola circa 2,5 s (%.2f)" % (m.get("glide_frames", 0) / 60.0))
				t.check(absf(m.get("descent", 0.0) - frog.glider_power.fall_speed) < 0.2, "col deltaplano scende a circa 2 m/s")
				t.check(distance > 25.0, "super salto più deltaplano coprono più di 25 m (%.1f)" % distance)
				m.charge_check = f + 120
			if m.has("charge_check") and f == m.charge_check:
				t.check(frog.glide_charge_ratio() > 0.75, "la carica del deltaplano si ricarica a terra")
				_next(4, Vector3(-30, 0.1, 10))
		4: # Spazio appena prima di atterrare: salto anticipato, niente deltaplano
			if f == 20:
				Input.action_press("jump")
			if f == 21:
				Input.action_release("jump")
			if f > 21 and frog.velocity.y < 0.0 and frog.global_position.y < 0.6 and not m.has("pressed"):
				m.pressed = f
				m.glided = false
				Input.action_press("jump")
			if m.has("pressed") and frog.is_gliding():
				m.glided = true
			if m.has("pressed") and f == m.pressed + 3:
				Input.action_release("jump")
			if m.has("pressed") and f == m.pressed + 20:
				t.check(not m.glided, "vicino al suolo Spazio non apre il deltaplano")
				t.check(frog.global_position.y > 0.3, "vicino al suolo Spazio fa un salto anticipato")
				t.finish(self)
	if frame > 3000:
		t.check(false, "il test non si è bloccato (step %d)" % step)
		t.finish(self)
	return false
