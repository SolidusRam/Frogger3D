extends CanvasLayer
## HUD provvisorio: vita, stato dei poteri, distanza e tane. Verrà sostituito
## al punto 8.

@export var frog: Frog
@export var course: Course

@onready var health_label: Label = $HealthLabel
@onready var powers_label: Label = $PowersLabel
@onready var progress_label: Label = $ProgressLabel
@onready var den_label: Label = $DenLabel


func _ready() -> void:
	frog.health_changed.connect(_on_health_changed)
	_on_health_changed(frog.health, frog.max_health)
	course.den_reached.connect(_on_den_reached)
	den_label.text = ""


func _process(_delta: float) -> void:
	var cooldown := frog.super_jump_cooldown_left()
	var super_jump := "pronto" if cooldown == 0.0 else "%.1f s" % cooldown
	powers_label.text = "Super salto: %s\nDeltaplano: %d%%" % [super_jump, roundi(frog.glide_charge_ratio() * 100.0)]
	progress_label.text = "Distanza: %d m   Tane: %d" % [roundi(course.distance()), course.dens_reached]


func _on_health_changed(health: int, max_health: int) -> void:
	health_label.text = "Vita: %d / %d" % [health, max_health]


func _on_den_reached(count: int, distance: float) -> void:
	den_label.text = "Tana %d raggiunta! %d m" % [count, roundi(distance)]
	den_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(den_label, "modulate:a", 0.0, 0.5)
