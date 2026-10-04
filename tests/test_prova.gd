extends SceneTree
## Modalità prova: livello di calore e calore bloccato, salto a un bioma,
## rana invincibile, poteri sempre carichi, una run di prova non salva il
## record.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node3D
var heat: Node
var prova: Node
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
	if paused and step != 4:
		main.get_node("Upgrades").choose(0)
	match step:
		0:
			if frame == 5:
				main.get_node("Course").den_reached.disconnect(main._on_den_reached)
				prova = Lib.by_script(main, "test_mode.gd")[0]
				t.check(not main.test_run, "una run normale non è di prova")
				prova.set_heat_level(3)
				t.check(heat.level() == 3, "si sceglie il livello di calore (%d)" % heat.level())
				t.check(main.test_run, "usata la modalità prova, la run è di prova")
				prova.set_heat_locked(true)
				prova.set_heat_level(1)
				t.check(heat.level() == 1, "in prova il calore può anche scendere")
				_next(1)
		1: # calore bloccato
			if f == 1:
				frog.power_used.emit(&"super_jump")
			if f == 300:
				t.check(heat.level() == 1, "col calore bloccato il livello resta quello scelto")
				prova.set_heat_locked(false)
				prova.jump_to("aeroporto")
				_next(2)
		2: # salto a un bioma
			if f == 30:
				var ahead := false
				for chunk in main.get_node("Course").get_children():
					if String(chunk.name).begins_with("AIRPORT"):
						var near_z: float = chunk.get_meta("near_z")
						if near_z < frog.global_position.z and near_z > frog.global_position.z - 15.0:
							ahead = true
				t.check(ahead, "il salto porta la rana davanti al bioma scelto")
				t.check(frog.is_on_floor() and frog.health == frog.max_health, "la rana arriva su una striscia sicura")
				prova.set_invincible(true)
				frog.take_hit(50, Vector3.ZERO)
				t.check(frog.health == frog.max_health, "invincibile, un colpo non toglie vita")
				prova.set_invincible(false)
				prova.set_charged(true)
				Input.action_press("super_jump")
				_next(3)
		3: # poteri sempre carichi
			if f == 2:
				Input.action_release("super_jump")
			if f == 10:
				t.check(frog.super_jump_power.is_ready() and frog.glider_power.charge == frog.glider_power.duration, "coi poteri sempre carichi il super salto è subito pronto")
				prova.set_charged(false)
				var saved: bool = main._save_record_if_better(99999.0)
				t.check(not saved and not FileAccess.file_exists("user://record_test.cfg"), "una run di prova non salva il record")
				prova.offer_upgrade()
				_next(4)
		4: # una tana a richiesta
			if f == 2:
				t.check(paused and main.get_node("Hud")._offer.visible, "si apre una tana a richiesta, a gioco fermo")
				main.get_node("Upgrades").choose(0)
			if f == 5:
				t.check(not paused, "scelto il power-up, il gioco riparte")
				t.finish(self)
	return false
