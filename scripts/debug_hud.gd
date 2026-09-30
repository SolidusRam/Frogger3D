extends CanvasLayer
## HUD provvisorio: mostra la vita della rana. Verrà sostituito al punto 8.

@export var frog: Frog

@onready var health_label: Label = $HealthLabel


func _ready() -> void:
	frog.health_changed.connect(_on_health_changed)
	_on_health_changed(frog.health, frog.max_health)


func _on_health_changed(health: int, max_health: int) -> void:
	health_label.text = "Vita: %d / %d" % [health, max_health]
