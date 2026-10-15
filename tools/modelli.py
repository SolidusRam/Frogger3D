"""Rende un modello in Blender per la griglia del README (vedi tools/modelli.sh).

Uso:  blender -b assets/models/NOME.blend --python tools/modelli.py -- USCITA.png

Camera ortografica di tre quarti, sfondo trasparente con l'ombra a terra
(shadow catcher). I colori sono quelli della prima tavolozza di scripts/style.gd
(convertiti da sRGB a lineare), non quelli di anteprima del .blend; la vernice
dei veicoli si sceglie con la variabile PAINT (car_0 ... car_5).
"""

import json
import math
import os
import re
import sys

import bpy
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sc = bpy.context.scene

# La tavolozza: il primo blocco "colors" di style.gd.
style = open(os.path.join(root, "scripts", "style.gd")).read()
blk = style.split('"colors": {')[1]
pal = {k: [float(x) for x in v.split(",")[:3]]
       for k, v in re.findall(r'"([a-z_0-9]+)": Color\(([^)]*)\)', blk)}


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


for m in bpy.data.materials:
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    key = os.environ.get("PAINT", "car_1") if m.name == "paint" else m.name
    col = [lin(c) for c in pal[key]] + [1] if key in pal else list(m.diffuse_color)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.85

# Inquadratura: il davanti del modello guarda +Y, la camera sta davanti a destra.
meshes = [o for o in sc.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center = (mn + mx) / 2
size = (mx - mn).length
d = Vector((1.0, 1.25, 0.85)).normalized()
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam)
cam.location = center + d * size * 3
cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
bpy.context.view_layer.update()
inv = cam.matrix_world.inverted()
cp = [inv @ p for p in pts]
xs = [p.x for p in cp]
ys = [p.y for p in cp]
cam_data.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.45
cam_data.shift_x = (max(xs) + min(xs)) / 2 / cam_data.ortho_scale
cam_data.shift_y = (max(ys) + min(ys)) / 2 / cam_data.ortho_scale
sc.camera = cam

bpy.ops.mesh.primitive_plane_add(size=size * 20, location=(center.x, center.y, mn.z))
bpy.context.active_object.is_shadow_catcher = True

sun_data = bpy.data.lights.new("sun", "SUN")
sun_data.energy = 3.5
sun_data.angle = math.radians(8)
sun = bpy.data.objects.new("sun", sun_data)
sc.collection.objects.link(sun)
sun.rotation_euler = Vector((-0.6, 0.9, 1.6)).normalized().to_track_quat("Z", "Y").to_euler()
world = bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (1, 1, 1, 1)
bg.inputs[1].default_value = 0.9

r = sc.render
r.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 48
sc.cycles.use_denoising = True
r.film_transparent = True
r.resolution_x = r.resolution_y = 640
r.resolution_percentage = 100
sc.view_settings.view_transform = "Standard"
r.image_settings.file_format = "PNG"
r.image_settings.color_mode = "RGBA"
r.filepath = out
bpy.ops.render.render(write_still=True)
