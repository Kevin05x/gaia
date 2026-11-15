# Cristales, hielo y minerales (assets/modelos/): normales hacia fuera (había caras al revés que se veían negras),
# sombreado plano y materiales coherentes con el terreno. Misma caja y mismo nodo raíz (el juego los escala por su caja).
# uso: blender -b --factory-startup -P reparar_minerales.py -- [--export]
import os, sys
SP = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SP)
from comun import *
import bpy, bmesh

EXPORT = '--export' in sys.argv
RENDER = os.path.join(SP, "render")
MODELOS = ["cristal", "cristal2", "cristal3_rojo", "cristal5_brillo", "hielo_2", "hielo_3", "mineral_2"]


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


# familia de material -> (color lineal o None para conservarlo, rugosidad, metal)
MATS = {
    "cristal": (None, 0.12, 0.0),                    # el color identifica el mineral: no se toca
    "rock": (srgb("#A47C5F"), 0.9, 0.0),             # roca de la paleta del terreno (antes naranja chillón)
    "rockTrack": (srgb("#B08A6A"), 0.92, 0.0),
    "crystal": (srgb("#CFE8F5"), 0.08, 0.0),         # hielo: blanco azulado (antes verde)
    "Material": None,                                # mineral_2: se decide por el color
}


def materiales():
    for m in bpy.data.materials:
        b = m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
        if b is None:
            continue
        fam = m.name.split('.')[0]
        if fam == "Material":  # mineral_2: roca rojiza y vetas oscuras
            c = b.inputs['Base Color'].default_value
            oscuro = (c[0] + c[1] + c[2]) / 3 < 0.25 and abs(c[0] - c[1]) < 0.05
            b.inputs['Roughness'].default_value = 0.55 if oscuro else 0.88
            b.inputs['Metallic'].default_value = 0.1 if oscuro else 0.0
            continue
        if fam not in MATS or MATS[fam] is None:
            continue
        color, rug, met = MATS[fam]
        if color:
            b.inputs['Base Color'].default_value = (*color, 1)
        b.inputs['Roughness'].default_value = rug
        b.inputs['Metallic'].default_value = met


def normales():
    invertidas = 0
    for o in bpy.context.scene.objects:
        if o.type != 'MESH':
            continue
        me = o.data
        if me.has_custom_normals:
            bpy.context.view_layer.objects.active = o
            o.select_set(True)
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
            o.select_set(False)
        bm = bmesh.new()
        bm.from_mesh(me)
        antes = [f.normal.copy() for f in bm.faces]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        invertidas += sum(1 for f, a in zip(bm.faces, antes) if f.normal.dot(a) < 0)
        for f in bm.faces:
            f.smooth = False
        bm.to_mesh(me)
        bm.free()
    return invertidas


for n in MODELOS:
    limpiar()
    importar(os.path.join(MOD, n + ".glb"))
    raices = sorted(o.name for o in bpy.context.scene.objects if o.parent is None)
    mn, mx = caja()
    t0 = tris()
    inv = normales()
    materiales()
    mn2, mx2 = caja()
    tol = 0.01 * max(mx - mn)
    ok = all(abs(a - b) <= tol for a, b in zip(list(mn) + list(mx), list(mn2) + list(mx2))) and \
        raices == sorted(o.name for o in bpy.context.scene.objects if o.parent is None) and tris() == t0
    print("INFORME", n, "tris", t0, "caras giradas", inv, "caja", tuple(round(v, 3) for v in mx - mn), "OK", ok)
    os.makedirs(RENDER, exist_ok=True)
    render(os.path.join(RENDER, n + "_reparado.png"))
    if EXPORT and ok:
        bpy.ops.export_scene.gltf(filepath=os.path.join(MOD, n + ".glb"), export_format='GLB',
                                  export_draco_mesh_compression_enable=False, export_yup=True,
                                  export_cameras=False, export_lights=False, use_selection=False)
        print("EXPORTADO", n)
