extends SceneTree
## Lo stagno: comprare statistiche (il prezzo sale), carte migliorate,
## rimborso; le statistiche valgono dalla run dopo (vita, carte offerte,
## incendio, seconda vita); una carta migliorata vale quando la si
## equipaggia; la schermata dello stagno; il menu iniziale porta al gioco.

const Lib := preload("res://tests/lib.gd")
const PROGRESS := "user://progressi_test.cfg"

var t := Lib.new()
var main: Node
var frame := 0
var step := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)


## Una partita nuova coi file dei test (come Lib.load_main, senza cancellare
## i progressi).
func _new_game() -> void:
	main.queue_free()
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://record_test.cfg"
	main.progress_path = PROGRESS
	root.add_child(main)
	current_scene = main


func _physics_process(_delta: float) -> bool:
	frame += 1
	var progress: GDScript = load("res://scripts/progress.gd")
	match step:
		0:
			if frame == 5:
				progress.add_flies(100)
				t.check(progress.flies == 100, "si parte con 100 mosche")
				t.check(progress.buy_stat("health") and progress.flies == 85 and progress.level("health") == 1, "Vita costa 15 al primo livello")
				t.check(progress.stat_cost("health") == 30, "il prezzo sale a ogni livello (30)")
				t.check(progress.buy_card("explosive_gloves") and progress.flies == 45, "un miglioramento di carta costa 40")
				t.check(not progress.buy_stat("revival"), "senza mosche abbastanza non si compra")
				progress.refund()
				t.check(progress.flies == 100 and progress.level("health") == 0 and progress.card_level("explosive_gloves") == 0, "il rimborso restituisce tutto")
				progress.stat_levels = {"health": 2, "choice": 1, "fire": 1, "revival": 1}
				progress.card_levels = {"explosive_gloves": 2}
				progress.save()
				_new_game()
				step = 1
		1:
			if frame == 12:
				var frog: Node3D = main.get_node("Frog")
				t.check(frog.max_health == 120 and frog.health == 120, "Vita al livello 2: 120 di vita massima")
				t.check(main.get_node("Upgrades").offer_size == 4, "Più scelta: quattro carte nelle tane")
				t.check(main.get_node("Wildfire").max_gap == 55.0, "Vantaggio: l'incendio resta 5 m più lontano")
				frog.take_hit(1000, Vector3.ZERO)
				t.check(not frog.is_dead and frog.health == 60, "Seconda vita: ci si rialza con metà vita (%d)" % frog.health)
				main.get_node("Upgrades").apply("explosive_gloves")
				var car: GDScript = load("res://scripts/car.gd")
				t.check(car.explosion_radius == 8.0 and not car.explosion_hurts_frog, "i guantoni esplosivi migliorati: raggio 8 m, non feriscono la rana")
				# La schermata dello stagno.
				var pond: Node = load("res://scripts/pond.gd").new()
				root.add_child(pond)
				var stats: int = pond._stats_box.get_child_count()
				var cards: int = pond._cards_box.get_child_count()
				t.check(stats == progress.STATS.size() and cards == progress.CARD_UPGRADES.size(), "lo stagno mostra statistiche e carte (%d e %d)" % [stats, cards])
				pond.queue_free()
				# Il menu iniziale porta al gioco.
				change_scene_to_file("res://scenes/menu.tscn")
				step = 2
				m.at = frame
		2:
			if frame == m.at + 5:
				var menu := current_scene
				var play: Button = null
				for node in menu.find_children("*", "Button", true, false):
					if node.text == "Gioca":
						play = node
				t.check(play != null, "il menu iniziale ha Gioca")
				play.pressed.emit()
			if frame == m.at + 15:
				t.check(current_scene.has_node("Frog"), "Gioca porta al gioco")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
				t.finish(self)
	return false
