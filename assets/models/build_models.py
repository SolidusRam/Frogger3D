"""Costruisce i modelli low-poly del gioco in Blender e li esporta.

Uso:  blender -b --python assets/models/build_models.py

Per ogni modello salva il file .blend (da aprire e ritoccare a mano) e il .glb
che usa Godot. In gioco i colori vengono dalla tavolozza dello stile: conta il
NOME del materiale ("paint", "glass", "tire"...), non il colore che ha qui,
che serve solo come anteprima in Blender.

Attenzione: rilanciare lo script sovrascrive i modelli. Se ne ritocchi uno a
mano in Blender, esportalo da lì e non rilanciare lo script per quel modello
(si può scegliere quali costruire passando i nomi dopo "--").

Convenzioni: in Blender il davanti del modello guarda verso +Y e l'alto è +Z;
l'esportazione glTF li porta a -Z e +Y, cioè le convenzioni di Godot.
I veicoli hanno l'origine al centro del loro ingombro di gioco; tutto il resto
ha l'origine a terra.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

OUT = os.path.dirname(os.path.abspath(__file__))

PREVIEW = {
    "paint": (0.75, 0.15, 0.12, 1), "glass": (0.06, 0.08, 0.1, 1),
    "tire": (0.04, 0.04, 0.04, 1), "trim": (0.18, 0.18, 0.2, 1),
    "headlight": (1.0, 0.95, 0.7, 1), "taillight": (0.9, 0.08, 0.08, 1),
    "cargo": (0.75, 0.74, 0.7, 1), "metal": (0.55, 0.55, 0.6, 1),
    "wing": (0.85, 0.42, 0.1, 1), "wing_stripe": (0.95, 0.9, 0.8, 1),
    "trunk": (0.35, 0.22, 0.12, 1), "tree": (0.18, 0.4, 0.15, 1),
    "house": (0.75, 0.68, 0.55, 1), "roof": (0.55, 0.2, 0.15, 1),
    "lamp_light": (1.0, 0.9, 0.6, 1), "mountain": (0.35, 0.33, 0.32, 1),
    "mountain_snow": (0.9, 0.92, 0.95, 1),
    "loco": (0.7, 0.12, 0.1, 1), "loco_stripe": (0.95, 0.8, 0.1, 1),
    "wagon": (0.45, 0.25, 0.15, 1), "wagon_deck": (0.5, 0.38, 0.22, 1),
    "sign_white": (0.95, 0.95, 0.92, 1), "signal_off": (0.25, 0.05, 0.05, 1),
    "signal_on": (1.0, 0.1, 0.05, 1),
}


# --- Strumenti -------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = PREVIEW.get(name, (1, 0, 1, 1))
    return mat


def mesh_object(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([Vector(v) for v in verts], [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material(mat))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def block(name, bottom, top, mat):
    """Un esaedro da 4 punti in basso e 4 in alto, nello stesso giro.

    Permette scatole rastremate: cofani inclinati, abitacoli, tetti."""
    verts = list(bottom) + list(top)
    faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh_object(name, verts, faces, mat)


def box(name, x0, x1, y0, y1, z0, z1, mat):
    return block(name,
                 [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
                 [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], mat)


def mirrored_box(name, x0, x1, y0, y1, z0, z1, mat):
    """Una coppia di scatole simmetriche rispetto a X = 0 (fari, finestrini)."""
    return [box(name + "_R", x0, x1, y0, y1, z0, z1, mat),
            box(name + "_L", -x1, -x0, y0, y1, z0, z1, mat)]


def cylinder(name, radius, depth, location, mat, sides=8, axis="X"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    if axis == "X":
        obj.rotation_euler = (0, math.pi / 2, 0)
    elif axis == "Y":
        obj.rotation_euler = (math.pi / 2, 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(material(mat))
    return obj


def cone(name, radius, depth, location, mat, sides=6):
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material(mat))
    return obj


def tube(name, a, b, radius, mat):
    """Un tubo a sezione quadrata tra due punti (telaio del deltaplano)."""
    a, b = Vector(a), Vector(b)
    direction = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=radius, depth=direction.length, location=(a + b) / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    obj.data.materials.append(material(mat))
    return obj


def join(name, objects):
    """Unisce le parti in un solo oggetto, con un materiale per parte."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    joined.data.name = name
    # L'origine dell'oggetto resta al centro del modello.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return joined


def save(model_name):
    blend = os.path.join(OUT, model_name + ".blend")
    glb = os.path.join(OUT, model_name + ".glb")
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_yup=True, export_apply=True)
    print("salvato", model_name)


def wheels(radius, width, x, ys, z):
    """Ruote a 8 lati, oggetti separati chiamati Wheel_*: Godot le fa girare."""
    for i, y in enumerate(ys):
        for side, label in ((1, "R"), (-1, "L")):
            cylinder("Wheel_%d%s" % (i, label), radius, width, (side * x, y, z), "tire")


# --- Veicoli ---------------------------------------------------------------
# Ingombro di gioco (larghezza, altezza, lunghezza) e origine al suo centro.

def car_model(name, w, h, length, cabin, wheel_radius, wheel_y):
    """Utilitaria e berlina: carrozzeria con cofano inclinato, abitacolo a
    vetri rastremato, tetto verniciato, fari, paraurti."""
    hx, hz, hy = w / 2, h / 2, length / 2
    floor = -hz + 0.17
    belt = floor + 0.52
    parts = [block("body",
                   [(-hx, -hy, floor), (hx, -hy, floor), (hx, hy, floor), (-hx, hy, floor)],
                   [(-hx, -hy + 0.05, belt), (hx, -hy + 0.05, belt), (hx, hy - 0.15, belt - 0.08), (-hx, hy - 0.15, belt - 0.08)],
                   "paint")]
    back, front, back_top, front_top = cabin
    roof = hz - 0.08
    parts.append(block("cabin",
                       [(-hx + 0.08, back, belt - 0.02), (hx - 0.08, back, belt - 0.02), (hx - 0.08, front, belt - 0.04), (-hx + 0.08, front, belt - 0.04)],
                       [(-hx + 0.18, back_top, roof), (hx - 0.18, back_top, roof), (hx - 0.18, front_top, roof), (-hx + 0.18, front_top, roof)],
                       "glass"))
    parts.append(box("roof", -hx + 0.16, hx - 0.16, back_top - 0.03, front_top + 0.03, roof, hz, "paint"))
    parts += mirrored_box("headlight", hx - 0.45, hx - 0.12, hy, hy + 0.04, floor + 0.2, floor + 0.36, "headlight")
    parts += mirrored_box("taillight", hx - 0.4, hx - 0.12, -hy - 0.04, -hy, floor + 0.25, floor + 0.4, "taillight")
    parts.append(box("bumper_front", -hx + 0.05, hx - 0.05, hy, hy + 0.1, floor - 0.02, floor + 0.12, "trim"))
    parts.append(box("bumper_back", -hx + 0.05, hx - 0.05, -hy - 0.1, -hy, floor - 0.02, floor + 0.12, "trim"))
    join("Body", parts)
    wheels(wheel_radius, 0.28, hx - 0.1, wheel_y, -hz + wheel_radius)
    save(name)


def build_compact():
    reset()
    car_model("compact", 1.8, 1.35, 3.4, (-1.3, 0.75, -1.15, 0.25), 0.3, (1.05, -1.05))


def build_sedan():
    reset()
    car_model("sedan", 2.0, 1.4, 4.4, (-1.25, 0.95, -0.95, 0.45), 0.33, (1.35, -1.35))


def build_van():
    reset()
    w, h, length = 2.1, 2.0, 4.8
    hx, hz, hy = w / 2, h / 2, length / 2
    floor = -hz + 0.2
    parts = [box("body", -hx, hx, -hy, 1.3, floor, hz, "paint")]
    # Muso inclinato con il parabrezza.
    parts.append(block("nose",
                       [(-hx, 1.3, floor), (hx, 1.3, floor), (hx, hy, floor), (-hx, hy, floor)],
                       [(-hx, 1.3, hz), (hx, 1.3, hz), (hx, hy - 0.4, 0.05), (-hx, hy - 0.4, 0.05)],
                       "paint"))
    slope = Vector((0, 0.95, 0.75)).normalized() * 0.03
    parts.append(block("windshield",
                       [(-hx + 0.12, 1.36, hz - 0.08), (hx - 0.12, 1.36, hz - 0.08), (hx - 0.12, hy - 0.46, 0.13), (-hx + 0.12, hy - 0.46, 0.13)],
                       [(-hx + 0.12, 1.36 + slope.y, hz - 0.08 + slope.z), (hx - 0.12, 1.36 + slope.y, hz - 0.08 + slope.z),
                        (hx - 0.12, hy - 0.46 + slope.y, 0.13 + slope.z), (-hx + 0.12, hy - 0.46 + slope.y, 0.13 + slope.z)],
                       "glass"))
    parts += mirrored_box("side_window", hx, hx + 0.02, -hy + 0.4, 1.2, 0.3, 0.75, "glass")
    parts += mirrored_box("headlight", hx - 0.45, hx - 0.12, hy, hy + 0.04, floor + 0.25, floor + 0.42, "headlight")
    parts += mirrored_box("taillight", hx - 0.35, hx - 0.1, -hy - 0.04, -hy, floor + 0.3, floor + 0.7, "taillight")
    parts.append(box("bumper_front", -hx + 0.05, hx - 0.05, hy, hy + 0.1, floor - 0.02, floor + 0.14, "trim"))
    parts.append(box("bumper_back", -hx + 0.05, hx - 0.05, -hy - 0.1, -hy, floor - 0.02, floor + 0.14, "trim"))
    join("Body", parts)
    wheels(0.38, 0.3, hx - 0.12, (1.55, -1.55), -hz + 0.38)
    save("van")


def build_truck():
    reset()
    w, h, length = 2.4, 2.6, 8.0
    hx, hz, hy = w / 2, h / 2, length / 2
    floor = -hz + 0.35
    parts = [box("chassis", -0.9, 0.9, -hy, hy - 0.1, floor - 0.15, floor + 0.05, "trim")]
    parts.append(block("cab",
                       [(-hx, 1.6, floor), (hx, 1.6, floor), (hx, hy, floor), (-hx, hy, floor)],
                       [(-hx, 1.6, 1.0), (hx, 1.6, 1.0), (hx, hy - 0.2, 1.0), (-hx, hy - 0.2, 0.95)],
                       "paint"))
    parts.append(box("windshield", -hx + 0.15, hx - 0.15, hy - 0.02, hy + 0.02, 0.1, 0.8, "glass"))
    parts += mirrored_box("cab_window", hx, hx + 0.02, 2.6, 3.6, 0.15, 0.75, "glass")
    parts.append(box("trailer", -hx, hx, -hy, 1.4, floor + 0.05, hz, "cargo"))
    parts += mirrored_box("stripe", hx, hx + 0.02, -hy + 0.2, 1.2, 0.0, 0.35, "paint")
    parts += mirrored_box("headlight", hx - 0.5, hx - 0.15, hy, hy + 0.04, floor + 0.15, floor + 0.35, "headlight")
    parts += mirrored_box("taillight", hx - 0.4, hx - 0.1, -hy - 0.04, -hy, floor + 0.1, floor + 0.35, "taillight")
    parts.append(box("bumper_front", -hx + 0.05, hx - 0.05, hy, hy + 0.12, floor - 0.1, floor + 0.1, "trim"))
    join("Body", parts)
    wheels(0.48, 0.4, hx - 0.15, (3.0, -1.6, -3.0), -hz + 0.48)
    save("truck")


# --- Deltaplano ------------------------------------------------------------

def build_glider():
    """Ala a delta a strisce, tubi del bordo d'attacco e della chiglia,
    triangolo di controllo. Origine all'attacco della chiglia."""
    reset()
    nose = Vector((0, 1.2, 0))
    center = Vector((0, -0.45, 0.06))
    parts = []
    for side in (1, -1):
        tip = Vector((side * 1.7, -0.75, -0.12))
        # Il bordo d'uscita va dal centro alla punta: tre spicchi alternati.
        steps = [center.lerp(tip, t / 3) for t in range(4)]
        for i in range(3):
            parts.append(mesh_object("panel_%d_%d" % (side, i), [nose, steps[i], steps[i + 1]], [(0, 1, 2)],
                                     "wing" if i % 2 == 0 else "wing_stripe"))
        parts.append(tube("edge_%d" % side, nose, tip, 0.035, "metal"))
    parts.append(tube("keel", nose, center, 0.035, "metal"))
    hang = Vector((0, 0.1, 0.0))
    for side in (1, -1):
        parts.append(tube("strut_%d" % side, hang, (side * 0.5, 0.1, -0.85), 0.03, "metal"))
    parts.append(tube("bar", (-0.55, 0.1, -0.85), (0.55, 0.1, -0.85), 0.035, "metal"))
    join("Glider", parts)
    save("glider")


# --- Ferrovia ---------------------------------------------------------------
# I rotabili hanno l'origine a terra, al centro: davanti verso +Y. Larghi 3 m.

def bogies(length, radius=0.45):
    """Due carrelli con due assi ciascuno, sotto i due capi del rotabile."""
    parts = []
    for end in (1, -1):
        for axle in (0.6, -0.6):
            y = end * (length / 2 - 2.2) + axle
            for side in (1, -1):
                parts.append(cylinder("wheel", radius, 0.2, (side * 1.15, y, radius), "trim"))
        parts.append(box("bogie", -1.0, 1.0, end * (length / 2 - 2.2) - 1.1, end * (length / 2 - 2.2) + 1.1, 0.35, 0.7, "trim"))
    return parts


def build_locomotive():
    reset()
    length = 14.0
    parts = bogies(length)
    parts.append(box("frame", -1.4, 1.4, -length / 2, length / 2, 0.7, 1.05, "trim"))
    parts.append(box("hood", -1.35, 1.35, -length / 2 + 0.2, 2.8, 1.05, 3.2, "loco"))
    parts.append(box("cab", -1.5, 1.5, 2.8, 5.2, 1.05, 3.8, "loco"))
    parts.append(block("nose",
                       [(-1.4, 5.2, 1.05), (1.4, 5.2, 1.05), (1.4, length / 2, 1.05), (-1.4, length / 2, 1.05)],
                       [(-1.4, 5.2, 2.5), (1.4, 5.2, 2.5), (1.4, length / 2 - 0.4, 2.2), (-1.4, length / 2 - 0.4, 2.2)],
                       "loco"))
    parts.append(box("windshield", -1.3, 1.3, 5.2, 5.24, 2.6, 3.5, "glass"))
    parts += mirrored_box("cab_window", 1.5, 1.52, 3.2, 4.8, 2.5, 3.4, "glass")
    parts += mirrored_box("stripe", 1.35, 1.37, -length / 2 + 0.3, 2.8, 1.5, 1.8, "loco_stripe")
    parts += mirrored_box("cab_stripe", 1.5, 1.52, 2.8, 5.2, 1.5, 1.8, "loco_stripe")
    parts.append(box("nose_stripe", -1.41, 1.41, length / 2 - 0.05, length / 2, 1.3, 1.6, "loco_stripe"))
    parts += mirrored_box("headlight", 0.6, 1.0, length / 2, length / 2 + 0.05, 1.7, 2.0, "headlight")
    parts.append(box("top_light", -0.3, 0.3, 5.0, 5.24, 3.55, 3.75, "headlight"))
    parts.append(box("plough", -1.4, 1.4, length / 2, length / 2 + 0.35, 0.3, 0.75, "trim"))
    join("Locomotive", parts)
    save("locomotive")


def build_boxcar():
    reset()
    length = 12.0
    parts = bogies(length)
    parts.append(box("frame", -1.4, 1.4, -length / 2, length / 2, 0.7, 1.05, "trim"))
    parts.append(box("body", -1.5, 1.5, -length / 2 + 0.1, length / 2 - 0.1, 1.05, 3.6, "wagon"))
    parts += mirrored_box("door", 1.5, 1.53, -1.2, 1.2, 1.2, 3.3, "trim")
    parts.append(box("roof", -1.55, 1.55, -length / 2 + 0.05, length / 2 - 0.05, 3.6, 3.7, "trim"))
    join("Boxcar", parts)
    save("boxcar")


def build_flatcar():
    reset()
    length = 12.0
    parts = bogies(length)
    parts.append(box("frame", -1.4, 1.4, -length / 2, length / 2, 0.7, 1.0, "trim"))
    parts.append(box("deck", -1.5, 1.5, -length / 2 + 0.1, length / 2 - 0.1, 1.0, 1.2, "wagon_deck"))
    for y in (-4.5, -1.5, 1.5, 4.5):
        parts += mirrored_box("stake", 1.4, 1.5, y - 0.08, y + 0.08, 1.2, 1.7, "wagon")
    join("Flatcar", parts)
    save("flatcar")


def build_signal():
    """Palo del passaggio a livello: croce di Sant'Andrea e due luci rosse
    verso -Y (la direzione da cui arriva la rana). Le luci accese sono oggetti
    separati, LampOn_*: Godot le accende e le spegne."""
    reset()
    parts = [cylinder("pole", 0.08, 3.4, (0, 0, 1.7), "metal", sides=6, axis="Z")]
    for angle in (0.6, -0.6):
        board = box("board", -0.9, 0.9, -0.03, 0.03, -0.11, 0.11, "sign_white")
        board.rotation_euler = (0, angle, 0)
        board.location = (0, -0.1, 3.0)
        bpy.context.view_layer.objects.active = board
        board.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
        board.select_set(False)
        parts.append(board)
    # Schermo nero dietro le luci, per il contrasto anche in pieno giorno.
    parts.append(box("lamp_screen", -0.95, 0.95, -0.12, 0.05, 1.75, 2.45, "trim"))
    for x in (-0.5, 0.5):
        parts.append(cylinder("lamp_off", 0.28, 0.06, (x, -0.16, 2.1), "signal_off", sides=8, axis="Y"))
    join("Signal", parts)
    for x, label in ((-0.5, "L"), (0.5, "R")):
        cylinder("LampOn_" + label, 0.3, 0.08, (x, -0.18, 2.1), "signal_on", sides=8, axis="Y")
    save("signal")


# --- Scenario --------------------------------------------------------------

def build_tree():
    reset()
    parts = [cylinder("trunk", 0.25, 1.6, (0, 0, 0.8), "trunk", sides=6, axis="Z")]
    parts.append(cone("crown_low", 1.7, 2.4, (0, 0, 2.6), "tree"))
    parts.append(cone("crown_high", 1.2, 2.0, (0, 0, 3.8), "tree"))
    join("Tree", parts)
    save("tree")


def build_house():
    """Una casetta col davanti verso +Y."""
    reset()
    parts = [box("walls", -3, 3, -2.5, 2.5, 0, 3.2, "house")]
    parts.append(mesh_object("roof",
                             [(-3.3, -2.8, 3.2), (3.3, -2.8, 3.2), (3.3, 2.8, 3.2), (-3.3, 2.8, 3.2), (-3.3, 0, 5.0), (3.3, 0, 5.0)],
                             [(0, 1, 5, 4), (3, 2, 5, 4), (0, 3, 4), (1, 2, 5), (0, 1, 2, 3)], "roof"))
    parts.append(box("door", -0.5, 0.5, 2.5, 2.56, 0, 2.0, "trim"))
    parts += mirrored_box("window", 1.2, 2.3, 2.5, 2.56, 1.2, 2.3, "glass")
    join("House", parts)
    save("house")


def build_lamp():
    """Un lampione col braccio verso +X."""
    reset()
    parts = [cylinder("pole", 0.09, 5.0, (0, 0, 2.5), "metal", sides=6, axis="Z")]
    parts.append(box("arm", 0, 1.4, -0.06, 0.06, 4.85, 4.97, "metal"))
    parts.append(box("head", 1.0, 1.6, -0.22, 0.22, 4.6, 4.85, "metal"))
    parts.append(box("light", 1.05, 1.55, -0.18, 0.18, 4.55, 4.6, "lamp_light"))
    join("Lamp", parts)
    save("lamp")


def build_mountain():
    reset()
    parts = [cone("rock", 40.0, 36.0, (0, 0, 18.0), "mountain", sides=7)]
    parts.append(cone("snow", 12.5, 11.0, (0, 0, 30.5), "mountain_snow", sides=7))
    join("Mountain", parts)
    save("mountain")


BUILDERS = {
    "compact": build_compact, "sedan": build_sedan, "van": build_van, "truck": build_truck,
    "glider": build_glider, "tree": build_tree, "house": build_house, "lamp": build_lamp,
    "mountain": build_mountain, "locomotive": build_locomotive, "boxcar": build_boxcar,
    "flatcar": build_flatcar, "signal": build_signal,
}

if __name__ == "__main__":
    wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(BUILDERS)
    for model in wanted:
        BUILDERS[model]()
