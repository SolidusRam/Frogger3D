extends SceneTree
## Caccia agli errori: la rana avanza veloce col calore al massimo per 40 s.
## Il test passa se nel log non compare nessun errore di Godot (lo controlla
## run.sh): per esempio lambda su nodi già distrutti quando i blocchi alle
## spalle vengono cancellati mentre i rottami fumano ancora.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var frog: Node3D
var frame := 0


func _initialize() -> void:
	frog = Lib.load_main(self).get_node("Frog")


func _physics_process(_delta: float) -> bool:
	frame += 1
	# Nelle tane il gioco si ferma per le carte dei power-up: se ne sceglie una.
	if paused:
		current_scene.get_node("Upgrades").choose(0)
	if frame == 1:
		root.get_node("Heat").value = 100.0
	frog.global_position = Vector3(0, 30, -0.4 * frame)
	frog.velocity = Vector3.ZERO
	if frame == 2400:
		t.check(frog.global_position.z < -900.0, "la rana ha percorso quasi 1 km")
		t.finish(self)
	return false
