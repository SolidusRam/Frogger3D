extends SceneTree
## Porto: la nave porta la rana; a calore basso le gru caricano le navi
## seguendo lo schema, lasciano sempre un passaggio e non cacciano la rana;
## dal livello 3 la gru più vicina la caccia, con l'ombra che lampeggia, poi
## fissa quando la gru si blocca; il container in acqua affonda; l'acqua del
## porto toglie vita; la prua spinge e non fa male.

const Lib := preload("res://tests/lib.gd")
const SITE := Vector3(0, 0, 320)
## La punta della prua, in coordinate della nave (Ship.BOW_X).
const BOW_X := 21.5

var t := Lib.new()
var main: Node
var frog: Node3D
var heat: Node
var port: Node3D
var lane: Node3D
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


## La nave più vicina al centro della zona di gioco.
func _central_ship() -> Node3D:
	var best: Node3D = null
	for s in lane.ships():
		if best == null or absf(s.global_position.x) < absf(best.global_position.x):
			best = s
	return best


## Mette la rana su una casella vuota della nave.
func _board(ship: Node3D) -> void:
	for row in [1, 2, 0, 3]:
		for col in [2, 1, 3, 0, 4]:
			var cell := Vector2i(col, row)
			if ship.level(cell) == 0:
				Lib.place(frog, ship.to_global(ship.cell_position(cell, 0)) + Vector3(0, -1.2, 0))
				return


## Un punto della corsia, a quota h, dove non c'è nessuna nave.
func _open_water(h: float) -> Vector3:
	for x in range(-30, 31, 2):
		var point: Vector3 = lane.to_global(Vector3(x, h, 0))
		if lane.ship_under(Vector3(point.x, 3.0, point.z)) == null and lane.ship_under(Vector3(point.x + 4.0, 3.0, point.z)) == null and lane.ship_under(Vector3(point.x - 4.0, 3.0, point.z)) == null:
			return point
	return Vector3.INF


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				main.get_node("Course").den_reached.disconnect(main._on_den_reached)
				heat.value = 0.0
				port = load("res://scripts/port.gd").new()
				port.position = SITE
				main.add_child(port)
				lane = Lib.by_script(port, "ship_lane.gd")[0]
				t.check(lane.ships().size() >= 1, "la corsia parte con le navi già in acqua")
				_next(1)
		1: # la nave porta la rana
			if f == 2:
				m.ship = _central_ship()
				_board(m.ship)
			if f == 20:
				m.x = frog.global_position.x
				m.ship_x = m.ship.global_position.x
			if f == 80:
				var moved: float = frog.global_position.x - m.x
				var ship_moved: float = m.ship.global_position.x - m.ship_x
				t.check(absf(moved - ship_moved) < 0.5 and absf(ship_moved) > 2.0, "la nave porta la rana (%.1f m contro %.1f)" % [moved, ship_moved])
				_next(2)
		2: # calore basso: le gru caricano, lasciano un passaggio, non cacciano
			heat.value = 0.0
			if f == 1:
				m.start_fill = {}
				m.max_fill = {}
				m.blocked = 0
				m.aimed = false
				m.ship = _central_ship()
				_board(m.ship)
			# La rana resta sulla nave: se la nave esce dalla zona, ne prende un'altra.
			if f % 120 == 0 and absf(frog.global_position.x) > 25.0:
				m.ship = _central_ship()
				_board(m.ship)
			for s in lane.ships():
				var id: int = s.get_instance_id()
				if not m.start_fill.has(id):
					m.start_fill[id] = s.filled_cells()
				m.max_fill[id] = maxi(m.max_fill.get(id, 0), s.filled_cells())
				if not s.has_crossing():
					m.blocked += 1
			for c in lane.cranes:
				if c.aimed:
					m.aimed = true
			if f == 1200:
				var loaded := 0
				for id in m.start_fill:
					loaded += m.max_fill[id] - m.start_fill[id]
				t.check(loaded >= 3, "a calore basso le gru caricano le navi (%d caselle in 20 s)" % loaded)
				t.check(m.blocked == 0, "a calore basso resta sempre un passaggio sul ponte")
				t.check(not m.aimed, "a calore basso nessuna gru caccia la rana")
				t.check(frog.health == frog.max_health, "a calore basso la rana ferma sulla nave non viene colpita")
				_next(3)
		3: # dal livello 3 la gru più vicina caccia la rana
			heat.value = 65.0
			if f == 1:
				frog.heal_full()
			# La rana resta sulle navi al centro (in gioco ci sono i muri ai lati).
			if f == 1 or (absf(frog.global_position.x) > 20.0 and not m.has("warned")):
				m.ship = _central_ship()
				_board(m.ship)
			for c in lane.cranes:
				if c.aimed and c.is_warning():
					m.warned = true
					if c._shadow.visible and not c.is_locked():
						m.blinked = true
					if c.is_locked():
						if not m.has("locked_x"):
							m.locked_x = c.position.x
							m.locked_crane = c
						if m.locked_crane == c and c._shadow.visible:
							m.solid = m.get("solid", 0) + 1
			if m.has("locked_crane") and is_instance_valid(m.locked_crane) and m.locked_crane.is_locked():
				if absf(m.locked_crane.position.x - m.locked_x) > 0.01:
					m.moved_while_locked = true
			if frog.health <= frog.max_health - 50:
				t.check(m.has("warned"), "la gru avvisa prima di colpire")
				t.check(m.has("blinked"), "mentre insegue, l'ombra lampeggia")
				t.check(m.get("solid", 0) > 10 and not m.has("moved_while_locked"), "negli ultimi istanti la gru è ferma e l'ombra fissa")
				t.check(true, "dal livello 3 la gru colpisce la rana ferma sulla nave (dopo %.1f s)" % (f / 60.0))
				_next(4)
			elif f > 1200:
				t.check(false, "dal livello 3 la gru colpisce la rana ferma sulla nave (vita %d)" % frog.health)
				_next(4)
		4: # il container in acqua affonda
			heat.value = 0.0
			if f == 1:
				frog.heal_full()
				Lib.place(frog, SITE + Vector3(0, 0.1, 9))
				var at := _open_water(6.0)
				if at == Vector3.INF:
					t.check(false, "c'è un tratto d'acqua libera per la prova")
					_next(5)
					return false
				var drop: RigidBody3D = load("res://scripts/shipping_container.gd").new()
				port.add_child(drop)
				drop.global_position = at
				drop.rotation.y = PI / 2.0
				m.drop = drop
			if f == 240:
				t.check(not is_instance_valid(m.drop), "il container caduto in acqua affonda e sparisce")
				_next(5)
		5: # l'acqua del porto toglie vita; la prua spinge e non fa male
			if f == 1:
				frog.heal_full()
				var ship: Node3D = _central_ship()
				# Davanti alla prua, in acqua.
				var bow: Vector3 = ship.to_global(Vector3(25, 0, 0))
				Lib.place(frog, Vector3(bow.x, -0.5, bow.z))
				m.ship = ship
				m.offset = (frog.global_position - ship.global_position).dot(ship.global_basis.x)
			if f == 30:
				t.check(frog.is_swimming(), "nell'acqua del porto si nuota")
			if f == 120:
				var offset: float = (frog.global_position - m.ship.global_position).dot(m.ship.global_basis.x)
				t.check(frog.health < frog.max_health, "l'acqua del porto toglie vita (vita %d)" % frog.health)
				t.check(frog.health >= frog.max_health - 45, "la prua spinge ma non fa male (vita %d)" % frog.health)
				t.check(offset > BOW_X - 0.5, "la prua spinge avanti la rana (%.1f m davanti al centro)" % offset)
				t.finish(self)
	return false
