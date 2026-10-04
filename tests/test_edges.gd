extends SceneTree
## Bordi: una nave porta la rana contro il bordo e il ponte di comando la
## spinge: la rana non entra nello scafo né passa oltre il muro, viene
## schiacciata (perde vita) e sbalzata di lato. In acqua, la prua che la
## spinge contro il bordo non la fa passare oltre il muro.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var lane: Node3D
var ship: Node3D
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


## Vero se la rana è dentro lo scafo o il ponte di comando della nave.
func _inside_ship() -> bool:
	var local: Vector3 = ship.to_local(frog.global_position)
	return absf(local.z) < 4.6 and local.x > -19.6 and local.x < 16.6 and local.y > -2.0 and local.y < 0.4


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				main.get_node("Course").den_reached.disconnect(main._on_den_reached)
				main.get_node("Course").jump_to(7) # porto
			if frame == 20:
				lane = Lib.by_script(main.get_node("Course"), "ship_lane.gd")[0]
				ship = lane.ships()[0]
				var dir: float = ship.global_basis.x.x
				# La nave poco prima del bordo, la rana sul ponte davanti al ponte
				# di comando: tra un secondo il ponte di comando la spinge.
				ship.position.x = dir * (35.5 + 12.0)
				m.dir = dir
			if frame == 23:
				frog.global_position = ship.to_global(Vector3(-12.0, ship.DECK_Y + 0.1, 0.0))
				frog.reset_physics_interpolation()
				_next(1)
		1:
			if absf(frog.global_position.x) > 37.6:
				m.outside = true
			if _inside_ship():
				m.inside = true
			if f == 180:
				t.check(not m.has("inside"), "il ponte di comando non fa entrare la rana nello scafo")
				t.check(not m.has("outside"), "la rana non passa oltre il bordo")
				t.check(frog.health < frog.max_health, "schiacciata contro il bordo perde vita (vita %d)" % frog.health)
				_next(2)
		2: # in acqua, la prua spinge la rana contro il bordo
			if f == 1:
				frog.heal_full()
				var dir: float = m.get("dir", ship.global_basis.x.x)
				ship.position.x = dir * (36.0 - 21.5 - 5.0)
			if f == 4:
				var dir: float = ship.global_basis.x.x
				frog.global_position = Vector3(dir * 36.0, -0.6, ship.global_position.z)
				frog.reset_physics_interpolation()
			if f > 4 and absf(frog.global_position.x) > 37.6:
				m.outside = true
			if f == 300:
				t.check(not m.has("outside"), "la prua non spinge la rana oltre il bordo")
				t.finish(self)
	return false
