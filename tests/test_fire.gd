extends SceneTree
## L'incendio: parte a max_gap dietro la rana, avanza più in fretta col calore,
## non resta mai più indietro di max_gap, la tana lo respinge, sull'acqua
## rallenta, brucia la rana che raggiunge, le auto raggiunte diventano rottami
## che non scaldano, l'HUD mostra la distanza.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var heat: Node
var fire: Node3D
var course: Node3D
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	heat = root.get_node("Heat")
	fire = main.get_node("Wildfire")
	course = main.get_node("Course")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


## Ferma la rana dov'è: niente gravità né movimenti, solo per misurare.
func _hold(at: Vector3) -> void:
	Lib.place(frog, at)


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				course.den_reached.disconnect(main._on_den_reached)
				fire.set_physics_process(true)
				fire.stopped = false
				fire.burn = 80.0
				heat.running = false
				heat.set_value(0.0)
				t.check(absf(fire.distance() - fire.max_gap) < 1.0, "l'incendio parte a %.0f m dietro la rana (%.1f)" % [fire.max_gap, fire.distance()])
				# Tolto il limite, per misurare la velocità vera.
				fire.max_gap = 1000.0
				_next(1)
				m.z = fire.front_z
		1: # velocità a calore zero e al massimo
			if f == 300:
				var slow: float = (m.z - fire.front_z) / 5.0
				t.check(absf(slow - fire.min_speed) < 0.15, "a calore zero avanza piano (%.2f m/s)" % slow)
				heat.set_value(100.0)
				m.z = fire.front_z
			if f == 600:
				var fast: float = (m.z - fire.front_z) / 5.0
				t.check(absf(fast - fire.max_speed) < 0.2, "al calore massimo corre (%.2f m/s)" % fast)
				# Accelera col tempo: dopo 10 minuti 2 m/s in più.
				var base: float = fire.speed()
				fire.elapsed += 600.0
				t.check(absf(fire.speed() - base - 2.0) < 0.01, "dopo 10 minuti corre 2 m/s in più (%.2f m/s)" % fire.speed())
				fire.elapsed += 6000.0
				t.check(fire.speed() == fire.top_speed, "ma non oltre %.1f m/s" % fire.top_speed)
				fire.elapsed = 0.0
				fire.max_gap = 40.0
				heat.set_value(0.0)
				# La rana scappa avanti di 150 m.
				frog.global_position.z -= 150.0
				frog.reset_physics_interpolation()
				_next(2)
		2: # mai più indietro di max_gap; la tana lo respinge
			if f == 3:
				t.check(fire.distance() <= fire.max_gap + 0.1, "non resta mai più indietro di %.0f m (%.1f)" % [fire.max_gap, fire.distance()])
				fire.front_z = frog.global_position.z + 10.0
				course.den_reached.emit(1, 100.0)
				t.check(absf(fire.distance() - fire.max_gap) < 0.1, "la tana respinge il fuoco a %.0f m" % fire.max_gap)
				_next(3)
		3: # sull'acqua rallenta
			if f == 1:
				for chunk in course.get_children():
					if chunk.has_meta("kind") and chunk.get_meta("kind") == 3 and not m.has("river"): # 3 = fiume
						m.river = chunk
				var center: float = m.river.get_meta("near_z") - m.river.get_meta("depth") / 2.0
				fire.max_gap = 1000.0
				# Il fiume può essere davanti alla rana: qui il fuoco non deve bruciarla.
				fire.burn = 0.0
				fire.front_z = center
				m.z = fire.front_z
			if f == 121:
				var on_water: float = (m.z - fire.front_z) / 2.0
				t.check(absf(on_water - fire.min_speed * fire.water_factor) < 0.1, "sull'acqua rallenta (%.2f m/s)" % on_water)
				fire.max_gap = 40.0
				fire.burn = 80.0
				_next(4)
		4: # brucia la rana che raggiunge; le auto raggiunte diventano rottami
			if f == 1:
				# Niente caos che non sia del fuoco: al calore alto le auto si
				# schiantano da sole e il rallentatore delle catene altererebbe
				# i tempi della prova.
				heat.set_value(0.0)
				main._recent_wrecks.clear()
				main._slowmo_until = 0
				frog.heal_full()
				fire.front_z = frog.global_position.z + 0.5
			if f == 30:
				t.check(frog.health < frog.max_health - 20, "il fuoco brucia la rana (vita %d)" % frog.health)
				frog.heal_full()
				var car: Node3D = Lib.cars(main).filter(func(c): return c.state == 0)[0]
				car.get_parent().set_physics_process(false)
				car.set_physics_process(false)
				m.car = car
				m.heat = heat.value
				fire.stopped = true
				fire.front_z = car.global_position.z
				# La rana vicina, perché un rottame normale scalderebbe.
				_hold(car.global_position + Vector3(0, 10, -8))
			if f == 40:
				t.check(m.car.state == 1, "l'auto raggiunta dal fuoco diventa rottame")
				t.check(absf(heat.value - m.heat) < 0.01, "i rottami dell'incendio non scaldano")
				t.check(Engine.time_scale == 1.0, "e non fanno scattare il rallentatore")
				var label: String = main.get_node("Hud")._fire_label.text
				t.check(label.ends_with(" m") and label.to_int() > 0, "l'HUD mostra la distanza dal fuoco (%s)" % label)
				t.finish(self)
	return false
