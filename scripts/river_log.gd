class_name RiverLog
extends Floater
## Un tronco: una piattaforma sicura.


func _build() -> void:
	super()
	var bark := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = size.x / 2.0
	mesh.bottom_radius = size.x / 2.0
	mesh.height = size.z
	mesh.material = Style.material("log")
	bark.mesh = mesh
	# Il cilindro nasce verticale: lo si corica lungo Z.
	bark.rotation.x = PI / 2.0
	add_child(bark)
