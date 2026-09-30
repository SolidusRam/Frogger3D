extends CanvasLayer
## HUD provvisorio: vita e stato dei poteri. Verrà sostituito al punto 8.

@export var frog: Frog

@onready var health_label: Label = $HealthLabel
@onready var powers_label: Label = $PowersLabel


func _ready() -> void:
	frog.health_changed.connect(_on_health_changed)
	_on_health_changed(frog.health, frog.max_health)


func _process(_delta: float) -> void:
	var cooldown := frog.super_jump_cooldown_left()
	var super_jump := "pronto" if cooldown == 0.0 else "%.1f s" % cooldown
	powers_label.text = "Super salto: %s\nDeltaplano: %d%%" % [super_jump, roundi(frog.glide_charge_ratio() * 100.0)]


func _on_health_changed(health: int, max_health: int) -> void:
	health_label.text = "Vita: %d / %d" % [health, max_health]
