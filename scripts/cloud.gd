class_name Cloud
extends RefCounted
## Le nuvole del cielo (vedi Worlds), costruite da codice perché hanno la
## lunghezza che serve: quelle che scorrono al posto dei tronchi e quelle di
## scena ai lati. Sbuffi sfaccettati, come i modelli, con la pancia più scura.
## Un generatore tutto loro, col seme dato: la grafica non deve cambiare la
## sequenza casuale del gioco (percorso, traffico).


## Una nuvola lunga length (lungo Z), larga width e alta height, con la cima
## piatta all'altezza height / 2: ci si sta sopra come su un tronco.
static func build(length: float, width: float, height: float, seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var root := Node3D.new()
	root.name = "Cloud"
	var count := maxi(roundi(length / 1.6), 2)
	for i in count:
		var z := -length / 2.0 + (i + 0.5) * length / count
		var r := rng.randf_range(0.85, 1.0) * width * 0.5
		root.add_child(_puff(Vector3(rng.randf_range(-0.08, 0.08) * width, 0.0, z), Vector3(r, height * 0.55, r * 1.5), "cloud"))
		# Gli sbuffi più piccoli sotto, più scuri: la pancia.
		var side := 1.0 if i % 2 == 0 else -1.0
		root.add_child(_puff(Vector3(side * width * 0.2, -height * 0.35, z), Vector3(r * 0.7, height * 0.4, r * 1.1), "cloud_shade"))
	return root


## Un ammasso di nuvole di scena, ai lati del percorso.
static func heap(size: float, seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var root := Node3D.new()
	root.name = "CloudHeap"
	for i in 5:
		var offset := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.0, 0.6), rng.randf_range(-1.0, 1.0)) * size
		var r := rng.randf_range(0.5, 1.0) * size
		root.add_child(_puff(offset, Vector3(r, r * 0.7, r), "cloud" if i < 3 else "cloud_shade"))
	return root


static func _puff(at: Vector3, radius: Vector3, palette_key: String) -> MeshInstance3D:
	var puff := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 7
	sphere.rings = 4
	sphere.material = Style.material(palette_key)
	puff.mesh = sphere
	puff.position = at
	puff.scale = radius
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return puff
