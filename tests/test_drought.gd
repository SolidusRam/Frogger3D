extends SceneTree
## La Siccità: la tana 5 apre il livello dopo, per quella rana; i livelli si
## scelgono fra quelli aperti; gli handicap si sommano e tornano a zero a ogni
## run; le mosche valgono di più; le pelli di rame, argento e oro arrivano coi
## livelli superati, e brillano come metallo. Una run di prova non apre niente.

const Lib := preload("res://tests/lib.gd")
const PROGRESS := "user://progressi_test.cfg"

var t := Lib.new()
var main: Node
var hud: Node
var drought: GDScript
var cosmetics: GDScript
var progress: GDScript
var frame := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	hud = main.get_node("Hud")
	drought = load("res://scripts/drought.gd")
	cosmetics = load("res://scripts/cosmetics.gd")
	progress = load("res://scripts/progress.gd")
	load("res://scripts/feats.gd").unlock_all = false


## La tana: le carte fermano il gioco, si chiudono subito.
func _den(count: int) -> void:
	main.get_node("Course").den_reached.emit(count, 100.0)
	hud.hide_offer()
	paused = false


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		3:
			var heat: Node = root.get_node("Heat")
			main.frog_kind = "comune"
			main.drought = 0
			t.check(drought.max_level("comune") == 0, "all'inizio niente Siccità")
			_den(4)
			t.check(drought.max_level("comune") == 0, "la tana 4 non basta")
			_den(5)
			t.check(drought.max_level("comune") == 1 and drought.max_level("raganella") == 0, "la tana 5 apre la Siccità 1, solo per quella rana")
			drought.choose("comune", 3)
			t.check(drought.selected("comune") == 1, "non si sceglie un livello chiuso")
			# Gli handicap del livello 5, tutti insieme.
			var fire: Node = main.get_node("Wildfire")
			var gap: float = fire.max_gap
			var offer: int = main.upgrades.offer_size
			var damage: float = main.frog.damage_factor
			var flies: float = main.fly_value
			drought.apply(main, 5)
			t.check(is_equal_approx(fire.max_gap, gap - 10.0), "l'incendio parte 10 m più vicino")
			t.check(is_equal_approx(heat.traffic_factor, 1.15) and is_equal_approx(heat.growth_factor, 1.3), "traffico più veloce, calore più rapido")
			t.check(main.upgrades.offer_size == offer - 1 and is_equal_approx(main.frog.damage_factor, damage * 1.25), "una carta in meno, colpi più forti")
			t.check(is_equal_approx(main.fly_value, flies * 2.0), "le mosche valgono il doppio (+20% a livello)")
			var before: float = heat.value
			heat.add(10.0)
			t.check(is_equal_approx(heat.value - before, 13.0), "il calore sale il 30% in più")
			heat.reset()
			t.check(heat.traffic_factor == 1.0 and heat.growth_factor == 1.0, "una run nuova riparte senza handicap")
			# Le pelli a gradi.
			progress.drought_best["comune"] = 3
			t.check(cosmetics.unlocked("copper", "comune") and cosmetics.unlocked("silver", "comune") and not cosmetics.unlocked("gold", "comune"), "superata la Siccità 3: rame e argento, non l'oro")
			t.check(not cosmetics.unlocked("copper", "raganella"), "ogni rana le guadagna da sé")
			var gold: StandardMaterial3D = root.get_node("Style").material("frog_gold")
			t.check(gold.metallic > 0.5, "l'oro è metallo")
			# Superare un livello lo annuncia, con la pelle nuova.
			main.drought = 5
			progress.drought_best["comune"] = 4
			_den(5)
			t.check(drought.best("comune") == 5 and hud._message.text.contains("Oro"), "superata la Siccità 5: la pelle d'oro (%s)" % hud._message.text)
			# Una run di prova non apre niente.
			main.test_run = true
			main.frog_kind = "rospo"
			main.drought = 0
			_den(5)
			t.check(drought.best("rospo") == -1, "in una run di prova la Siccità non si apre")
			progress.load_from(PROGRESS)
			t.check(drought.best("comune") == 5, "si salva")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
