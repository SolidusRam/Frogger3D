class_name Edges
extends Node3D
## I bordi visibili della zona di gioco, uno per ogni tipo di blocco, ai due
## lati (x = ±edge_x, dove stanno i muri invisibili). Il bordo taglia di
## traverso le corsie, quindi dove le corsie continuano fuori dalla zona di
## gioco è una struttura da cui entrano ed escono:
## - strada: una galleria (le auto nascono e spariscono dentro, al buio);
## - fiume: un ponte, sotto cui passano tronchi e coccodrilli;
## - ferrovia: i portali della linea elettrica, sotto cui passano i treni;
## - aeroporto: una fila di luci di bordo, basse sotto le ali;
## - porto: il molo finisce (lo fa Port); qui solo le bitte agli angoli;
## - strisce sicure, partenza e tane: una siepe.
## Solo grafica: a fermare la rana restano i muri invisibili.

## Quanto entra la galleria oltre il bordo: le auto nascono lì dentro.
const TUNNEL_DEPTH := 9.0
const TUNNEL_HEIGHT := 4.2

var kind: Course.Kind
var depth := 10.0
var edge_x := 37.5
## Per strade: corsie e loro larghezza (per i pilastri fra una corsia e l'altra).
var lanes := 0
var lane_width := 4.0


func _ready() -> void:
	for side in [-1.0, 1.0]:
		match kind:
			Course.Kind.START, Course.Kind.SAFE, Course.Kind.DEN, Course.Kind.AEROBATICS:
				_hedge(side)
			Course.Kind.ROAD:
				_tunnel(side)
			Course.Kind.RIVER:
				_bridge(side)
			Course.Kind.RAIL:
				_gantry(side)
			Course.Kind.AIRPORT:
				_edge_lights(side)
			Course.Kind.PORT:
				_bollards(side)


func _hedge(side: float) -> void:
	_box(Vector3(1.2, 1.3, depth), Vector3(side * (edge_x + 0.6), 0.65, 0.0), "tree")
	# Cespugli più alti, per rompere la linea.
	var z := -depth / 2.0 + 1.0
	while z < depth / 2.0:
		_box(Vector3(1.5, 1.8, 1.6), Vector3(side * (edge_x + 0.7), 0.9, z), "tree")
		z += 3.3


## La bocca della galleria: architrave, pilastri fra le corsie, e dentro un
## soffitto e un fondo scuri. Davanti è aperta: le auto ci entrano.
func _tunnel(side: float) -> void:
	var outer := edge_x + TUNNEL_DEPTH
	_box(Vector3(TUNNEL_DEPTH, 0.6, depth), Vector3(side * (edge_x + TUNNEL_DEPTH / 2.0), TUNNEL_HEIGHT + 0.3, 0.0), "tunnel_dark")
	_box(Vector3(0.6, TUNNEL_HEIGHT + 0.6, depth), Vector3(side * (outer + 0.3), (TUNNEL_HEIGHT + 0.6) / 2.0, 0.0), "tunnel_dark")
	# La facciata.
	_box(Vector3(1.0, 2.0, depth + 1.0), Vector3(side * (edge_x + 0.5), TUNNEL_HEIGHT + 1.0, 0.0), "concrete")
	for i in lanes + 1:
		var z := (i - lanes / 2.0) * lane_width
		_box(Vector3(1.0, TUNNEL_HEIGHT, 0.5), Vector3(side * (edge_x + 0.5), TUNNEL_HEIGHT / 2.0, z), "concrete")
	# Una fascia gialla e nera sopra l'ingresso: il bordo si legge da lontano.
	_box(Vector3(0.1, 0.4, depth + 1.0), Vector3(side * edge_x, TUNNEL_HEIGHT + 0.3, 0.0), "taxi_line")


## Un ponte di pietra sopra il fiume: tronchi e coccodrilli passano sotto.
func _bridge(side: float) -> void:
	var width := 5.0
	var x := side * (edge_x + width / 2.0)
	_box(Vector3(width, 0.7, depth + 2.0), Vector3(x, 1.9, 0.0), "stone")
	for parapet in [-1.0, 1.0]:
		_box(Vector3(0.4, 0.8, depth + 2.0), Vector3(x + parapet * (width / 2.0 - 0.2), 2.65, 0.0), "stone")
	# Le spalle del ponte, sulle due rive.
	for bank in [-1.0, 1.0]:
		_box(Vector3(width, 2.6, 1.2), Vector3(x, 0.6, bank * (depth / 2.0 + 0.4)), "stone")


## I portali della linea elettrica: due pali ai capi del blocco e una trave
## sopra i binari, sotto cui passano i treni.
func _gantry(side: float) -> void:
	var x := side * (edge_x + 0.4)
	for end in [-1.0, 1.0]:
		_box(Vector3(0.4, 7.0, 0.4), Vector3(x, 3.5, end * (depth / 2.0 - 0.3)), "metal")
	_box(Vector3(0.5, 0.5, depth), Vector3(x, 6.8, 0.0), "metal")
	_box(Vector3(0.1, 0.4, depth), Vector3(x - side * 0.3, 6.8, 0.0), "taxi_line")


## Le luci blu di bordo pista: basse, sotto i motori degli aerei.
func _edge_lights(side: float) -> void:
	var z := -depth / 2.0 + 1.0
	while z < depth / 2.0:
		_box(Vector3(0.2, 0.5, 0.2), Vector3(side * edge_x, 0.25, z), "metal")
		_box(Vector3(0.3, 0.2, 0.3), Vector3(side * edge_x, 0.6, z), "edge_light")
		z += 2.5


## Il molo finisce al bordo (lo taglia Port): due bitte sugli angoli di ogni
## banchina, dove il cemento finisce sull'acqua.
func _bollards(side: float) -> void:
	for end in [-1.0, 1.0]:
		_box(Vector3(0.6, 0.8, 0.6), Vector3(side * (edge_x - 0.8), 0.4, end * (depth / 2.0 - 1.0)), "metal")


func _box(size: Vector3, at: Vector3, palette_key: String) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = Style.material(palette_key)
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)
