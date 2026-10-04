extends SceneTree
## Gradini di calore: sotto il livello dei gradini nessun annuncio; al
## raggiungerlo l'HUD mostra "la soglia del caos" con una riga per gradino,
## per qualche secondo; ai livelli successivi non torna; dopo una nuova run
## torna di nuovo.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var heat: Node
var hud: Node
var frame := 0
var start := 0
var step := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	heat = root.get_node("Heat")
	hud = main.get_node("Hud")


func _next(to_step: int) -> void:
	step = to_step
	start = frame


func _physics_process(_delta: float) -> bool:
	frame += 1
	var f := frame - start
	if paused and is_instance_valid(main):
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				heat.running = false
				heat.add(45.0 - heat.value)
			if frame == 10:
				t.check(heat.level() == heat.STEP_LEVEL - 1 and not hud.steps_visible(), "sotto il livello dei gradini nessun annuncio")
				heat.add(61.0 - heat.value)
				_next(1)
		1:
			if f == 2:
				t.check(hud.steps_visible(), "al livello %d compare la soglia del caos" % heat.STEP_LEVEL)
				var text: String = hud.steps_text()
				var all_listed: bool = heat.STEPS.all(func(s): return text.contains(s))
				t.check(all_listed and heat.STEPS.size() >= 2, "l'annuncio elenca tutti i gradini (%d)" % heat.STEPS.size())
			if f == 180:
				t.check(hud.steps_visible(), "l'annuncio resta qualche secondo (3 s)")
			if f == 420:
				t.check(not hud.steps_visible(), "poi sparisce (7 s)")
				heat.add(81.0 - heat.value)
			if f == 425:
				t.check(not hud.steps_visible(), "ai livelli successivi non torna")
				main.restart()
				_next(2)
		2:
			if f == 5:
				# La partita è stata ricaricata: nuova scena, nuovo HUD.
				main = current_scene
				main.record_path = "user://record_test.cfg"
				hud = main.get_node("Hud")
				heat.running = false
				heat.add(61.0 - heat.value)
			if f == 8:
				t.check(hud.steps_visible(), "in una nuova run l'annuncio torna")
				t.finish(self)
	return false
