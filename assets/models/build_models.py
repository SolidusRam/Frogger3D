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
from mathutils import Matrix, Vector

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
    "plane": (0.92, 0.93, 0.95, 1), "plane_wing": (0.75, 0.77, 0.8, 1),
    "plane_engine": (0.55, 0.57, 0.6, 1), "plane_tail": (0.15, 0.3, 0.7, 1),
    "crane": (0.95, 0.65, 0.1, 1), "crane_cab": (0.2, 0.45, 0.3, 1),
    "tug": (0.95, 0.75, 0.1, 1), "beacon": (1.0, 0.55, 0.05, 1), "dolly": (0.35, 0.37, 0.4, 1),
    "cardboard": (0.7, 0.52, 0.32, 1), "tape": (0.85, 0.75, 0.55, 1),
    "ship_hull": (0.55, 0.12, 0.1, 1), "ship_deck": (0.3, 0.32, 0.3, 1),
    "ship_bridge": (0.92, 0.92, 0.9, 1), "ship_stripe": (0.1, 0.12, 0.2, 1),
    "frog": (0.3, 0.75, 0.25, 1), "frog_belly": (0.85, 0.88, 0.55, 1), "frog_spot": (0.18, 0.48, 0.15, 1),
    "eye": (0.95, 0.95, 0.95, 1), "pupil": (0.05, 0.05, 0.05, 1), "glove": (0.85, 0.1, 0.1, 1),
    "water": (0.15, 0.4, 0.7, 1), "pad": (0.3, 0.7, 0.3, 1), "stone": (0.58, 0.55, 0.5, 1),
    "reed": (0.42, 0.55, 0.22, 1), "cattail": (0.42, 0.25, 0.12, 1), "flower": (0.95, 0.55, 0.7, 1),
    "water_shallow": (0.35, 0.62, 0.75, 1), "ripple": (0.85, 0.93, 0.97, 1),
    "log": (0.45, 0.3, 0.15, 1), "log_end": (0.78, 0.62, 0.4, 1),
    "leather": (0.45, 0.28, 0.15, 1), "lens": (0.3, 0.6, 0.85, 1), "scarf": (0.85, 0.15, 0.15, 1),
    "flipper": (0.98, 0.6, 0.1, 1), "eye_red": (0.9, 0.15, 0.1, 1), "wart": (0.36, 0.27, 0.15, 1),
    "hard_hat": (1.0, 0.8, 0.1, 1), "straw": (0.9, 0.78, 0.45, 1), "felt_black": (0.12, 0.11, 0.12, 1),
    "felt_blue": (0.2, 0.35, 0.8, 1), "felt_green": (0.25, 0.6, 0.3, 1), "felt_purple": (0.55, 0.3, 0.75, 1),
    "gold": (0.95, 0.75, 0.2, 1), "sign_white": (0.95, 0.95, 0.92, 1),
    "croc": (0.2, 0.4, 0.2, 1), "croc_dark": (0.16, 0.32, 0.16, 1), "croc_eye": (0.95, 0.85, 0.2, 1),
    "eagle": (0.42, 0.27, 0.14, 1), "eagle_dark": (0.22, 0.14, 0.08, 1), "eagle_head": (0.95, 0.94, 0.9, 1),
    "beak": (0.98, 0.75, 0.15, 1), "eagle_eye": (0.98, 0.8, 0.1, 1), "wicker": (0.62, 0.45, 0.22, 1),
    "stunt": (0.12, 0.3, 0.75, 1), "stunt_stripe": (0.95, 0.95, 0.95, 1), "stunt_tip": (0.85, 0.15, 0.15, 1),
    "airship": (0.78, 0.8, 0.84, 1), "cloud": (0.95, 0.96, 1.0, 1), "cloud_shade": (0.78, 0.84, 0.94, 1),
    "rainbow_0": (0.9, 0.2, 0.2, 1), "rainbow_1": (0.98, 0.55, 0.1, 1), "rainbow_2": (0.98, 0.88, 0.2, 1),
    "rainbow_3": (0.3, 0.75, 0.3, 1), "rainbow_4": (0.25, 0.5, 0.9, 1), "rainbow_5": (0.55, 0.3, 0.8, 1),
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


# --- La rana ---------------------------------------------------------------

def ico(name, radius, location, mat, scale=(1, 1, 1)):
    """Una sfera sfaccettata (20 facce), nello stile dei blocchi."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material(mat))
    return obj


def part(name, objects, pivot, parent=None):
    """Una parte mobile della rana: le forme unite in un oggetto con l'origine
    nel perno (l'articolazione), figlia della parte a cui è attaccata."""
    if len(objects) > 1:
        obj = join(name, objects)
    else:
        obj = objects[0]
        obj.name = name
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.transform(Matrix.Translation(-Vector(pivot)))
    obj.location = pivot
    if parent:
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def slope_patch(name, x0, x1, y0, y1, surface, mat):
    """Una macchia sottile appoggiata su una superficie inclinata
    (surface(y) dà la quota della superficie)."""
    return block(name,
                 [(x0, y0, surface(y0) - 0.01), (x1, y0, surface(y0) - 0.01), (x1, y1, surface(y1) - 0.01), (x0, y1, surface(y1) - 0.01)],
                 [(x0, y0, surface(y0) + 0.025), (x1, y0, surface(y0) + 0.025), (x1, y1, surface(y1) + 0.025), (x0, y1, surface(y1) + 0.025)],
                 mat)


def build_frog():
    """La rana, a pezzi rigidi come i personaggi della PS1: ogni parte ha
    l'origine nella sua articolazione e Godot la muove da codice.

    Torso (perno sui fianchi)
      Head (collo) > EyeL, EyeR (centro dell'occhio), Throat (sotto il mento)
      LegL, LegR (anca) > FootL/R (caviglia), SpringL/R (in cima alla molla)
      ArmL, ArmR (spalla): un braccio lungo ARM in avanti, che Godot punta
        verso il guantone e allunga quando il pugno scatta
    GloveL, GloveR (centro del guantone): li muove il pugno.

    Ingombro come la scatola che sostituisce: circa 0,8 x 0,65 x 1 m, più i
    guantoni ai lati. Davanti +Y, origine a terra."""
    reset()
    torso_top = lambda y: 0.44 + (y + 0.36) * 0.148
    torso = [block("back",
                   [(-0.34, -0.42, 0.14), (0.34, -0.42, 0.14), (0.3, 0.22, 0.16), (-0.3, 0.22, 0.16)],
                   [(-0.27, -0.36, torso_top(-0.36)), (0.27, -0.36, torso_top(-0.36)), (0.24, 0.18, torso_top(0.18)), (-0.24, 0.18, torso_top(0.18))],
                   "frog"),
             block("belly",
                   [(-0.24, -0.26, 0.12), (0.24, -0.26, 0.12), (0.22, 0.24, 0.15), (-0.22, 0.24, 0.15)],
                   [(-0.29, -0.3, 0.3), (0.29, -0.3, 0.3), (0.27, 0.25, 0.36), (-0.27, 0.25, 0.36)],
                   "frog_belly")]
    for i, (x0, x1, y0, y1) in enumerate([(-0.18, -0.06, -0.28, -0.16), (0.05, 0.19, -0.2, -0.06), (-0.1, 0.02, -0.02, 0.1)]):
        torso.append(slope_patch("spot_%d" % i, x0, x1, y0, y1, torso_top, "frog_spot"))
    torso_obj = part("Torso", torso, (0, -0.3, 0.15))

    # La testa: larga e piatta, il muso che scende in avanti, la bocca come
    # una riga scura; gli occhi sporgono sopra, su due rilievi.
    head = [block("skull",
                  [(-0.33, 0.06, 0.3), (0.33, 0.06, 0.3), (0.29, 0.58, 0.3), (-0.29, 0.58, 0.3)],
                  [(-0.27, 0.08, 0.6), (0.27, 0.08, 0.6), (0.19, 0.5, 0.52), (-0.19, 0.5, 0.52)],
                  "frog"),
            # La bocca: una riga sul muso che piega in su agli angoli.
            box("mouth", -0.2, 0.2, 0.53, 0.572, 0.36, 0.38, "pupil")]
    for side in (1, -1):
        head.append(block("mouth_corner_%d" % side,
                          [(side * 0.2, 0.5, 0.36), (side * 0.29, 0.44, 0.38), (side * 0.29, 0.49, 0.38), (side * 0.2, 0.57, 0.36)],
                          [(side * 0.2, 0.5, 0.38), (side * 0.29, 0.44, 0.405), (side * 0.29, 0.49, 0.405), (side * 0.2, 0.57, 0.38)],
                          "pupil"))
    for side in (1, -1):
        head.append(block("socket_%d" % side,
                          [(side * 0.06, 0.2, 0.5), (side * 0.3, 0.2, 0.5), (side * 0.3, 0.44, 0.5), (side * 0.06, 0.44, 0.5)],
                          [(side * 0.09, 0.23, 0.63), (side * 0.27, 0.23, 0.63), (side * 0.27, 0.41, 0.63), (side * 0.09, 0.41, 0.63)],
                          "frog"))
        head.append(box("nostril_%d" % side, side * 0.06 - 0.025, side * 0.06 + 0.025, 0.49, 0.53, 0.505, 0.53, "pupil"))
    head_obj = part("Head", head, (0, 0.15, 0.44), torso_obj)
    for side, label in ((1, "R"), (-1, "L")):
        center = (side * 0.18, 0.32, 0.66)
        eye = [ico("ball", 0.13, center, "eye"),
               box("pupil", center[0] - 0.05, center[0] + 0.05, center[1] + 0.09, center[1] + 0.135, center[2] - 0.035, center[2] + 0.055, "pupil")]
        part("Eye" + label, eye, center, head_obj)
    part("Throat", [block("throat",
                          [(-0.2, 0.16, 0.22), (0.2, 0.16, 0.22), (0.17, 0.5, 0.26), (-0.17, 0.5, 0.26)],
                          [(-0.25, 0.12, 0.33), (0.25, 0.12, 0.33), (0.24, 0.53, 0.33), (-0.24, 0.53, 0.33)],
                          "frog_belly")], (0, 0.33, 0.33), head_obj)

    # Le zampe dietro: la coscia ripiegata lungo il fianco, il piede palmato
    # che punta in avanti e in fuori, la molla sotto il tallone.
    for side, label in ((1, "R"), (-1, "L")):
        sx = lambda x: side * x
        def quad(points, z):
            return [(sx(x), y, z) for x, y in points]
        leg = part("Leg" + label, [block("haunch",
                                         quad([(0.22, -0.5), (0.47, -0.5), (0.5, 0.06), (0.26, 0.06)], 0.05),
                                         quad([(0.24, -0.43), (0.41, -0.43), (0.44, -0.04), (0.28, -0.04)], 0.32),
                                         "frog")], (sx(0.29), -0.3, 0.2), torso_obj)
        part("Foot" + label, [block("foot",
                                    quad([(0.32, -0.04), (0.5, -0.04), (0.64, 0.32), (0.3, 0.32)], 0.0),
                                    quad([(0.34, -0.02), (0.48, -0.02), (0.6, 0.3), (0.32, 0.3)], 0.06),
                                    "frog")], (sx(0.41), 0.0, 0.04), leg)
        coil = [cylinder("plate_top", 0.11, 0.03, (sx(0.33), -0.5, 0.15), "metal", sides=6, axis="Z"),
                cylinder("plate_bottom", 0.11, 0.03, (sx(0.33), -0.5, 0.0), "metal", sides=6, axis="Z")]
        for i, z in enumerate((0.05, 0.1)):
            ring = cylinder("ring_%d" % i, 0.09, 0.025, (sx(0.33), -0.5, z), "metal", sides=6, axis="Z")
            ring.rotation_euler = (0, 0, math.pi / 6 * (i + 1))
            coil.append(ring)
        part("Spring" + label, coil, (sx(0.33), -0.5, 0.16), leg)

    # Le braccia e i guantoni da boxe, in guardia ai lati.
    for side, label in ((1, "R"), (-1, "L")):
        shoulder = Vector((side * 0.25, 0.12, 0.34))
        glove = Vector((side * 0.55, 0.3, 0.38))
        length = (glove - shoulder).length
        verts = [(-0.07, 0, -0.07), (0.07, 0, -0.07), (0.07, 0, 0.07), (-0.07, 0, 0.07),
                 (-0.055, length, -0.055), (0.055, length, -0.055), (0.055, length, 0.055), (-0.055, length, 0.055)]
        faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        arm = mesh_object("Arm" + label, verts, faces, "frog")
        arm.location = shoulder
        arm.rotation_mode = "QUATERNION"
        arm.rotation_quaternion = (glove - shoulder).to_track_quat("Y", "Z")
        arm.parent = torso_obj
        arm.matrix_parent_inverse = torso_obj.matrix_world.inverted()
        fist = [ico("fist", 0.25, glove, "glove", scale=(0.95, 1.12, 0.92)),
                ico("thumb", 0.1, glove + Vector((-side * 0.17, 0.1, 0.1)), "glove"),
                cylinder("cuff", 0.15, 0.12, glove + Vector((0, -0.24, 0)), "sign_white", sides=8, axis="Y")]
        part("Glove" + label, fist, tuple(glove))
    save("frog")


# --- Gli accessori delle rane ------------------------------------------------

# I perni delle parti della rana (vedi build_frog): un accessorio ha l'origine
# nel perno della parte a cui si aggancia, e si chiama "Parte__nome"; in gioco
# Frog.set_look lo appende a quella parte, così segue le animazioni.
PIVOTS = {
    "Torso": (0, -0.3, 0.15), "Head": (0, 0.15, 0.44),
    "EyeL": (-0.18, 0.32, 0.66), "EyeR": (0.18, 0.32, 0.66),
    "FootL": (-0.41, 0.0, 0.04), "FootR": (0.41, 0.0, 0.04),
}


def attach(target, name, objects):
    """Un accessorio: le forme unite, con l'origine nel perno di target."""
    return part(target + "__" + name, objects, PIVOTS[target])


def torso_top(y):
    return 0.44 + (y + 0.36) * 0.148


def build_frog_raganella():
    """La raganella: ventose tonde sulle punte delle dita (gli occhi rossi e il
    corpo più snello li dà il gioco)."""
    reset()
    for side, label in ((1, "R"), (-1, "L")):
        pads = [ico("pad_%d" % i, 0.06, (side * x, y, 0.045), "frog_belly", scale=(1, 1, 0.7))
                for i, (x, y) in enumerate([(0.32, 0.33), (0.47, 0.35), (0.62, 0.33)])]
        attach("Foot" + label, "pads", pads)
    save("frog_raganella")


def build_frog_paracadutista():
    """La paracadutista: cuffia di cuoio con i paraorecchie, gli occhialoni
    tirati sulla fronte e una sciarpa rossa che svolazza dietro."""
    reset()
    cap = [ico("cap", 0.36, (0, 0.14, 0.6), "leather", scale=(1.0, 0.95, 0.55))]
    for side in (1, -1):
        cap.append(box("flap_%d" % side, side * 0.29, side * 0.36, 0.02, 0.28, 0.36, 0.6, "leather"))
    attach("Head", "cap", cap)
    # Gli occhialoni sulla cuffia, sopra e dietro gli occhi.
    goggles = [box("strap", -0.34, 0.34, 0.0, 0.05, 0.7, 0.76, "tire")]
    for side in (1, -1):
        goggles.append(cylinder("rim_%d" % side, 0.1, 0.06, (side * 0.13, 0.06, 0.78), "metal", sides=8, axis="Y"))
        goggles.append(cylinder("lens_%d" % side, 0.075, 0.07, (side * 0.13, 0.07, 0.78), "lens", sides=8, axis="Y"))
    attach("Head", "goggles", goggles)
    scarf = [box("knot", -0.28, 0.28, 0.12, 0.24, 0.36, 0.46, "scarf"),
             block("tail",
                   [(0.12, 0.12, 0.44), (0.22, 0.12, 0.44), (0.3, -0.42, 0.5), (0.2, -0.42, 0.5)],
                   [(0.12, 0.12, 0.47), (0.22, 0.12, 0.47), (0.3, -0.42, 0.53), (0.2, -0.42, 0.53)],
                   "scarf")]
    attach("Torso", "scarf", scarf)
    save("frog_paracadutista")


def build_frog_fiume():
    """La rana di fiume: maschera da sub sugli occhi, boccaglio arancione e
    pinne ai piedi."""
    reset()
    # La cornice è un bordo vuoto: dietro il vetro si vedono gli occhi.
    mask = [box("frame_top", -0.32, 0.32, 0.42, 0.47, 0.77, 0.8, "tire"),
            box("frame_bottom", -0.32, 0.32, 0.42, 0.47, 0.55, 0.58, "tire"),
            box("frame_left", -0.32, -0.29, 0.42, 0.47, 0.55, 0.8, "tire"),
            box("frame_right", 0.29, 0.32, 0.42, 0.47, 0.55, 0.8, "tire"),
            box("frame_nose", -0.03, 0.03, 0.42, 0.47, 0.55, 0.62, "tire"),
            box("glass", -0.29, 0.29, 0.455, 0.465, 0.58, 0.77, "lens"),
            box("strap", -0.33, 0.33, 0.0, 0.42, 0.66, 0.7, "tire")]
    attach("Head", "mask", mask)
    snorkel = [tube("pipe", (0.3, 0.46, 0.45), (0.33, 0.3, 0.95), 0.035, "flipper"),
               box("bite", 0.18, 0.31, 0.5, 0.56, 0.42, 0.48, "tire")]
    attach("Head", "snorkel", snorkel)
    for side, label in ((1, "R"), (-1, "L")):
        fin = block("fin",
                    [(side * 0.3, 0.28, 0.0), (side * 0.62, 0.28, 0.0), (side * 0.78, 0.7, 0.0), (side * 0.26, 0.7, 0.0)],
                    [(side * 0.3, 0.28, 0.035), (side * 0.62, 0.28, 0.035), (side * 0.78, 0.7, 0.035), (side * 0.26, 0.7, 0.035)],
                    "flipper")
        attach("Foot" + label, "fin", [fin])
    save("frog_fiume")


def build_frog_camaleonte():
    """Il camaleonte: una cresta sulla testa, la coda arrotolata dietro e gli
    occhi a torretta (la pelle che li avvolge da dietro)."""
    reset()
    crest = [cone("spike_%d" % i, 0.06, 0.16 - 0.02 * i, (0, 0.04 + 0.11 * i, 0.64 - 0.025 * i), "frog_spot", sides=4)
             for i in range(4)]
    attach("Head", "crest", crest)
    tail = []
    for i in range(9):
        t = i / 8.0
        angle = t * math.pi * 1.6
        radius = 0.22 * (1.0 - 0.6 * t)
        y = -0.42 - 0.18 - radius * math.sin(angle)
        z = 0.54 - radius * math.cos(angle)
        tail.append(ico("seg_%d" % i, 0.075 * (1.0 - 0.55 * t), (0, y, z), "frog"))
    attach("Torso", "tail", tail)
    for side, label in ((1, "R"), (-1, "L")):
        # La torretta avvolge l'occhio e lascia scoperta solo la pupilla.
        attach("Eye" + label, "turret", [ico("turret", 0.155, (side * 0.18, 0.3, 0.66), "frog", scale=(1.05, 0.85, 1.05))])
    save("frog_camaleonte")


def build_frog_rospo():
    """Il rospo: le verruche sulla schiena e le ghiandole gonfie dietro gli
    occhi (il corpo più tozzo lo dà il gioco)."""
    reset()
    warts = []
    for i, (x, y) in enumerate([(-0.18, -0.3), (0.12, -0.32), (0.0, -0.18), (-0.15, -0.05), (0.18, -0.08), (0.05, 0.05), (-0.05, -0.33), (0.22, -0.22)]):
        warts.append(ico("wart_%d" % i, 0.045 + 0.012 * (i % 3), (x, y, torso_top(y) + 0.015), "wart", scale=(1, 1, 0.6)))
    attach("Torso", "warts", warts)
    glands = [ico("gland_%d" % side, 0.09, (side * 0.25, 0.14, 0.55), "wart", scale=(0.9, 1.5, 0.6)) for side in (1, -1)]
    attach("Head", "glands", glands)
    save("frog_rospo")


# --- I cappelli del guardaroba (scripts/cosmetics.gd) ----------------------

def build_hat_hard_hat():
    """L'elmetto da cantiere: la calotta gialla con la costola, la tesa
    davanti. Si appende alla testa, dietro gli occhi."""
    reset()
    hat = [ico("dome", 0.3, (0, 0.06, 0.66), "hard_hat", scale=(1.05, 1.1, 0.6)),
           box("ridge", -0.035, 0.035, -0.26, 0.36, 0.74, 0.86, "hard_hat"),
           block("brim",
                 [(-0.3, 0.2, 0.62), (0.3, 0.2, 0.62), (0.26, 0.42, 0.6), (-0.26, 0.42, 0.6)],
                 [(-0.3, 0.2, 0.65), (0.3, 0.2, 0.65), (0.26, 0.42, 0.63), (-0.26, 0.42, 0.63)],
                 "hard_hat")]
    attach("Head", "hat", hat)
    save("hat_hard_hat")


def build_hat_goggles():
    """Gli occhiali da pilota, tirati sulla fronte con l'elastico."""
    reset()
    goggles = [box("strap", -0.33, 0.33, 0.0, 0.05, 0.68, 0.74, "tire")]
    for side in (1, -1):
        goggles.append(cylinder("rim_%d" % side, 0.1, 0.06, (side * 0.13, 0.06, 0.76), "metal", sides=8, axis="Y"))
        goggles.append(cylinder("lens_%d" % side, 0.075, 0.07, (side * 0.13, 0.07, 0.76), "lens", sides=8, axis="Y"))
    attach("Head", "hat", goggles)
    save("hat_goggles")


# I cappelli del mercatino e delle uova (scripts/cosmetics.gd). Tutti appesi
# alla testa, dietro gli occhi (la calotta della testa sta attorno a
# (0, 0.06, 0.6)). Mai il materiale "glove": cambia con le carte dei guantoni.
HAT_CENTER = (0, 0.06)


def hat_cylinder(name, radius, depth, z, mat, sides=8):
    return cylinder(name, radius, depth, (HAT_CENTER[0], HAT_CENTER[1], z), mat, sides=sides, axis="Z")


def build_hat_straw():
    """Il cappello di paglia, con la fascia rossa."""
    reset()
    attach("Head", "hat", [hat_cylinder("brim", 0.42, 0.03, 0.64, "straw", sides=10),
                           hat_cylinder("crown", 0.2, 0.16, 0.73, "straw"),
                           hat_cylinder("band", 0.205, 0.045, 0.68, "scarf")])
    save("hat_straw")


def build_hat_cap():
    """Il berretto da baseball, con la visiera sopra gli occhi."""
    reset()
    attach("Head", "hat", [ico("dome", 0.25, (0, 0.04, 0.66), "felt_blue", scale=(1, 1.05, 0.62)),
                           box("visor", -0.17, 0.17, 0.2, 0.44, 0.66, 0.69, "felt_blue"),
                           ico("button", 0.035, (0, 0.04, 0.82), "sign_white")])
    save("hat_cap")


def build_hat_top_hat():
    """Il cilindro, alto e nero, con la fascia rossa."""
    reset()
    attach("Head", "hat", [hat_cylinder("brim", 0.3, 0.03, 0.66, "felt_black", sides=10),
                           hat_cylinder("pipe", 0.19, 0.38, 0.86, "felt_black"),
                           hat_cylinder("band", 0.195, 0.055, 0.71, "scarf")])
    save("hat_top_hat")


def build_hat_crown():
    """La corona d'oro, con le punte e una gemma davanti."""
    reset()
    parts = [hat_cylinder("ring", 0.21, 0.11, 0.71, "gold")]
    for i in range(5):
        angle = i * 2 * math.pi / 5 + math.pi / 2
        parts.append(cone("spike_%d" % i, 0.05, 0.13, (HAT_CENTER[0] + 0.18 * math.cos(angle), HAT_CENTER[1] + 0.18 * math.sin(angle), 0.82), "gold", sides=4))
    parts.append(ico("gem", 0.045, (0, HAT_CENTER[1] + 0.21, 0.71), "scarf"))
    attach("Head", "hat", parts)
    save("hat_crown")


def build_hat_cowboy():
    """Il cappello da cowboy: tesa larga, calotta col solco, fascia scura."""
    reset()
    crown = block("crown",
                  [(-0.19, -0.12, 0.66), (0.19, -0.12, 0.66), (0.19, 0.24, 0.66), (-0.19, 0.24, 0.66)],
                  [(-0.14, -0.08, 0.86), (0.14, -0.08, 0.86), (0.14, 0.2, 0.84), (-0.14, 0.2, 0.84)],
                  "leather")
    attach("Head", "hat", [hat_cylinder("brim", 0.46, 0.03, 0.65, "leather", sides=10), crown,
                           hat_cylinder("band", 0.2, 0.04, 0.69, "tire")])
    save("hat_cowboy")


def build_hat_beanie():
    """La berretta di lana col risvolto e il pompon."""
    reset()
    attach("Head", "hat", [ico("dome", 0.26, (0, 0.05, 0.66), "felt_green", scale=(1, 1, 0.78)),
                           hat_cylinder("cuff", 0.255, 0.08, 0.63, "sign_white"),
                           ico("pompon", 0.085, (0, 0.05, 0.88), "sign_white")])
    save("hat_beanie")


def build_hat_chef():
    """Il cappello da cuoco: la fascia e lo sbuffo bianco."""
    reset()
    parts = [hat_cylinder("band", 0.2, 0.12, 0.69, "sign_white")]
    for i, (x, y) in enumerate([(-0.08, 0.02), (0.08, 0.02), (0.0, 0.14), (0.0, -0.08)]):
        parts.append(ico("puff_%d" % i, 0.15, (x, HAT_CENTER[1] + y, 0.84), "sign_white"))
    attach("Head", "hat", parts)
    save("hat_chef")


def build_hat_pirate():
    """Il tricorno del pirata, con un teschio bianco davanti."""
    reset()
    cy = HAT_CENTER[1]
    brim = prism("brim", [(0, cy + 0.42), (-0.38, cy - 0.22), (0.38, cy - 0.22)], 0.62, 0.72, "felt_black")
    attach("Head", "hat", [brim, ico("dome", 0.2, (0, cy, 0.74), "felt_black", scale=(1, 1, 0.65)),
                           box("skull", -0.04, 0.04, cy + 0.3, cy + 0.34, 0.67, 0.71, "sign_white")])
    save("hat_pirate")


def build_hat_fez():
    """Il fez rosso con la nappa d'oro."""
    reset()
    attach("Head", "hat", [cylinder("fez", 0.15, 0.2, (0, HAT_CENTER[1], 0.76), "scarf", sides=8, axis="Z"),
                           tube("cord", (0, HAT_CENTER[1], 0.86), (0.15, HAT_CENTER[1] - 0.04, 0.74), 0.015, "gold"),
                           ico("tassel", 0.035, (0.15, HAT_CENTER[1] - 0.04, 0.72), "gold")])
    save("hat_fez")


def build_hat_propeller():
    """Il berretto con l'elica in cima."""
    reset()
    cy = HAT_CENTER[1]
    attach("Head", "hat", [ico("dome", 0.25, (0, cy, 0.66), "felt_purple", scale=(1, 1, 0.7)),
                           cylinder("stem", 0.02, 0.1, (0, cy, 0.86), "metal", sides=6, axis="Z"),
                           box("blade_a", -0.22, 0.22, cy - 0.035, cy + 0.035, 0.9, 0.92, "scarf"),
                           box("blade_b", -0.035, 0.035, cy - 0.22, cy + 0.22, 0.9, 0.92, "felt_blue")])
    save("hat_propeller")


# --- La tana ----------------------------------------------------------------

def prism(name, points, z0, z1, mat):
    """Un prisma: un poligono a terra (punti in senso antiorario, visto
    dall'alto) alzato fra z0 e z1. Laghetti, ninfee, pietre piatte."""
    n = len(points)
    verts = [(x, y, z0) for x, y in points] + [(x, y, z1) for x, y in points]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh_object(name, verts, faces, mat)


def ring(name, cx, cy, r_in, r_out, sides, z0, z1, mat):
    """Un anello piatto a facce (le increspature dell'acqua)."""
    verts = []
    for z in (z0, z1):
        for r in (r_out, r_in):
            for i in range(sides):
                a = math.tau * i / sides
                verts.append((cx + math.cos(a) * r, cy + math.sin(a) * r, z))
    n = sides
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((2 * n + i, 2 * n + j, 3 * n + j, 3 * n + i))  # sopra
        faces.append((i, n + i, n + j, j))                          # sotto
        faces.append((i, j, 2 * n + j, 2 * n + i))                  # fuori
        faces.append((n + i, 3 * n + i, 3 * n + j, n + j))          # dentro
    return mesh_object(name, verts, faces, mat)


def wobbly_ring(cx, cy, rx, ry, sides, wobble, seed):
    """I punti di un contorno irregolare, sempre uguale per lo stesso seed."""
    points = []
    for i in range(sides):
        a = math.tau * i / sides
        k = 1.0 + wobble * math.sin(seed * 12.9898 + i * 78.233) * 0.5
        points.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
    return points


def lily_pad(name, cx, cy, radius, turn):
    """Una ninfea: un disco a sette lati col taglio a spicchio."""
    notch = 0.35
    points = [(cx, cy)]
    for i in range(8):
        a = turn + notch + (math.tau - 2 * notch) * i / 7
        points.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius))
    return prism(name, points, 0.04, 0.08, "pad")


def reed(name, x, y, height, lean, head=False):
    """Una canna: un fusto rastremato e piegato; le tife hanno il pennacchio."""
    top = (x + lean[0], y + lean[1], height)
    parts = [block(name,
                   [(x - 0.05, y - 0.05, 0), (x + 0.05, y - 0.05, 0), (x + 0.05, y + 0.05, 0), (x - 0.05, y + 0.05, 0)],
                   [(top[0] - 0.02, top[1] - 0.02, height), (top[0] + 0.02, top[1] - 0.02, height),
                    (top[0] + 0.02, top[1] + 0.02, height), (top[0] - 0.02, top[1] + 0.02, height)],
                   "reed")]
    if head:
        f = 0.75
        base = (x + lean[0] * f, y + lean[1] * f, height * f)
        parts.append(tube(name + "_head", base, (x + lean[0] * 0.95, y + lean[1] * 0.95, height * 0.95), 0.07, "cattail"))
    return parts


def build_den():
    """La tana: una striscia di prato larga quanto la zona di gioco (74 x
    12 m), con un laghetto per lato (ninfee, fiori, sassi, canne), le pietre
    del passaggio al centro e, sopra il passaggio, due grandi tife che si
    piegano e si incrociano: l'arco che si vede arrivare da lontano.
    Origine al centro della striscia, a terra. Solo forme: niente collisioni."""
    reset()
    parts = []
    flowers = []
    for side in (1, -1):
        cx = side * 21.0
        # L'acqua bassa chiara sul bordo, quella profonda più scura al centro.
        parts.append(prism("pond_%d" % side, wobbly_ring(cx, 0.2, 8.5, 3.9, 11, 0.35, side), 0.0, 0.03, "water_shallow"))
        parts.append(prism("deep_%d" % side, wobbly_ring(cx + side * 0.4, 0.1, 6.2, 2.5, 9, 0.3, side + 2), 0.0, 0.035, "water"))
        # I sassi sul bordo, un po' fuori dall'acqua.
        for i, (px, py) in enumerate(wobbly_ring(cx, 0.2, 9.6, 4.8, 9, 0.3, side + 5)):
            parts.append(ico("stone_%d_%d" % (side, i), 0.35 + 0.2 * ((i * 7) % 3) / 2, (px, py, 0.05), "stone", scale=(1.2, 1.0, 0.55)))
        pads = [(-5.5, -1.5, 1.1), (-2.0, 1.8, 0.9), (1.5, -0.8, 1.2), (4.8, 1.5, 0.8), (6.2, -1.9, 0.7), (-6.4, 1.6, 0.6)]
        for i, (dx, dy, r) in enumerate(pads):
            parts.append(lily_pad("pad_%d_%d" % (side, i), cx + side * dx, dy, r, i * 1.7))
            if i % 2 == 0:
                # I fiori sono oggetti a sé (Flower_*), col perno alla base: in
                # gioco restano boccioli finché la rana non arriva.
                fx, fy = cx + side * dx + 0.2 * r, dy + 0.15 * r
                flowers.append(part("Flower_%d_%d" % (side, i),
                                    [ico("petals", 0.18, (fx, fy, 0.16), "flower", scale=(1, 1, 0.8)),
                                     ico("heart", 0.07, (fx, fy, 0.28), "lamp_light")], (fx, fy, 0.08)))
        # Le canne, a ciuffi sul bordo verso l'esterno.
        for c, (dx, dy) in enumerate([(8.5, 2.5), (9.5, -2.0), (-7.8, 3.3), (2.0, 4.6), (-3.0, -4.5)]):
            for k in range(5):
                h = 1.2 + 0.25 * ((k * 5 + c) % 4)
                lean = (side * 0.15 * (k - 2), 0.1 * ((k + c) % 3 - 1))
                parts += reed("reed_%d_%d_%d" % (side, c, k), cx + side * dx + 0.18 * (k - 2), dy + 0.12 * ((k * 3) % 5 - 2), h, lean, head=(k % 2 == 1))

    # Le increspature attorno ad alcune ninfee: oggetti a sé, Godot le fa
    # allargare piano (Ripple_*).
    ripples = []
    for side in (1, -1):
        for k, (dx, dy, r) in enumerate([(-2.0, 1.8, 0.9), (1.5, -0.8, 1.2)]):
            cx, cy = side * 21.0 + side * dx, dy
            for n, extra in enumerate((0.3, 0.6)):
                ripple = ring("Ripple_%d_%d_%d" % (side, k, n), 0, 0, r + extra, r + extra + 0.07, 10, 0.04, 0.045, "ripple")
                ripple.location = (cx, cy, 0)
                ripples.append(ripple)

    # Il passaggio: pietre piatte al centro.
    for i, y in enumerate((-4.6, -2.2, 0.2, 2.6, 4.9)):
        x = 0.6 * math.sin(i * 1.9)
        parts.append(prism("step_%d" % i, wobbly_ring(x, y, 0.9, 0.7, 7, 0.25, i), 0.0, 0.07, "stone"))

    # L'arco: due grandi tife che partono ai lati del passaggio, si piegano e si
    # incrociano in alto; i pennacchi scendono oltre il centro.
    for side in (1, -1):
        points = []
        for i in range(7):
            t = i / 6
            points.append(Vector((side * (6.5 - 7.6 * t * t), 0.0, 7.2 * math.sin(t * math.pi * 0.55))))
        for i in range(6):
            parts.append(tube("arch_%d_%d" % (side, i), points[i], points[i + 1], 0.24 - 0.02 * i, "reed"))
        tip = points[-1]
        direction = (points[-1] - points[-2]).normalized()
        parts.append(tube("arch_head_%d" % side, tip - direction * 0.2, tip + direction * 1.8, 0.45, "cattail"))
        parts.append(tube("arch_spike_%d" % side, tip + direction * 1.8, tip + direction * 2.5, 0.06, "reed"))
        # Le foglie alla base: lame lunghe e strette.
        for k, (dx, h, lean) in enumerate([(-0.5, 3.2, -0.8), (0.4, 2.6, 0.7), (0.0, 3.8, 0.3)]):
            base = side * 6.5 + dx
            tip_x, tip_y = base + side * lean, 0.1 * k
            parts.append(block("leaf_%d_%d" % (side, k),
                               [(base - 0.18, -0.04, 0.0), (base + 0.18, -0.04, 0.0), (base + 0.18, 0.04, 0.0), (base - 0.18, 0.04, 0.0)],
                               [(tip_x - 0.02, tip_y - 0.01, h), (tip_x + 0.02, tip_y - 0.01, h), (tip_x + 0.02, tip_y + 0.01, h), (tip_x - 0.02, tip_y + 0.01, h)],
                               "reed"))
        parts.append(ico("arch_foot_%d" % side, 0.9, (side * 6.5, 0.0, 0.1), "stone", scale=(1.3, 1.1, 0.5)))
    join("Den", parts)
    save("den")


def build_den_sky():
    """La tana del cielo: la stessa striscia (74 x 12 m), con una pozza di
    pioggia per lato sopra le nuvole, ciuffi di nuvola al posto di sassi,
    ninfee e canne, e l'arcobaleno al posto delle tife. Fiori (Flower_*) e
    increspature (Ripple_*) come nella tana della terra: Godot li anima allo
    stesso modo."""
    reset()
    parts = []
    for side in (1, -1):
        cx = side * 21.0
        parts.append(prism("pond_%d" % side, wobbly_ring(cx, 0.2, 8.5, 3.9, 11, 0.35, side), 0.0, 0.03, "water_shallow"))
        parts.append(prism("deep_%d" % side, wobbly_ring(cx + side * 0.4, 0.1, 6.2, 2.5, 9, 0.3, side + 2), 0.0, 0.035, "water"))
        for i, (px, py) in enumerate(wobbly_ring(cx, 0.2, 9.6, 4.8, 9, 0.3, side + 5)):
            parts.append(ico("tuft_%d_%d" % (side, i), 0.55 + 0.25 * ((i * 7) % 3) / 2, (px, py, 0.1), "cloud", scale=(1.4, 1.2, 0.6)))
        pads = [(-5.5, -1.5, 1.1), (-2.0, 1.8, 0.9), (1.5, -0.8, 1.2), (4.8, 1.5, 0.8), (6.2, -1.9, 0.7), (-6.4, 1.6, 0.6)]
        for i, (dx, dy, r) in enumerate(pads):
            parts.append(ico("puff_%d_%d" % (side, i), r * 0.7, (cx + side * dx, dy, 0.05), "cloud", scale=(1.0, 1.0, 0.3)))
            if i % 2 == 0:
                fx, fy = cx + side * dx + 0.2 * r, dy + 0.15 * r
                part("Flower_%d_%d" % (side, i),
                     [ico("petals", 0.18, (fx, fy, 0.2), "flower", scale=(1, 1, 0.8)),
                      ico("heart", 0.07, (fx, fy, 0.32), "lamp_light")], (fx, fy, 0.12))
    for side in (1, -1):
        for k, (dx, dy, r) in enumerate([(-2.0, 1.8, 0.9), (1.5, -0.8, 1.2)]):
            cx, cy = side * 21.0 + side * dx, dy
            for n, extra in enumerate((0.3, 0.6)):
                ripple = ring("Ripple_%d_%d_%d" % (side, k, n), 0, 0, r + extra, r + extra + 0.07, 10, 0.04, 0.045, "ripple")
                ripple.location = (cx, cy, 0)
    # Il passaggio: sbuffi di nuvola piatti al centro.
    for i, y in enumerate((-4.6, -2.2, 0.2, 2.6, 4.9)):
        x = 0.6 * math.sin(i * 1.9)
        parts.append(prism("step_%d" % i, wobbly_ring(x, y, 0.9, 0.7, 7, 0.25, i), 0.0, 0.07, "cloud_shade"))
    # L'arcobaleno: sei fasce a semicerchio sopra il passaggio, coi piedi
    # nelle nuvole.
    for band in range(6):
        radius = 7.2 - band * 0.36
        points = [Vector((radius * math.cos(math.pi * i / 14), 0.0, radius * math.sin(math.pi * i / 14))) for i in range(15)]
        for i in range(14):
            parts.append(tube("band_%d_%d" % (band, i), points[i], points[i + 1], 0.19, "rainbow_%d" % band))
    for side in (1, -1):
        parts.append(ico("foot_%d" % side, 1.4, (side * 6.3, 0.0, 0.2), "cloud", scale=(1.4, 1.2, 0.7)))
        parts.append(ico("foot_b_%d" % side, 1.0, (side * 7.4, 0.6, 0.4), "cloud", scale=(1.2, 1.0, 0.7)))
    join("Den", parts)
    save("den_sky")


# --- Il fiume ---------------------------------------------------------------

def build_log():
    """Il tronco, lungo 1 m: Godot allunga la corteccia (Bark) fino alla
    lunghezza del tronco e mette le teste (EndA, EndB) e il moncone (Stub) al
    loro posto. Sette facce, una piatta in cima: ci si sta in piedi. Raggio
    0,8, origine al centro."""
    reset()
    bark = cylinder("Bark", 0.78, 1.0, (0, 0, 0), "log", sides=7, axis="Y")
    # Una faccia piatta in cima.
    bark.rotation_euler = (0, math.pi / 7 + math.pi / 2, 0)
    part("Bark", [bark], (0, 0, 0))
    for label, y in (("A", 0.5), ("B", -0.5)):
        sign = 1 if y > 0 else -1
        end = [cylinder("rim", 0.8, 0.06, (0, y, 0), "log", sides=7, axis="Y"),
               cylinder("wood", 0.58, 0.07, (0, y, 0), "log_end", sides=7, axis="Y"),
               cylinder("ring", 0.36, 0.08, (0, y, 0), "log", sides=7, axis="Y"),
               cylinder("core", 0.22, 0.09, (0, y, 0), "log_end", sides=7, axis="Y")]
        for obj in end:
            obj.rotation_euler = (0, math.pi / 7 + math.pi / 2, 0)
        part("End" + label, end, (0, y, 0))
    stub = [tube("branch", (0.45, 0, 0.45), (0.95, 0.15, 0.85), 0.13, "log"),
            cylinder("cut", 0.14, 0.04, (0.95, 0.15, 0.85), "log_end", sides=6, axis="Z"),
            box("moss", -0.35, 0.25, -0.2, 0.45, 0.72, 0.8, "pad")]
    part("Stub", stub, (0, 0, 0))
    save("log")


def build_crocodile():
    """Il coccodrillo, 1,4 x 0,8 x 6 m come la sua collisione: corpo e coda
    rastremati con le creste, zampe di lato, occhi gialli sul collo, narici,
    denti; la mascella superiore (Jaw) ruota sul suo attacco posteriore e
    Godot la apre per mordere. Davanti +Y, origine al centro."""
    reset()
    parts = []
    # Il corpo: dal collo a metà, poi la coda che si stringe.
    sections = [(1.4, 0.62, -0.38, 0.22), (0.4, 0.7, -0.4, 0.3), (-0.6, 0.66, -0.38, 0.26),
                (-1.6, 0.45, -0.32, 0.18), (-2.4, 0.25, -0.26, 0.1), (-3.0, 0.08, -0.2, 0.0)]
    for i in range(len(sections) - 1):
        y0, w0, b0, t0 = sections[i]
        y1, w1, b1, t1 = sections[i + 1]
        parts.append(block("body_%d" % i,
                           [(-w0, y0, b0), (w0, y0, b0), (w1, y1, b1), (-w1, y1, b1)],
                           [(-w0 * 0.75, y0, t0), (w0 * 0.75, y0, t0), (w1 * 0.75, y1, t1), (-w1 * 0.75, y1, t1)],
                           "croc"))
    # Le creste: due file sulla schiena, una sola sulla coda.
    for i in range(9):
        y = 1.1 - i * 0.42
        top = 0.3 - max(0.0, -y - 0.6) * 0.12
        xs = (-0.25, 0.25) if y > -1.2 else (0.0,)
        for x in xs:
            parts.append(block("scute_%d_%d" % (i, int(x * 10)),
                               [(x - 0.09, y - 0.12, top - 0.02), (x + 0.09, y - 0.12, top - 0.02), (x + 0.09, y + 0.12, top - 0.02), (x - 0.09, y + 0.12, top - 0.02)],
                               [(x - 0.02, y - 0.03, top + 0.12), (x + 0.02, y - 0.03, top + 0.12), (x + 0.02, y + 0.03, top + 0.12), (x - 0.02, y + 0.03, top + 0.12)],
                               "croc_dark"))
    # Le zampe, corte e storte, ai lati.
    for y in (0.9, -0.5):
        for side in (1, -1):
            parts.append(block("leg_%d_%d" % (int(y * 10), side),
                               [(side * 0.55, y - 0.15, -0.3), (side * 0.95, y - 0.05, -0.4), (side * 0.95, y + 0.25, -0.4), (side * 0.55, y + 0.2, -0.3)],
                               [(side * 0.5, y - 0.12, -0.05), (side * 0.75, y - 0.05, -0.15), (side * 0.75, y + 0.15, -0.15), (side * 0.5, y + 0.15, -0.05)],
                               "croc_dark"))
    # La mascella inferiore e i suoi denti.
    parts.append(block("lower_jaw",
                       [(-0.45, 1.4, -0.36), (0.45, 1.4, -0.36), (0.28, 3.0, -0.3), (-0.28, 3.0, -0.3)],
                       [(-0.45, 1.4, -0.08), (0.45, 1.4, -0.08), (0.28, 3.0, -0.12), (-0.28, 3.0, -0.12)],
                       "croc_dark"))
    for i in range(5):
        y = 1.7 + i * 0.3
        w = 0.42 - (y - 1.4) / 1.6 * 0.16
        for side in (1, -1):
            parts.append(cone("tooth_low_%d_%d" % (i, side), 0.045, 0.12, (side * (w - 0.04), y, -0.03), "sign_white", sides=4))
    # Gli occhi sporgenti sul collo, con la fessura scura, e le narici.
    for side in (1, -1):
        parts.append(block("brow_%d" % side,
                           [(side * 0.12, 1.0, 0.18), (side * 0.42, 1.0, 0.18), (side * 0.42, 1.4, 0.15), (side * 0.12, 1.4, 0.15)],
                           [(side * 0.17, 1.08, 0.38), (side * 0.37, 1.08, 0.38), (side * 0.37, 1.32, 0.36), (side * 0.17, 1.32, 0.36)],
                           "croc"))
        parts.append(ico("eye_%d" % side, 0.1, (side * 0.27, 1.3, 0.36), "croc_eye"))
        parts.append(box("slit_%d" % side, side * 0.27 - 0.015, side * 0.27 + 0.015, 1.36, 1.41, 0.3, 0.43, "pupil"))
    join("Body", parts)

    # La mascella superiore: il perno al suo attacco, dietro.
    jaw = [block("upper_jaw",
                 [(-0.48, 1.4, -0.1), (0.48, 1.4, -0.1), (0.3, 3.0, -0.1), (-0.3, 3.0, -0.1)],
                 [(-0.38, 1.4, 0.2), (0.38, 1.4, 0.2), (0.22, 3.0, 0.06), (-0.22, 3.0, 0.06)],
                 "croc")]
    for side in (1, -1):
        jaw.append(box("nostril_%d" % side, side * 0.08 - 0.03, side * 0.08 + 0.03, 2.75, 2.85, 0.06, 0.1, "pupil"))
        for i in range(5):
            y = 1.65 + i * 0.3
            w = 0.46 - (y - 1.4) / 1.6 * 0.17
            tooth = cone("tooth_up_%d_%d" % (i, side), 0.045, 0.12, (side * (w - 0.04), y, -0.14), "sign_white", sides=4)
            tooth.rotation_euler = (math.pi, 0, 0)
            jaw.append(tooth)
    part("Jaw", jaw, (0, 1.4, -0.08))
    save("crocodile")


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


# La funivia del cielo, al posto del treno (stessi ingombri: la cabina dal
# telaio a 0,7 m fino all'altezza del vagone). Le cabine pendono dal cavo
# (CABLE_Z) con un braccio e la carrucola.
CABLE_Z = 7.5


def hanger(y, top):
    """Il braccio dal tetto al cavo, con la carrucola."""
    parts = [box("arm_%d" % int(y * 10), -0.08, 0.08, y - 0.08, y + 0.08, top, CABLE_Z - 0.2, "metal")]
    parts.append(box("yoke_%d" % int(y * 10), -0.12, 0.12, y - 0.6, y + 0.6, CABLE_Z - 0.35, CABLE_Z - 0.2, "trim"))
    for dy in (-0.45, 0.45):
        parts.append(cylinder("pulley_%d_%d" % (int(y * 10), int(dy * 10)), 0.22, 0.1, (0, y + dy, CABLE_Z), "trim"))
    return parts


def cabin_body(length, height, mat):
    """Una cabina a vetri: fondo e tetto pieni, finestre lungo i lati."""
    half = length / 2 - 0.1
    parts = [block("floor", [(-1.3, -half, 0.7), (1.3, -half, 0.7), (1.3, half, 0.7), (-1.3, half, 0.7)],
                   [(-1.5, -half, 1.3), (1.5, -half, 1.3), (1.5, half, 1.3), (-1.5, half, 1.3)], mat)]
    parts.append(box("glass", -1.48, 1.48, -half + 0.2, half - 0.2, 1.3, height - 0.5, "glass"))
    for y in [-half + 0.1] + [-half + 0.2 + k * (length - 0.6) / 4 for k in range(1, 4)] + [half - 0.1]:
        parts.append(box("pillar_%d" % int(y * 10), -1.5, 1.5, y - 0.1, y + 0.1, 1.3, height - 0.5, mat))
    parts.append(box("roof", -1.55, 1.55, -half, half, height - 0.5, height, mat))
    parts += mirrored_box("stripe", 1.5, 1.52, -half, half, 1.0, 1.2, "loco_stripe")
    return parts


def build_cablecar_front():
    """La cabina di testa (al posto della locomotiva, 14 m): il muso a vetri
    inclinato, i fari, due bracci sul cavo."""
    reset()
    length, height = 14.0, 3.8
    parts = cabin_body(length - 1.6, height, "loco")
    for p in parts:
        p.location.y -= 0.8
    parts.append(block("nose", [(-1.5, length / 2 - 1.7, 0.7), (1.5, length / 2 - 1.7, 0.7), (1.0, length / 2, 1.0), (-1.0, length / 2, 1.0)],
                       [(-1.55, length / 2 - 1.7, height), (1.55, length / 2 - 1.7, height), (1.0, length / 2 - 0.6, height - 0.6), (-1.0, length / 2 - 0.6, height - 0.6)], "loco"))
    parts.append(box("windshield", -0.95, 0.95, length / 2 - 0.62, length / 2 - 0.4, 1.8, height - 0.8, "glass"))
    parts += mirrored_box("headlight", 0.4, 0.8, length / 2 - 0.05, length / 2 + 0.02, 1.15, 1.4, "headlight")
    for y in (-3.5, 3.0):
        parts += hanger(y, height)
    join("CableCarFront", parts)
    save("cablecar_front")


def build_cablecar():
    """Una cabina (al posto del carro chiuso, 12 m), due bracci sul cavo."""
    reset()
    length, height = 12.0, 3.7
    parts = cabin_body(length, height, "wagon")
    for y in (-3.5, 3.5):
        parts += hanger(y, height)
    join("CableCar", parts)
    save("cablecar")


def build_cablecar_open():
    """Il cestone aperto (al posto del pianale, 12 m, alto 1,2): una vasca
    bassa con le sponde, appesa al cavo con quattro funi tese."""
    reset()
    length, height = 12.0, 1.2
    half = length / 2 - 0.1
    parts = [block("tray", [(-1.3, -half, 0.7), (1.3, -half, 0.7), (1.3, half, 0.7), (-1.3, half, 0.7)],
                   [(-1.5, -half, 1.0), (1.5, -half, 1.0), (1.5, half, 1.0), (-1.5, half, 1.0)], "wagon")]
    parts.append(box("deck", -1.45, 1.45, -half, half, 1.0, height, "wagon_deck"))
    parts += mirrored_box("rail", 1.4, 1.5, -half, half, height, height + 0.5, "wagon")
    for y in (-half + 0.3, half - 0.3):
        for side in (1, -1):
            parts.append(tube("rope_%d_%d" % (int(y), side), (side * 1.4, y, height + 0.5), (0, y * 0.6, CABLE_Z - 0.3), 0.04, "trim"))
        parts += hanger(y * 0.6, CABLE_Z - 0.4)
    join("CableCarOpen", parts)
    save("cablecar_open")


def build_cable_pylon():
    """Il pilone della funivia, fuori dalla zona di gioco: un traliccio che
    regge il cavo a CABLE_Z."""
    reset()
    parts = []
    for x in (-0.8, 0.8):
        for y in (-0.8, 0.8):
            parts.append(tube("leg_%d_%d" % (x * 10, y * 10), (x, y, 0), (x * 0.3, y * 0.3, CABLE_Z + 0.6), 0.1, "crane"))
    for z in (2.0, 4.0, 6.0):
        k = 1 - z / (CABLE_Z + 0.6) * 0.7
        parts.append(box("ring_%d" % z, -0.8 * k - 0.05, 0.8 * k + 0.05, -0.8 * k - 0.05, 0.8 * k + 0.05, z - 0.06, z + 0.06, "crane"))
    parts.append(box("head", -0.6, 0.6, -0.4, 0.4, CABLE_Z + 0.5, CABLE_Z + 0.8, "trim"))
    join("CablePylon", parts)
    save("cable_pylon")


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


# --- Aeroporto --------------------------------------------------------------

def build_airplane():
    """Aereo di linea: davanti verso +Y, origine a terra. Pancia a 0,9 m (la
    rana non ci passa sotto), ali a circa 2,5 m (sotto le ali sì), motori
    sotto le ali."""
    airplane_model("airplane", props=False)


def build_airplane_prop():
    """L'aereo del cielo, cambiato di poco: un vecchio quadrimotore a eliche.
    Stessa sagoma e stessi ingombri del jet (i motori interni al loro posto),
    due motori in più più in fuori, e le eliche "Prop_*" davanti a ogni
    motore; coda e strisce rosse."""
    airplane_model("airplane_prop", props=True)


def airplane_model(name, props):
    reset()
    livery = "loco" if props else "plane_tail"
    parts = []
    parts.append(block("fuselage",
                       [(-1.8, -7, 0.9), (1.8, -7, 0.9), (1.8, 8, 0.9), (-1.8, 8, 0.9)],
                       [(-1.8, -7, 4.5), (1.8, -7, 4.5), (1.8, 8, 4.5), (-1.8, 8, 4.5)], "plane"))
    parts.append(block("nose",
                       [(-1.8, 8, 0.9), (1.8, 8, 0.9), (0.6, 12, 2.0), (-0.6, 12, 2.0)],
                       [(-1.8, 8, 4.5), (1.8, 8, 4.5), (0.6, 12, 3.4), (-0.6, 12, 3.4)], "plane"))
    parts.append(block("cockpit",
                       [(-1.2, 9.6, 3.5), (1.2, 9.6, 3.5), (0.62, 11.6, 3.05), (-0.62, 11.6, 3.05)],
                       [(-1.2, 9.6, 4.0), (1.2, 9.6, 4.0), (0.62, 11.6, 3.45), (-0.62, 11.6, 3.45)], "glass"))
    parts.append(block("tail_cone",
                       [(-1.8, -7, 0.9), (1.8, -7, 0.9), (0.5, -12, 3.0), (-0.5, -12, 3.0)],
                       [(-1.8, -7, 4.5), (1.8, -7, 4.5), (0.5, -12, 4.5), (-0.5, -12, 4.5)], "plane"))
    parts += mirrored_box("windows", 1.8, 1.83, -6.0, 7.0, 3.2, 3.6, "glass")
    for side in (1, -1):
        parts.append(block("wing_%d" % side,
                           [(side * 1.8, -1.0, 2.4), (side * 13.0, -4.0, 2.6), (side * 13.0, -2.2, 2.6), (side * 1.8, 4.0, 2.4)],
                           [(side * 1.8, -1.0, 2.75), (side * 13.0, -4.0, 2.8), (side * 13.0, -2.2, 2.8), (side * 1.8, 4.0, 2.75)],
                           "plane_wing"))
        parts.append(cylinder("engine_%d" % side, 0.85, 3.4, (side * 6.0, 1.2, 1.75), "plane_engine", sides=8, axis="Y"))
        if props:
            parts.append(cone("spinner_%d" % side, 0.4, 0.6, (side * 6.0, 3.2, 1.75), "plane", sides=8))
            parts[-1].rotation_euler = (-math.pi / 2, 0, 0)
            parts.append(cylinder("engine_out_%d" % side, 0.7, 2.8, (side * 10.0, 0.0, 2.0), "plane_engine", sides=8, axis="Y"))
            parts.append(cone("spinner_out_%d" % side, 0.35, 0.5, (side * 10.0, 1.65, 2.0), "plane", sides=8))
            parts[-1].rotation_euler = (-math.pi / 2, 0, 0)
        else:
            parts.append(cylinder("intake_%d" % side, 0.7, 0.05, (side * 6.0, 2.92, 1.75), "trim", sides=8, axis="Y"))
        parts.append(block("stabilizer_%d" % side,
                           [(side * 0.4, -12.0, 4.2), (side * 5.0, -12.2, 4.3), (side * 5.0, -11.2, 4.3), (side * 0.4, -9.2, 4.2)],
                           [(side * 0.4, -12.0, 4.45), (side * 5.0, -12.2, 4.45), (side * 5.0, -11.2, 4.45), (side * 0.4, -9.2, 4.45)],
                           "plane_wing"))
    parts.append(block("fin",
                       [(-0.2, -11.8, 4.5), (0.2, -11.8, 4.5), (0.2, -8.0, 4.5), (-0.2, -8.0, 4.5)],
                       [(-0.15, -12.6, 9.5), (0.15, -12.6, 9.5), (0.15, -10.6, 9.5), (-0.15, -10.6, 9.5)],
                       livery))
    parts.append(box("tail_stripe_l", -1.84, -1.8, -6.5, 7.5, 1.6, 1.9, livery))
    parts.append(box("tail_stripe_r", 1.8, 1.84, -6.5, 7.5, 1.6, 1.9, livery))
    parts.append(cylinder("nose_wheel", 0.35, 0.3, (0, 9.5, 0.35), "tire"))
    parts.append(box("nose_strut", -0.08, 0.08, 9.42, 9.58, 0.35, 1.2, "metal"))
    for side in (1, -1):
        for dy in (-0.45, 0.45):
            parts.append(cylinder("main_wheel", 0.45, 0.35, (side * 2.4, -0.5 + dy, 0.45), "tire"))
        parts.append(box("main_strut", side * 2.4 - 0.1, side * 2.4 + 0.1, -0.6, -0.4, 0.45, 2.5, "metal"))
    join("Airplane", parts)
    if props:
        for i, (x, y, z, r) in enumerate([(6.0, 3.0, 1.75, 1.25), (-6.0, 3.0, 1.75, 1.25), (10.0, 1.45, 2.0, 1.05), (-10.0, 1.45, 2.0, 1.05)]):
            propeller("Prop_%d" % i, (x, y, z), r, "trim")
    save(name)


# I mezzi del trenino bagagli hanno l'origine a terra, al centro, come i
# rotabili: davanti verso +Y. Passano sotto le ali (2,4 m): restano sotto 1,9.

def build_tug():
    """Trattorino portabagagli: 1,4 x 2,6 m, cofano davanti, sedile dietro
    sotto un tettuccio su quattro montanti."""
    reset()
    parts = [box("chassis", -0.7, 0.7, -1.3, 1.3, 0.3, 0.6, "tug")]
    parts.append(block("hood",
                       [(-0.68, 0.0, 0.6), (0.68, 0.0, 0.6), (0.68, 1.3, 0.6), (-0.68, 1.3, 0.6)],
                       [(-0.6, 0.0, 1.05), (0.6, 0.0, 1.05), (0.6, 1.2, 0.9), (-0.6, 1.2, 0.9)], "tug"))
    parts.append(box("seat", -0.45, 0.45, -1.0, -0.4, 0.6, 0.85, "trim"))
    parts.append(box("seat_back", -0.45, 0.45, -1.15, -1.0, 0.6, 1.25, "trim"))
    for x in (0.62, -0.62):
        for y in (0.0, -1.2):
            parts.append(box("post", x - 0.04, x + 0.04, y - 0.04, y + 0.04, 0.6, 1.7, "metal"))
    parts.append(box("canopy", -0.7, 0.7, -1.3, 0.1, 1.7, 1.78, "tug"))
    parts.append(box("beacon", -0.12, 0.12, -0.6, -0.36, 1.78, 1.9, "beacon"))
    parts += mirrored_box("headlight", 0.3, 0.55, 1.3, 1.34, 0.7, 0.85, "headlight")
    parts.append(box("bumper", -0.7, 0.7, 1.3, 1.42, 0.25, 0.45, "trim"))
    parts.append(box("hitch", -0.08, 0.08, -1.55, -1.3, 0.35, 0.45, "metal"))
    join("Tug", parts)
    wheels(0.3, 0.22, 0.62, (0.85, -0.85), 0.3)
    save("tug")


def build_dolly():
    """Carrello portabagagli: pianale a 0,55 m (1,5 x 2,6), sponde basse e
    timone davanti. I bagagli li carica Godot sul pianale."""
    reset()
    parts = [box("bed", -0.75, 0.75, -1.3, 1.3, 0.4, 0.55, "dolly")]
    for x in (0.72, -0.72):
        for y in (-1.25, 0.0, 1.25):
            parts.append(box("stake", x - 0.03, x + 0.03, y - 0.03, y + 0.03, 0.55, 0.85, "metal"))
        parts.append(box("rail", x - 0.03, x + 0.03, -1.28, 1.28, 0.8, 0.85, "metal"))
    parts.append(box("drawbar", -0.05, 0.05, 1.3, 1.85, 0.38, 0.46, "metal"))
    join("Dolly", parts)
    for i, y in enumerate((0.85, -0.85)):
        for side, label in ((1, "R"), (-1, "L")):
            cylinder("Wheel_%d%s" % (i, label), 0.2, 0.15, (side * 0.62, y, 0.2), "tire")
    save("dolly")


def build_suitcase():
    """Valigia sdraiata: 0,5 x 0,75 x 0,3 m, origine al centro. Il colore
    ("paint") lo sceglie Godot."""
    reset()
    parts = [box("shell", -0.25, 0.25, -0.375, 0.375, -0.15, 0.15, "paint")]
    parts.append(box("zip", -0.26, 0.26, -0.385, 0.385, -0.02, 0.02, "trim"))
    parts.append(box("handle", -0.1, 0.1, 0.375, 0.42, 0.04, 0.1, "trim"))
    parts.append(box("tag", 0.25, 0.27, -0.1, 0.05, -0.08, 0.06, "sign_white"))
    join("Suitcase", parts)
    save("suitcase")


def build_parcel():
    """Pacco di cartone: 0,6 x 0,6 x 0,5 m con il nastro adesivo, origine al
    centro."""
    reset()
    parts = [box("box", -0.3, 0.3, -0.3, 0.3, -0.25, 0.25, "cardboard")]
    parts.append(box("tape_top", -0.06, 0.06, -0.31, 0.31, 0.25, 0.26, "tape"))
    for y in (0.3, -0.31):
        parts.append(box("tape_side", -0.06, 0.06, y, y + 0.01, 0.0, 0.26, "tape"))
    join("Parcel", parts)
    save("parcel")


# --- Porto -------------------------------------------------------------------

def build_crane():
    """Gru a portale: scavalca una corsia d'acqua lungo Y (14 m tra le gambe,
    sulle due banchine) e scorre lungo X. Origine a terra, al centro. Il
    carrello è un modello a parte (crane_trolley), perché scorre lungo il
    braccio."""
    reset()
    parts = []
    half = 7.0
    for y in (half, -half):
        for x in (2.2, -2.2):
            parts.append(box("leg", x - 0.25, x + 0.25, y - 0.25, y + 0.25, 0, 15.0, "crane"))
        parts.append(box("foot_beam", -2.6, 2.6, y - 0.35, y + 0.35, 0, 0.6, "crane"))
        parts.append(box("cross", -2.2, 2.2, y - 0.2, y + 0.2, 7.5, 8.0, "crane"))
        parts.append(cylinder("wheel_a", 0.35, 0.3, (2.2, y, 0.35), "trim", sides=8, axis="X"))
        parts.append(cylinder("wheel_b", 0.35, 0.3, (-2.2, y, 0.35), "trim", sides=8, axis="X"))
    for x in (1.6, -1.6):
        parts.append(box("girder", x - 0.35, x + 0.35, -half - 1.5, half + 1.5, 15.0, 16.0, "crane"))
    parts.append(box("cab", -1.9, -1.3, -half - 1.4, -half + 0.2, 13.6, 15.0, "crane_cab"))
    parts.append(box("cab_window", -1.95, -1.9, -half - 1.2, -half, 14.1, 14.8, "glass"))
    join("Crane", parts)
    save("crane")


def build_crane_trolley():
    """Il carrello della gru, con i cavi e lo spreader: scorre lungo Y tra le
    travi. Lo spreader è lungo X, come i container sulle navi. Origine a
    terra sotto il carrello: le quote sono quelle della gru."""
    reset()
    parts = [box("trolley", -1.3, 1.3, -1.6, 1.6, 15.2, 16.4, "crane")]
    for x in (-1.1, 1.1):
        parts.append(box("cable", x - 0.05, x + 0.05, -0.05, 0.05, 13.0, 15.2, "metal"))
    parts.append(box("spreader", -3.1, 3.1, -1.3, 1.3, 12.8, 13.0, "metal"))
    join("CraneTrolley", parts)
    save("crane_trolley")


def build_ship():
    """Nave portacontainer: la prua guarda verso +X (non +Y: in gioco la nave
    corre lungo X), il ponte è a 0,7 m, la linea di galleggiamento a -0,4.
    Dietro c'è il ponte di comando, davanti il castello di prua: tutti e due
    troppo alti per il salto normale. In mezzo, il ponte libero per i
    container (da x = -14,6 a 17)."""
    reset()
    parts = [box("hull", -20, 17, -5, 5, -2.5, 0.6, "ship_hull")]
    parts.append(box("deck", -14.6, 17, -5, 5, 0.6, 0.7, "ship_deck"))
    parts.append(box("stripe", -20.05, 17, -5.05, 5.05, -0.6, -0.3, "ship_stripe"))
    bow = [(17, -5), (21.5, -1.2), (21.5, 1.2), (17, 5)]
    parts.append(block("bow",
                       [(17, -4, -2.5), (21, -0.5, -2.5), (21, 0.5, -2.5), (17, 4, -2.5)],
                       [(x, y, 0.6) for x, y in bow], "ship_hull"))
    parts.append(block("forecastle",
                       [(x, y, 0.6) for x, y in bow],
                       [(x, y, 3.4) for x, y in bow], "ship_hull"))
    parts.append(box("forecastle_top", 17, 21.3, -4.6, 4.6, 3.4, 3.5, "ship_deck"))
    parts.append(box("bridge", -20, -14.6, -5, 5, 0.6, 9.0, "ship_bridge"))
    parts.append(box("bridge_windows", -14.65, -14.55, -4.6, 4.6, 7.4, 8.3, "glass"))
    for y in (-5.05, 5.0):
        parts.append(box("side_windows", -19.5, -15.1, y, y + 0.05, 7.4, 8.3, "glass"))
    parts.append(box("funnel", -19.2, -17.0, -1.1, 1.1, 9.0, 11.0, "ship_hull"))
    parts.append(box("funnel_band", -19.25, -16.95, -1.15, 1.15, 10.0, 10.5, "ship_stripe"))
    join("Ship", parts)
    save("ship")


def build_airship():
    """Il dirigibile cargo del cielo, al posto della nave (stessi ingombri:
    la prua verso +X, il ponte a 0,7 m, la cabina di comando a poppa e il muso
    a prua troppo alti per il salto normale). Il ponte coi container sta sul
    dorso di un grande involucro a sigaro, che pende sotto; a poppa le pinne,
    ai lati le gondole dei motori con le eliche "Prop_*"."""
    reset()
    parts = [box("deck", -20, 17, -5, 5, 0.45, 0.7, "ship_deck")]
    # La fiancata sotto il ponte, che si rastrema verso l'involucro.
    parts.append(block("keel", [(-20, -3.0, -2.4), (17, -3.0, -2.4), (17, 3.0, -2.4), (-20, 3.0, -2.4)],
                       [(-20, -5.0, 0.45), (17, -5.0, 0.45), (17, 5.0, 0.45), (-20, 5.0, 0.45)], "ship_hull"))
    parts.append(box("keel_stripe", -20.05, 17.05, -5.05, 5.05, -0.2, 0.15, "ship_stripe"))
    parts += [box("gunwale_a", -14.6, 17, 4.85, 5.0, 0.7, 1.0, "trim"), box("gunwale_b", -14.6, 17, -5.0, -4.85, 0.7, 1.0, "trim")]
    hull = cylinder("envelope", 4.6, 40.0, (-1.0, 0, -4.2), "airship", sides=10, axis="X")
    parts.append(hull)
    nose = cone("envelope_nose", 4.6, 4.5, (21.2, 0, -4.2), "airship", sides=10)
    nose.rotation_euler = (0, math.pi / 2, 0)
    parts.append(nose)
    tail = cone("envelope_tail", 4.6, 5.0, (-23.5, 0, -4.2), "airship", sides=10)
    tail.rotation_euler = (0, -math.pi / 2, 0)
    parts.append(tail)
    for x in (-8.0, 8.0):
        parts.append(cylinder("band_%d" % x, 4.65, 0.8, (x, 0, -4.2), "ship_stripe", sides=10, axis="X"))
    # Le pinne a croce in coda.
    parts.append(box("fin_down", -26.5, -21.5, -0.15, 0.15, -12.0, -8.0, "ship_hull"))
    for side in (1, -1):
        parts.append(box("fin_side_%d" % side, -26.5, -21.5, side * 4.0, side * 8.5, -4.4, -4.0, "ship_hull"))
    # Il muso a prua (come il castello) e la cabina di comando a poppa.
    bow = [(17, -5), (21.5, -1.2), (21.5, 1.2), (17, 5)]
    parts.append(block("forecastle", [(x, y, 0.6) for x, y in bow], [(x, y, 3.4) for x, y in bow], "ship_hull"))
    parts.append(box("forecastle_top", 17, 21.3, -4.6, 4.6, 3.4, 3.5, "ship_deck"))
    parts.append(box("bridge", -20, -14.6, -5, 5, 0.6, 9.0, "ship_bridge"))
    parts.append(box("bridge_windows", -14.65, -14.55, -4.6, 4.6, 7.4, 8.3, "glass"))
    for y in (-5.05, 5.0):
        parts.append(box("side_windows", -19.5, -15.1, y, y + 0.05, 7.4, 8.3, "glass"))
    parts.append(box("mast", -17.6, -17.2, -0.2, 0.2, 9.0, 12.0, "metal"))
    parts.append(box("beacon", -17.7, -17.1, -0.3, 0.3, 12.0, 12.4, "beacon"))
    # Le gondole dei motori ai lati, sotto il ponte.
    for side in (1, -1):
        parts.append(box("pylon_%d" % side, -12.6, -11.4, side * 5.0, side * 7.0, -1.0, -0.6, "trim"))
        parts.append(cylinder("pod_%d" % side, 0.8, 3.0, (-12.0, side * 7.4, -0.8), "ship_bridge", sides=8, axis="X"))
    join("Airship", parts)
    # Le eliche girano attorno a X, il verso di marcia della nave.
    for i, side in enumerate((1, -1)):
        propeller("Prop_%d" % i, (-13.7, side * 7.4, -0.8), 1.4, "trim", axis="X")
    save("airship")


def build_skycrane():
    """L'elicottero-gru del cielo, al posto del carrello della gru: stesse
    quote (il container appeso sotto lo spreader, a 12,8 m), la fusoliera
    sottile con la cabina davanti (+X) e il grande rotore "Rotor_main" sopra.
    Origine a terra sotto l'elicottero."""
    reset()
    parts = [block("spine", [(-6.5, -0.6, 15.0), (5.0, -0.6, 15.0), (5.0, 0.6, 15.0), (-6.5, 0.6, 15.0)],
                   [(-6.5, -0.45, 16.6), (5.0, -0.45, 16.6), (5.0, 0.45, 16.6), (-6.5, 0.45, 16.6)], "crane")]
    parts.append(block("cockpit", [(5.0, -1.0, 14.6), (7.6, -0.7, 15.0), (7.6, 0.7, 15.0), (5.0, 1.0, 14.6)],
                       [(5.0, -0.9, 16.8), (7.2, -0.6, 16.2), (7.2, 0.6, 16.2), (5.0, 0.9, 16.8)], "crane"))
    parts.append(box("windshield", 6.5, 7.3, -0.62, 0.62, 15.4, 16.1, "glass"))
    parts.append(block("tail", [(-6.5, -0.45, 15.4), (-11.5, -0.25, 15.9), (-11.5, 0.25, 15.9), (-6.5, 0.45, 15.4)],
                       [(-6.5, -0.35, 16.6), (-11.5, -0.2, 16.4), (-11.5, 0.2, 16.4), (-6.5, 0.35, 16.6)], "crane"))
    parts.append(box("fin", -12.0, -10.8, -0.08, 0.08, 16.0, 18.2, "crane_cab"))
    parts.append(box("engine", -2.5, 1.5, -1.0, 1.0, 16.6, 17.4, "crane_cab"))
    parts.append(box("mast", -0.25, 0.25, -0.25, 0.25, 17.4, 17.9, "trim"))
    for side in (1, -1):
        parts.append(box("leg_f_%d" % side, 3.5, 3.8, side * 0.5, side * 2.4, 13.4, 15.2, "trim"))
        parts.append(box("leg_b_%d" % side, -3.8, -3.5, side * 0.5, side * 2.4, 13.4, 15.2, "trim"))
    for x in (-1.1, 1.1):
        parts.append(box("cable", x - 0.05, x + 0.05, -0.05, 0.05, 13.0, 15.0, "metal"))
    parts.append(box("spreader", -3.1, 3.1, -1.3, 1.3, 12.8, 13.0, "metal"))
    join("Skycrane", parts)
    rotor = [box("blade_a", -9.0, 9.0, -0.3, 0.3, 17.85, 17.95, "trim"), box("blade_b", -0.3, 0.3, -9.0, 9.0, 17.85, 17.95, "trim")]
    part("Rotor_main", rotor, (0, 0, 17.9))
    tail_rotor = [box("tail_blade", -12.4, -11.6, 0.1, 0.16, 15.6, 18.6, "trim"), box("tail_blade_b", -13.5, -10.5, 0.1, 0.16, 17.0, 17.2, "trim")]
    # Il rotore di coda gira di lato: Prop_tail, attorno all'asse di lato.
    part("Prop_tail", tail_rotor, (-12.0, 0.13, 17.1))
    save("skycrane")


def build_container():
    """Container da 20 piedi: 2,44 x 2,6 x 6,1 m, davanti verso +Y, origine
    al centro. Le nervature fanno leggere la forma anche in pixel grossi."""
    reset()
    w, h, length = 1.22, 1.3, 3.05
    parts = [box("body", -w, w, -length, length, -h, h, "paint")]
    for i in range(9):
        y = -length + 0.35 + i * (2 * length - 0.7) / 8
        parts += mirrored_box("rib", w, w + 0.05, y - 0.08, y + 0.08, -h + 0.1, h - 0.1, "paint")
    parts.append(box("doors", -w + 0.05, w - 0.05, -length - 0.04, -length, -h + 0.05, h - 0.05, "trim"))
    parts.append(box("frame_top", -w - 0.02, w + 0.02, -length, length, h - 0.08, h + 0.02, "trim"))
    parts.append(box("frame_bottom", -w - 0.02, w + 0.02, -length, length, -h - 0.02, -h + 0.08, "trim"))
    join("Container", parts)
    save("container")


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


# --- Il cielo: i veicoli della strada (vedi scripts/worlds.gd) ----------------
# Stessi ruoli di utilitaria, berlina, furgone e camion, con le loro
# dimensioni di gioco. Le eliche "Prop_*" girano attorno al muso (l'asse
# avanti), i rotori "Rotor_*" attorno all'alto; le ruote "Wheel_*" come
# quelle delle auto.

def propeller(name, pivot, radius, mat="trim", axis="Y"):
    """Un'elica a due pale con il mozzo, con l'origine nel mozzo. axis: l'asse
    attorno a cui gira (Y avanti, X di lato)."""
    x, y, z = pivot
    hub = cone(name + "_hub", 0.08, 0.16, pivot, "metal", sides=6)
    if axis == "Y":
        hub.rotation_euler = (-math.pi / 2, 0, 0)
        blade = box(name + "_blade", x - radius, x + radius, y - 0.03, y + 0.03, z - 0.06, z + 0.06, mat)
    else:
        hub.rotation_euler = (0, math.pi / 2, 0)
        blade = box(name + "_blade", x - 0.03, x + 0.03, y - radius, y + radius, z - 0.06, z + 0.06, mat)
    return part(name, [hub, blade], pivot)


def build_ultralight():
    """L'ultraleggero (al posto dell'utilitaria, 1,8 x 1,35 x 3,4): una
    carlinga a goccia col tettuccio, l'ala alta coi montanti, la trave di coda
    e l'elica sul muso. Le ali sporgono oltre l'ingombro: solo da vedere."""
    reset()
    hz, hy = 0.675, 1.7
    parts = [block("pod", [(-0.42, -0.4, -0.5), (0.42, -0.4, -0.5), (0.3, 1.3, -0.45), (-0.3, 1.3, -0.45)],
                   [(-0.42, -0.4, 0.25), (0.42, -0.4, 0.25), (0.3, 1.3, 0.1), (-0.3, 1.3, 0.1)], "paint")]
    parts.append(block("nose", [(-0.3, 1.3, -0.45), (0.3, 1.3, -0.45), (0.12, 1.6, -0.25), (-0.12, 1.6, -0.25)],
                       [(-0.3, 1.3, 0.1), (0.3, 1.3, 0.1), (0.12, 1.6, -0.05), (-0.12, 1.6, -0.05)], "paint"))
    parts.append(block("canopy", [(-0.34, -0.2, 0.25), (0.34, -0.2, 0.25), (0.26, 1.1, 0.1), (-0.26, 1.1, 0.1)],
                       [(-0.26, -0.1, 0.55), (0.26, -0.1, 0.55), (0.2, 0.7, 0.5), (-0.2, 0.7, 0.5)], "glass"))
    parts.append(box("wing", -1.95, 1.95, -0.05, 0.85, 0.55, hz, "paint"))
    parts += mirrored_box("wing_tip", 1.75, 1.95, -0.05, 0.85, 0.54, hz + 0.01, "wing_stripe")
    for side in (1, -1):
        parts.append(tube("strut_%d" % side, (side * 0.4, 0.4, -0.2), (side * 1.2, 0.4, 0.56), 0.035, "trim"))
    parts.append(tube("boom", (0, -0.4, 0.05), (0, -1.55, 0.3), 0.08, "trim"))
    parts.append(block("fin", [(-0.03, -1.7, 0.25), (0.03, -1.7, 0.25), (0.03, -1.35, 0.25), (-0.03, -1.35, 0.25)],
                       [(-0.03, -1.7, hz), (0.03, -1.7, hz), (0.03, -1.55, hz), (-0.03, -1.55, hz)], "paint"))
    parts.append(box("tailplane", -0.65, 0.65, -1.7, -1.45, 0.27, 0.33, "paint"))
    parts.append(box("headlight", -0.1, 0.1, 1.55, 1.62, -0.2, -0.1, "headlight"))
    parts.append(box("taillight", -0.04, 0.04, -1.72, -1.68, 0.55, 0.62, "taillight"))
    for side in (1, -1):
        parts.append(tube("gear_%d" % side, (side * 0.3, 0.6, -0.45), (side * 0.55, 0.6, -0.5), 0.03, "trim"))
    join("Body", parts)
    wheels(0.15, 0.08, 0.6, (0.6,), -hz + 0.15)
    propeller("Prop_nose", (0, 1.66, -0.15), 0.75)
    save("ultralight")


def build_helicopter():
    """L'elicotterino (al posto della berlina, 2,0 x 1,4 x 4,4): la bolla di
    vetro davanti, la trave di coda col rotore di coda (una "ruota" che gira di
    lato), i pattini e il rotore principale sul tetto, più largo dell'ingombro."""
    reset()
    hz, hy = 0.7, 2.2
    parts = [block("body", [(-0.85, -0.8, -0.45), (0.85, -0.8, -0.45), (0.85, 0.9, -0.45), (-0.85, 0.9, -0.45)],
                   [(-0.7, -0.6, 0.5), (0.7, -0.6, 0.5), (0.7, 0.9, 0.5), (-0.7, 0.9, 0.5)], "paint")]
    parts.append(block("bubble", [(-0.85, 0.9, -0.45), (0.85, 0.9, -0.45), (0.45, 2.05, -0.3), (-0.45, 2.05, -0.3)],
                       [(-0.7, 0.9, 0.5), (0.7, 0.9, 0.5), (0.3, 1.9, 0.15), (-0.3, 1.9, 0.15)], "glass"))
    parts.append(block("boom", [(-0.2, -2.0, 0.0), (0.2, -2.0, 0.0), (0.3, -0.8, -0.2), (-0.3, -0.8, -0.2)],
                       [(-0.12, -2.0, 0.25), (0.12, -2.0, 0.25), (0.25, -0.8, 0.35), (-0.25, -0.8, 0.35)], "paint"))
    parts.append(block("fin", [(-0.04, -2.2, 0.1), (0.04, -2.2, 0.1), (0.04, -1.85, 0.1), (-0.04, -1.85, 0.1)],
                       [(-0.04, -2.2, hz), (0.04, -2.2, hz), (0.04, -2.05, hz), (-0.04, -2.05, hz)], "paint"))
    parts.append(box("mast", -0.12, 0.12, 0.05, 0.3, 0.5, 0.66, "trim"))
    for side in (1, -1):
        parts.append(box("skid_%d" % side, side * 0.75 - 0.05, side * 0.75 + 0.05, -0.9, 1.4, -hz, -hz + 0.06, "trim"))
        for y in (-0.4, 0.8):
            parts.append(tube("strut_%d_%d" % (side, int(y * 10)), (side * 0.75, y, -hz + 0.05), (side * 0.6, y, -0.42), 0.03, "trim"))
    parts += mirrored_box("headlight", 0.15, 0.35, 1.9, 1.95, -0.3, -0.15, "headlight")
    parts.append(box("taillight", -0.05, 0.05, -2.22, -2.18, 0.55, 0.65, "taillight"))
    join("Body", parts)
    # Il rotore di coda gira di lato come una ruota: Wheel_tail.
    tail = [box("tail_blade_a", 0.22, 0.26, -2.05 - 0.38, -2.05 + 0.38, 0.4, 0.48, "trim"),
            box("tail_blade_b", 0.22, 0.26, -2.05 - 0.04, -2.05 + 0.04, 0.06, 0.82, "trim")]
    part("Wheel_tail", tail, (0.24, -2.05, 0.44))
    main = [box("blade_a", -2.2, 2.2, 0.1, 0.25, 0.66, 0.7, "trim"), box("blade_b", -0.07, 0.07, -2.0, 2.4, 0.66, 0.7, "trim"),
            cone("hub", 0.14, 0.12, (0, 0.175, 0.72), "metal", sides=6)]
    part("Rotor_main", main, (0, 0.175, 0.68))
    save("helicopter")


def build_balloon():
    """La mongolfiera (al posto del furgone, 2,4 x 3,4 x 2,6): il cesto di
    vimini col bruciatore, le funi, e il pallone a spicchi che fa da tetto."""
    reset()
    hz = 1.7
    parts = [box("basket", -0.6, 0.6, -0.6, 0.6, -hz, -0.95, "wicker")]
    parts.append(box("rim", -0.65, 0.65, -0.65, 0.65, -1.0, -0.9, "leather"))
    parts.append(box("burner", -0.18, 0.18, -0.18, 0.18, -0.85, -0.65, "metal"))
    parts.append(box("flame", -0.08, 0.08, -0.08, 0.08, -0.65, -0.5, "headlight"))
    for x in (-1, 1):
        for y in (-1, 1):
            parts.append(tube("rope_%d_%d" % (x, y), (x * 0.58, y * 0.58, -0.95), (x * 0.45, y * 0.45, -0.55), 0.02, "trim"))
    # Il pallone: un cono rovesciato, un cilindro e la cupola, a otto spicchi.
    lower = cone("envelope_low", 1.2, 1.1, (0, 0, -0.05), "paint", sides=8)
    lower.rotation_euler = (math.pi, 0, 0)
    parts.append(lower)
    parts.append(cylinder("envelope_mid", 1.2, 1.1, (0, 0, 1.0), "paint", sides=8, axis="Z"))
    parts.append(cylinder("band", 1.22, 0.25, (0, 0, 0.8), "wing_stripe", sides=8, axis="Z"))
    top = cone("envelope_top", 1.2, 0.5, (0, 0, 1.8), "paint", sides=8)
    parts.append(top)
    join("Body", parts)
    save("balloon")


def build_blimp():
    """Il dirigibile (al posto del camion, 2,4 x 2,6 x 8): l'involucro a sigaro
    con le pinne in coda, la gondola sotto coi finestrini e due eliche ai lati."""
    reset()
    hz, hy = 1.3, 4.0
    parts = [cylinder("hull", 1.05, 5.6, (0, 0, 0.25), "paint", sides=8, axis="Y")]
    parts[0].scale = (1.12, 1.0, 1.0)
    nose = cone("nose", 1.05, 1.2, (0, 3.4, 0.25), "paint", sides=8)
    nose.rotation_euler = (-math.pi / 2, 0, 0)
    nose.scale = (1.12, 1.0, 1.0)
    parts.append(nose)
    tail = cone("tail", 1.05, 1.2, (0, -3.4, 0.25), "paint", sides=8)
    tail.rotation_euler = (math.pi / 2, 0, 0)
    tail.scale = (1.12, 1.0, 1.0)
    parts.append(tail)
    parts.append(cylinder("band", 1.08, 0.4, (0, 1.5, 0.25), "wing_stripe", sides=8, axis="Y"))
    parts[-1].scale = (1.12, 1.0, 1.0)
    # Le pinne a croce.
    parts.append(block("fin_up", [(-0.05, -3.9, 0.9), (0.05, -3.9, 0.9), (0.05, -2.7, 0.9), (-0.05, -2.7, 0.9)],
                       [(-0.05, -3.95, hz), (0.05, -3.95, hz), (0.05, -3.4, hz), (-0.05, -3.4, hz)], "trim"))
    parts.append(block("fin_down", [(-0.05, -3.9, -0.4), (0.05, -3.9, -0.4), (0.05, -2.7, -0.4), (-0.05, -2.7, -0.4)],
                       [(-0.05, -3.95, -0.95), (0.05, -3.95, -0.95), (0.05, -3.4, -0.95), (-0.05, -3.4, -0.95)], "trim"))
    for side in (1, -1):
        parts.append(box("fin_side_%d" % side, side * 0.9, side * 1.75, -3.9, -2.9, 0.2, 0.3, "trim"))
    parts.append(box("gondola", -0.42, 0.42, -0.8, 1.4, -hz, -0.65, "cargo"))
    parts += mirrored_box("window", 0.42, 0.44, -0.6, 1.2, -1.05, -0.85, "glass")
    parts.append(box("headlight", -0.15, 0.15, 3.98, 4.02, 0.15, 0.35, "headlight"))
    parts.append(box("taillight", -0.08, 0.08, -3.98, -3.94, 1.05, 1.2, "taillight"))
    for side in (1, -1):
        parts.append(box("pylon_%d" % side, side * 0.42, side * 0.8, -0.95, -0.75, -1.05, -0.95, "trim"))
    join("Body", parts)
    for name, side in (("Prop_L", -1), ("Prop_R", 1)):
        propeller(name, (side * 0.85, -1.0, -1.0), 0.5)
    save("blimp")


def build_stunt_plane():
    """L'aereo della pattuglia acrobatica (il bioma del cielo): un piccolo jet
    a ala bassa, lungo 6 m e largo 5,6, blu con la fascia bianca (il capo la
    ha d'oro: "stunt_stripe" si cambia in gioco), la punta del muso rossa e il
    tettuccio a goccia. Davanti +Y, origine al centro della fusoliera."""
    reset()
    parts = [block("fuselage", [(-0.5, -2.4, -0.45), (0.5, -2.4, -0.45), (0.5, 2.2, -0.45), (-0.5, 2.2, -0.45)],
                   [(-0.45, -2.4, 0.42), (0.45, -2.4, 0.42), (0.45, 2.2, 0.38), (-0.45, 2.2, 0.38)], "stunt")]
    parts.append(block("nose", [(-0.5, 2.2, -0.45), (0.5, 2.2, -0.45), (0.12, 3.0, -0.1), (-0.12, 3.0, -0.1)],
                       [(-0.45, 2.2, 0.38), (0.45, 2.2, 0.38), (0.1, 3.0, 0.05), (-0.1, 3.0, 0.05)], "stunt_tip"))
    parts.append(block("tail_cone", [(-0.5, -2.4, -0.45), (0.5, -2.4, -0.45), (0.25, -3.0, -0.1), (-0.25, -3.0, -0.1)],
                       [(-0.45, -2.4, 0.42), (0.45, -2.4, 0.42), (0.22, -3.0, 0.3), (-0.22, -3.0, 0.3)], "stunt"))
    parts.append(block("canopy", [(-0.36, 0.0, 0.4), (0.36, 0.0, 0.4), (0.32, 1.7, 0.38), (-0.32, 1.7, 0.38)],
                       [(-0.2, 0.3, 0.8), (0.2, 0.3, 0.8), (0.16, 1.2, 0.75), (-0.16, 1.2, 0.75)], "glass"))
    parts += mirrored_box("stripe", 0.5, 0.52, -2.3, 2.1, -0.05, 0.15, "stunt_stripe")
    for side in (1, -1):
        parts.append(block("wing_%d" % side, [(side * 0.5, 0.9, -0.3), (side * 2.8, -0.4, -0.25), (side * 2.8, -1.0, -0.25), (side * 0.5, -1.0, -0.3)],
                           [(side * 0.5, 0.9, -0.12), (side * 2.8, -0.4, -0.15), (side * 2.8, -1.0, -0.15), (side * 0.5, -1.0, -0.12)], "stunt"))
        parts.append(box("tip_%d" % side, side * 2.72 - 0.08, side * 2.72 + 0.08, -1.0, -0.35, -0.3, -0.08, "stunt_tip"))
        parts.append(block("stab_%d" % side, [(side * 0.3, -2.4, 0.15), (side * 1.3, -2.9, 0.15), (side * 1.3, -3.1, 0.15), (side * 0.3, -3.0, 0.15)],
                           [(side * 0.3, -2.4, 0.25), (side * 1.3, -2.9, 0.22), (side * 1.3, -3.1, 0.22), (side * 0.3, -3.0, 0.25)], "stunt"))
    parts.append(block("fin", [(-0.05, -3.0, 0.3), (0.05, -3.0, 0.3), (0.05, -2.0, 0.4), (-0.05, -2.0, 0.4)],
                       [(-0.05, -3.1, 1.4), (0.05, -3.1, 1.4), (0.05, -2.7, 1.4), (-0.05, -2.7, 1.4)], "stunt_stripe"))
    parts.append(box("nozzle", -0.22, 0.22, -3.08, -3.0, -0.1, 0.25, "trim"))
    join("StuntPlane", parts)
    save("stunt_plane")


def build_eagle():
    """L'aquila del cielo, al posto del coccodrillo e con la sua stessa
    collisione (1,4 x 0,8 x 6 m): la schiena è una piattaforma, il becco morde.
    Corpo bruno, testa bianca, becco giallo uncinato; il becco superiore (Jaw)
    ruota sul suo attacco e Godot lo apre come la mascella del coccodrillo; le
    ali (WingL, WingR) hanno il perno alla spalla e Godot le fa battere.
    Davanti +Y, origine al centro."""
    reset()
    parts = []
    # Il corpo: dal collo alla coda, la schiena piatta in cima (z 0,38).
    sections = [(1.4, 0.45, -0.3, 0.3), (0.6, 0.62, -0.4, 0.38), (-0.6, 0.58, -0.38, 0.38),
                (-1.5, 0.4, -0.28, 0.3), (-1.9, 0.28, -0.18, 0.2)]
    for i in range(len(sections) - 1):
        y0, w0, b0, t0 = sections[i]
        y1, w1, b1, t1 = sections[i + 1]
        parts.append(block("body_%d" % i,
                           [(-w0 * 0.8, y0, b0), (w0 * 0.8, y0, b0), (w1 * 0.8, y1, b1), (-w1 * 0.8, y1, b1)],
                           [(-w0, y0, t0), (w0, y0, t0), (w1, y1, t1), (-w1, y1, t1)],
                           "eagle"))
    # La coda a ventaglio, con la punta scura.
    parts.append(block("tail", [(-0.28, -1.9, 0.02), (0.28, -1.9, 0.02), (0.75, -2.8, 0.0), (-0.75, -2.8, 0.0)],
                       [(-0.28, -1.9, 0.16), (0.28, -1.9, 0.16), (0.75, -2.8, 0.08), (-0.75, -2.8, 0.08)], "eagle"))
    parts.append(block("tail_tip", [(-0.75, -2.8, 0.0), (0.75, -2.8, 0.0), (0.8, -3.0, 0.0), (-0.8, -3.0, 0.0)],
                       [(-0.75, -2.8, 0.08), (0.75, -2.8, 0.08), (0.8, -3.0, 0.06), (-0.8, -3.0, 0.06)], "eagle_dark"))
    # La testa bianca e il becco inferiore.
    parts.append(block("neck", [(-0.36, 1.4, -0.28), (0.36, 1.4, -0.28), (0.3, 1.8, -0.22), (-0.3, 1.8, -0.22)],
                       [(-0.45, 1.4, 0.3), (0.45, 1.4, 0.3), (0.34, 1.8, 0.42), (-0.34, 1.8, 0.42)], "eagle_head"))
    parts.append(block("head", [(-0.3, 1.8, -0.22), (0.3, 1.8, -0.22), (0.22, 2.3, -0.12), (-0.22, 2.3, -0.12)],
                       [(-0.34, 1.8, 0.42), (0.34, 1.8, 0.42), (0.24, 2.3, 0.3), (-0.24, 2.3, 0.3)], "eagle_head"))
    parts.append(block("beak_low", [(-0.14, 2.3, -0.1), (0.14, 2.3, -0.1), (0.05, 2.75, -0.02), (-0.05, 2.75, -0.02)],
                       [(-0.14, 2.3, 0.04), (0.14, 2.3, 0.04), (0.05, 2.75, 0.02), (-0.05, 2.75, 0.02)], "beak"))
    # Gli occhi feroci, con la fronte sporgente sopra.
    for side in (1, -1):
        parts.append(ico("eye_%d" % side, 0.09, (side * 0.27, 2.05, 0.24), "eagle_eye"))
        parts.append(box("pupil_%d" % side, side * 0.27 - 0.03, side * 0.27 + 0.03, 2.1, 2.14, 0.2, 0.28, "pupil"))
        parts.append(block("brow_%d" % side, [(side * 0.12, 1.9, 0.3), (side * 0.36, 1.9, 0.28), (side * 0.32, 2.2, 0.3), (side * 0.12, 2.2, 0.32)],
                           [(side * 0.12, 1.9, 0.42), (side * 0.36, 1.9, 0.38), (side * 0.32, 2.2, 0.36), (side * 0.12, 2.2, 0.38)], "eagle_head"))
    # Le zampe gialle raccolte sotto la pancia, con gli artigli scuri.
    for side in (1, -1):
        parts.append(box("leg_%d" % side, side * 0.15, side * 0.32, -0.9, -0.5, -0.55, -0.3, "beak"))
        for k in range(3):
            parts.append(cone("claw_%d_%d" % (side, k), 0.04, 0.16, (side * (0.17 + k * 0.06), -0.45, -0.55), "pupil", sides=4))
    join("Body", parts)

    # Il becco superiore uncinato: il perno al suo attacco.
    jaw = [block("beak_up", [(-0.16, 2.25, 0.02), (0.16, 2.25, 0.02), (0.06, 2.85, 0.0), (-0.06, 2.85, 0.0)],
                 [(-0.15, 2.25, 0.24), (0.15, 2.25, 0.24), (0.05, 2.85, 0.12), (-0.05, 2.85, 0.12)], "beak")]
    hook = cone("hook", 0.07, 0.22, (0, 2.88, -0.02), "beak", sides=4)
    hook.rotation_euler = (math.pi, 0, 0)
    jaw.append(hook)
    part("Jaw", jaw, (0, 2.25, 0.04))

    # Le ali aperte: piatte, con le remiganti scure come dita in punta.
    for name, side in (("WingL", -1), ("WingR", 1)):
        wing = [block("wing_%d" % side,
                      [(side * 0.45, 1.0, 0.1), (side * 3.4, 0.8, 0.1), (side * 3.4, -0.6, 0.1), (side * 0.45, -0.4, 0.1)],
                      [(side * 0.45, 1.0, 0.24), (side * 3.4, 0.8, 0.18), (side * 3.4, -0.6, 0.18), (side * 0.45, -0.4, 0.24)],
                      "eagle")]
        wing.append(block("covert_%d" % side,
                          [(side * 0.45, 1.0, 0.24), (side * 2.6, 0.85, 0.18), (side * 2.6, 0.3, 0.18), (side * 0.45, 0.4, 0.24)],
                          [(side * 0.45, 1.0, 0.3), (side * 2.6, 0.85, 0.24), (side * 2.6, 0.3, 0.24), (side * 0.45, 0.4, 0.3)],
                          "eagle_dark"))
        for k in range(4):
            y = 0.65 - k * 0.38
            spread = k * 0.12
            wing.append(block("primary_%d_%d" % (side, k),
                              [(side * 3.4, y, 0.12), (side * (4.3 - spread * 0.5), y - 0.05 - spread, 0.12), (side * (4.3 - spread * 0.5), y - 0.25 - spread, 0.12), (side * 3.4, y - 0.3, 0.12)],
                              [(side * 3.4, y, 0.17), (side * (4.3 - spread * 0.5), y - 0.05 - spread, 0.15), (side * (4.3 - spread * 0.5), y - 0.25 - spread, 0.15), (side * 3.4, y - 0.3, 0.17)],
                              "eagle_dark"))
        part(name, wing, (side * 0.45, 0.3, 0.17))
    save("eagle")


def build_mountain():
    reset()
    parts = [cone("rock", 40.0, 36.0, (0, 0, 18.0), "mountain", sides=7)]
    parts.append(cone("snow", 12.5, 11.0, (0, 0, 30.5), "mountain_snow", sides=7))
    join("Mountain", parts)
    save("mountain")


BUILDERS = {
    "compact": build_compact, "sedan": build_sedan, "van": build_van, "truck": build_truck,
    "frog": build_frog, "den": build_den, "den_sky": build_den_sky, "log": build_log, "crocodile": build_crocodile, "eagle": build_eagle, "stunt_plane": build_stunt_plane, "ultralight": build_ultralight, "helicopter": build_helicopter,
    "balloon": build_balloon, "blimp": build_blimp, "glider": build_glider, "tree": build_tree, "house": build_house, "lamp": build_lamp,
    "mountain": build_mountain, "locomotive": build_locomotive, "boxcar": build_boxcar,
    "flatcar": build_flatcar, "cablecar_front": build_cablecar_front, "cablecar": build_cablecar,
    "cablecar_open": build_cablecar_open, "cable_pylon": build_cable_pylon, "signal": build_signal, "airplane": build_airplane, "airplane_prop": build_airplane_prop,
    "crane": build_crane, "crane_trolley": build_crane_trolley, "ship": build_ship, "airship": build_airship, "skycrane": build_skycrane,
    "container": build_container, "tug": build_tug, "dolly": build_dolly,
    "suitcase": build_suitcase, "parcel": build_parcel,
    "frog_raganella": build_frog_raganella, "frog_paracadutista": build_frog_paracadutista,
    "frog_fiume": build_frog_fiume, "frog_camaleonte": build_frog_camaleonte,
    "frog_rospo": build_frog_rospo, "hat_hard_hat": build_hat_hard_hat, "hat_goggles": build_hat_goggles,
    "hat_straw": build_hat_straw, "hat_cap": build_hat_cap, "hat_top_hat": build_hat_top_hat,
    "hat_crown": build_hat_crown, "hat_cowboy": build_hat_cowboy, "hat_beanie": build_hat_beanie,
    "hat_chef": build_hat_chef, "hat_pirate": build_hat_pirate, "hat_fez": build_hat_fez,
    "hat_propeller": build_hat_propeller,
}

if __name__ == "__main__":
    wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(BUILDERS)
    for model in wanted:
        BUILDERS[model]()
