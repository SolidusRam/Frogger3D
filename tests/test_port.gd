extends SceneTree
## Porto: il nastro trasporta la rana; la gru avvisa con l'ombra prima di
## lasciar cadere il container, e negli ultimi istanti si blocca; il container
## fa male a chi sta sotto e poi resta a terra; col calore alto la gru mira
## molto più spesso alla rana; la gru prevede dove il nastro porterà la rana.

const Lib := preload("res://tests/lib.gd")
const SITE := Vector3(0, 0, 320)

var t := Lib.new()
var main: Node
var frog: Node3D
var heat: Node
var site: Node3D
var belt: Node3D
var crane: Node3D
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	heat = root.get_node("Heat")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				main.get_node("Course").den_reached.disconnect(main._on_den_reached)
				Lib.test_ground(main)
				site = Node3D.new()
				main.add_child(site)
				site.global_position = SITE
				belt = load("res://scripts/conveyor.gd").new()
				belt.direction = 1.0
				belt.speed = 4.0
				belt.position.z = -3.0
				site.add_child(belt)
				Lib.place(frog, SITE + Vector3(-20, 0.5, -3))
				_next(1)
		1: # il nastro
			if f == 20:
				m.x = frog.global_position.x
			if f == 80:
				var moved: float = frog.global_position.x - m.x
				t.check(moved > 3.0 and moved < 5.0, "il nastro trasporta la rana a circa 4 m/s (%.1f m in 1 s)" % moved)
				# La gru, con la rana ferma sotto, accanto al nastro.
				Lib.place(frog, SITE + Vector3(10, 0.1, 2))
				crane = load("res://scripts/crane.gd").new()
				crane.aim_chance = 1.0
				site.add_child(crane)
				_next(2)
		2: # avviso, caduta, colpo
			if crane.is_warning() and not m.has("warning_at"):
				m.warning_at = f
			if m.has("warning_at") and crane.is_warning() and crane._shadow.visible:
				m.blinked = true
			if crane.is_locked() and not m.has("locked_x"):
				m.locked_x = crane.global_position.x
			if m.has("warning_at") and not m.has("dropped") and crane.phase == 2:
				m.dropped = f
				var lead: float = (f - m.warning_at) / 60.0
				t.check(lead > 1.4 and lead < 1.6, "l'ombra avvisa circa 1,5 s prima della caduta (%.2f)" % lead)
				t.check(m.has("blinked"), "l'ombra a terra lampeggia")
				t.check(absf(crane.global_position.x - frog.global_position.x) < 1.0, "la gru ha mirato alla rana")
				t.check(m.has("locked_x") and absf(m.locked_x - crane.global_position.x) < 0.01, "negli ultimi istanti la gru è ferma")
				m.container = site.get_children().filter(func(n): return n.has_method("_physics_process") and n.get_script() and n.get_script().resource_path.ends_with("shipping_container.gd"))[0]
			if m.has("dropped") and f == m.dropped + 120:
				t.check(frog.health <= frog.max_health - 50, "il container colpisce chi sta sotto (vita %d)" % frog.health)
				var c: Node3D = m.container
				t.check(is_instance_valid(c) and absf(c.global_position.y - 1.3) < 0.3, "a terra il container resta come ostacolo (quota %.2f)" % c.global_position.y)
				_next(3)
			if f > 1200:
				t.check(false, "la gru lascia cadere un container entro 20 s")
				t.finish(self)
		3: # col calore la gru mira alla rana
			Lib.place(frog, SITE + Vector3(20, 0.1, 2))
			crane.aim_chance = 0.25
			var aimed := [0, 0]
			for i in 2:
				heat.value = 0.0 if i == 0 else 100.0
				for n in 300:
					crane._choose_target()
					if absf(crane.target_x - 20.0) < 0.5:
						aimed[i] += 1
			t.check(aimed[1] > aimed[0] + 150, "col calore alto la gru mira molto più spesso (%d contro %d su 300)" % [aimed[1], aimed[0]])
			heat.value = 0.0
			crane.queue_free()
			_next(4)
		4: # la rana ferma su un nastro: la gru calcola dove sarà
			if f == 1:
				frog.heal_full()
				var ride: Node3D = load("res://scripts/conveyor.gd").new()
				ride.direction = -1.0
				ride.speed = 4.0
				ride.position.z = 1.5
				site.add_child(ride)
				Lib.place(frog, SITE + Vector3(0, 0.5, 1.5))
				crane = load("res://scripts/crane.gd").new()
				crane.aim_chance = 1.0
				crane.position.x = -5.0
				site.add_child(crane)
			if frog.health <= frog.max_health - 50:
				t.check(true, "la gru colpisce la rana portata dal nastro (dopo %.1f s)" % (f / 60.0))
				t.finish(self)
			if f > 600:
				t.check(false, "la gru colpisce la rana portata dal nastro (vita %d)" % frog.health)
				t.finish(self)
	return false
