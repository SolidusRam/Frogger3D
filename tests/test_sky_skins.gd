extends SceneTree
## Le skin del cielo: sulla strada volano ultraleggeri, elicotterini,
## mongolfiere e dirigibili (con eliche e rotori che girano); la ferrovia è
## una funivia; l'aereo è il quadrimotore a eliche; il porto ha dirigibili
## cargo ed elicotteri-gru (senza gambe); la tana ha l'arcobaleno;
## l'inseguitore è un temporale, anche nell'HUD. Tornati sulla terra, tutto
## torna com'era.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var course: Node3D
var fire: Node3D
var frame := 0
var start := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	course = main.get_node("Course")
	fire = main.get_node("Wildfire")


func _next(to_step: int) -> void:
	step = to_step
	start = frame
	m = {}


## I blocchi del tipo dato creati da jump_to (gli ultimi).
func _last_chunk(kind: int) -> Node3D:
	var found: Node3D = null
	for chunk in course.get_children():
		if chunk.has_meta("kind") and chunk.get_meta("kind") == kind:
			found = chunk
	return found


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				root.get_node("Heat").running = false
				main.next_world()
				course.jump_to(2) # strada
				_next(1)
		1: # la strada
			if f == 30:
				var cars := Lib.by_script(_last_chunk(2), "car.gd")
				t.check(not cars.is_empty() and cars.all(func(c): return c.sky), "sulla strada del cielo i veicoli volano (%d)" % cars.size())
				var types := {}
				var spinning := 0
				for car in cars:
					types[car.model_type] = true
					if not car._props.is_empty() or not car._rotors.is_empty():
						spinning += 1
				t.check(spinning > 0, "con eliche e rotori (%d)" % spinning)
				var balloon := cars.filter(func(c): return c.model_type == "van")
				if not balloon.is_empty():
					t.check(balloon[0].size.y > 3.0, "la mongolfiera è alta (%.1f m)" % balloon[0].size.y)
				var hud: Node = main.get_node("Hud")
				t.check(fire.sky and hud._fire_icon.kind == "storm", "l'inseguitore è un temporale, anche nell'HUD")
				t.check(fire._loop_sound == &"storm_loop", "e si sente la pioggia")
				course.jump_to(4) # ferrovia
				_next(2)
		2: # la funivia
			var tracks := Lib.by_script(_last_chunk(4), "rail_track.gd")
			if f == 1:
				t.check(not tracks.is_empty() and tracks.all(func(tr): return tr.sky), "la ferrovia del cielo è una funivia")
			var train: Node = null
			for track in tracks:
				if track.train:
					train = track.train
			if train:
				t.check(train.sky, "con le cabine appese al cavo")
				course.jump_to(7) # porto
				_next(3)
			elif f > 900:
				t.check(false, "passa una cabina entro 15 s")
				t.finish(self)
				return true
		3: # il porto
			if f == 30:
				var chunk := _last_chunk(7)
				var ships := Lib.by_script(chunk, "ship.gd")
				var cranes := Lib.by_script(chunk, "crane.gd")
				t.check(not ships.is_empty() and ships.all(func(s): return s.sky and not s._props.is_empty()), "il porto ha dirigibili cargo con le eliche (%d)" % ships.size())
				t.check(not cranes.is_empty() and cranes.all(func(c): return c.sky and not c._rotors.is_empty()), "ed elicotteri-gru (%d)" % cranes.size())
				t.check(cranes.all(func(c): return c.get_children().filter(func(n): return n is CollisionShape3D).is_empty()), "senza gambe che spingono")
				course.jump_to(6) # aeroporto
				_next(4)
		4: # l'aeroporto e la tana
			if f == 10:
				var taxiway: Node = Lib.by_script(_last_chunk(6), "taxiway.gd")[0]
				t.check(taxiway.sky, "l'aeroporto del cielo manda il quadrimotore a eliche")
				taxiway._send_plane()
				var planes := Lib.by_script(taxiway, "airplane.gd")
				t.check(not planes.is_empty() and planes[-1].sky and not planes[-1]._props.is_empty(), "con le eliche che girano")
				course.jump_to(5) # tana
				_next(5)
		5:
			if f == 10:
				var den: Node3D = _last_chunk(5).get_meta("den")
				t.check(den.find_child("Den", true, false) != null and den.scene_file_path.ends_with("den_sky.glb"), "la tana del cielo è la pozza con l'arcobaleno")
				t.check(not den.find_children("Flower_*", "", true, false).is_empty(), "coi fiori che si aprono")
				# Il giro: di nuovo la terra.
				main.next_world()
				course.jump_to(2)
				_next(6)
		6:
			if f == 30:
				var cars := Lib.by_script(_last_chunk(2), "car.gd")
				t.check(not cars.is_empty() and cars.all(func(c): return not c.sky), "sulla terra le auto tornano auto")
				t.check(not fire.sky and main.get_node("Hud")._fire_icon.kind == "fire", "e l'inseguitore torna fuoco")
				t.finish(self)
	return false
