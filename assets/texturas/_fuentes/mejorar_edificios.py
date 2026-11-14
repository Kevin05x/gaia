# Mejora de los edificios del equipo (Kenney Space Kit / KayKit Space Base Bits, CC0) sin cambiar su caja.
# uso: blender -b --factory-startup -P mejorar_edificios.py -- [--export] [nombres...]
import os, sys
SP = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SP)
from comun import *
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
EXPORT = '--export' in args
pedidos = [a for a in args if not a.startswith('--')] or NOMBRES
MAX_TRIS = 2500


# ---------- materiales
def mat_emisivo(nombre, color, fuerza, base=(0.03, 0.035, 0.045)):
    m = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*base, 1)
    b.inputs['Roughness'].default_value = 0.2
    b.inputs['Metallic'].default_value = 0.0
    b.inputs['Emission Color'].default_value = (*color, 1)
    b.inputs['Emission Strength'].default_value = fuerza
    return m


def emisivos():
    return {"ventana": mat_emisivo("emisivo_ventana", (1.0, 0.50, 0.18), 1.2),
            "luz": mat_emisivo("emisivo_luz", (0.85, 0.93, 1.0), 1.8, (0.6, 0.62, 0.65)),
            "baliza": mat_emisivo("emisivo_baliza", (1.0, 0.10, 0.05), 1.8, (0.3, 0.03, 0.02))}


# Tinte de polvo marciano (multiplica el color lineal) y PBR (metal, rugosidad) por familia de material
PBR = {"metal": ((0.93, 0.86, 0.78), 0.0, 0.78), "metalDark": ((0.95, 0.90, 0.84), 0.35, 0.58),
       "dark": ((1.0, 0.95, 0.90), 0.05, 0.8), "metalRed": ((0.95, 0.88, 0.80), 0.1, 0.65),
       "spacebits_texture": (None, 0.1, 0.7)}


def pbr():
    for m in bpy.data.materials:
        if not m.use_nodes or m.name.startswith('emisivo_'):
            continue
        fam = m.name.split('.')[0]
        if fam not in PBR:
            continue
        tinte, met, rou = PBR[fam]
        b = m.node_tree.nodes.get('Principled BSDF')
        if b is None:
            continue
        if tinte and not b.inputs['Base Color'].is_linked:
            c = b.inputs['Base Color'].default_value
            b.inputs['Base Color'].default_value = (c[0] * tinte[0], c[1] * tinte[1], c[2] * tinte[2], 1)
        b.inputs['Metallic'].default_value = met
        b.inputs['Roughness'].default_value = rou


def mat_por_familia(fam):
    for m in bpy.data.materials:
        if m.name.split('.')[0] == fam:
            return m


# ---------- geometría
def raiz():
    return [o for o in bpy.context.scene.objects if o.parent is None and o.type == 'MESH'][0]


def ray(o, d):
    dg = bpy.context.evaluated_depsgraph_get()
    hit, loc, nor, _, ob, _ = bpy.context.scene.ray_cast(dg, Vector(o), Vector(d).normalized())
    return (loc, nor, ob) if hit else None


PIEZAS = []  # (matriz mundo, tamaño, material)


def caja_orientada(loc, normal, tam, mat, hundir=0.0, arriba=Vector((0, 0, 1))):
    """Caja de tamaño tam=(ancho, alto, grosor) apoyada en la superficie (loc, normal); hundir la mete en ella."""
    z = Vector(normal).normalized()
    y = arriba - arriba.dot(z) * z
    if y.length < 1e-3:
        y = Vector((0, 1, 0)) - Vector((0, 1, 0)).dot(z) * z
    y.normalize()
    x = y.cross(z)
    c = Vector(loc) + z * (tam[2] / 2 - hundir)
    M = Matrix((x, y, z)).transposed().to_4x4()
    M.translation = c
    PIEZAS.append((M, tam, mat))


def construir(nombre_obj, padre):
    if not PIEZAS:
        return None
    me = bpy.data.meshes.new(nombre_obj)
    bm = bmesh.new()
    mats = []
    for M, tam, mat in PIEZAS:
        if mat not in mats:
            mats.append(mat)
        r = bmesh.ops.create_cube(bm, size=1.0)
        vs = r['verts']
        bmesh.ops.scale(bm, vec=Vector(tam), verts=vs)
        bmesh.ops.transform(bm, matrix=M, verts=vs)
        for f in {f for v in vs for f in v.link_faces}:
            f.material_index = mats.index(mat)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(nombre_obj, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = padre
    ob.matrix_parent_inverse = padre.matrix_world.inverted()
    PIEZAS.clear()
    return ob


def frac(mn, mx, fx, fy, fz):
    return Vector((mn.x + (mx.x - mn.x) * fx, mn.y + (mx.y - mn.y) * fy, mn.z + (mx.z - mn.z) * fz))


def anillo(c, z, n, a0, radio_ext=30):
    """Rayos horizontales hacia el eje vertical que pasa por c."""
    for i in range(n):
        a = math.radians(a0) + 2 * math.pi * i / n
        d = Vector((math.cos(a), math.sin(a), 0))
        o = Vector((c.x, c.y, z)) + d * radio_ext
        yield i, d, ray(o, -d)


# ---------- por modelo
def hangar_cuadrado(E, mn, mx):
    for lado in (-1, 1):  # ventanas en los muros laterales (±x)
        for fy in (0.17, 0.30, 0.70, 0.83):
            o = frac(mn, mx, 0.5, fy, 0.40)
            o.x = (mn.x - 2) if lado < 0 else (mx.x + 2)
            h = ray(o, (-lado, 0, 0))
            if h:
                caja_orientada(h[0], h[1], (1.3, 0.6, 0.04), E["ventana"], hundir=0.015)
    for lado in (-1, 1):  # luz sobre cada portón y balizas a los lados
        o = frac(mn, mx, 0.5, 0.5, 0.86)
        o.y = (mn.y - 2) if lado < 0 else (mx.y + 2)
        h = ray(o, (0, -lado, 0))
        if h:
            caja_orientada(h[0], h[1], (3.2, 0.18, 0.06), E["luz"], hundir=0.055)
        for fx in (0.1, 0.9):
            o = frac(mn, mx, fx, 0.5, 0.25)
            o.y = (mn.y - 2) if lado < 0 else (mx.y + 2)
            h = ray(o, (0, -lado, 0))
            if h:
                caja_orientada(h[0], h[1], (0.25, 0.25, 0.06), E["luz"], hundir=0.055)
    dark = mat_por_familia("dark")
    mdark = mat_por_familia("metalDark")
    for fy in (0.2, 0.8):  # paneles solares y rejilla en los techos blancos (por debajo de la franja alta)
        for fx in (0.33, 0.67):
            o = frac(mn, mx, fx, fy, 1.0)
            o.z += 2
            h = ray(o, (0, 0, -1))
            if h and h[0].z + 0.12 < mx.z - 0.02:
                caja_orientada(h[0], h[1], (2.4, 1.7, 0.08), dark, arriba=Vector((0, 1, 0)))
        o = frac(mn, mx, 0.5, fy, 1.0)
        o.z += 2
        h = ray(o, (0, 0, -1))
        if h and h[0].z + 0.35 < mx.z - 0.02:
            caja_orientada(h[0], h[1], (0.7, 0.7, 0.3), mdark, arriba=Vector((0, 1, 0)))


def hangar_roundA(E, mn, mx):
    c = (mn + mx) / 2
    H = mx.z - mn.z
    for i, d, h in anillo(c, mn.z + H * 0.47, 8, 22.5):  # anillo de ventanas en la franja blanca
        if h:
            caja_orientada(h[0], h[1], (1.3, 0.45, 0.04), E["ventana"], hundir=0.015)
    for i, d, h in anillo(c, mn.z + H * 0.13, 4, 45):  # luces bajas en la base
        if h:
            caja_orientada(h[0], h[1], (0.35, 0.2, 0.05), E["luz"], hundir=0.02)
    h = ray(Vector((c.x, c.y, mx.z + 2)), (0, 0, -1))
    if h:
        caja_orientada(h[0], h[1], (0.4, 0.4, 0.04), E["luz"], hundir=0.04)


def foco(E, mn, mx):
    c = (mn + mx) / 2
    R = (mx.x - mn.x) / 2
    H = mx.z - mn.z
    for i in range(48):  # busca la cara inferior de los brazos con rayos hacia arriba
        a = 2 * math.pi * i / 48
        d = Vector((math.cos(a), math.sin(a), 0))
        for rf in (0.80, 0.55):
            o = Vector((c.x, c.y, mn.z + H * 0.55)) + d * R * rf
            h = ray(o, (0, 0, 1))
            if h and h[0].z > mn.z + H * 0.8 and h[1].z < -0.5:
                caja_orientada(h[0], h[1], (0.32, 0.32, 0.04), E["luz"], hundir=0.015, arriba=d)


def taladro(E, mn, mx):
    c = (mn + mx) / 2
    H = mx.z - mn.z
    for i, d, h in anillo(c, mn.z + H * 0.90, 8, 22.5):  # luces de estado alrededor de la cabeza
        if h and abs(h[1].z) < 0.6:
            caja_orientada(h[0], h[1], (0.35, 0.16, 0.05), E["luz"] if i % 2 else E["baliza"], hundir=0.02)
    for i, d, h in anillo(c, mn.z + H * 0.55, 16, 0):  # ventanas del módulo central, entre las patas
        if h and h[2].name.startswith('drill_module') and abs(h[1].z) < 0.5:
            caja_orientada(h[0], h[1], (0.45, 0.7, 0.04), E["ventana"], hundir=0.015)


def anthena_juego(E, mn, mx):
    for o in bpy.context.scene.objects:  # la punta del alimentador (_defaultMat, 4 caras) pasa a baliza
        for s in getattr(o, 'material_slots', []):
            if s.material and s.material.name == '_defaultMat':
                s.material = E["luz"]
    c = (mn + mx) / 2
    H = mx.z - mn.z
    for i, d, h in anillo(c, mn.z + H * 0.06, 4, 45):
        if h:
            caja_orientada(h[0], h[1], (0.5, 0.3, 0.05), E["luz"], hundir=0.02)


def torreta(E, mn, mx):
    c = (mn + mx) / 2
    H = mx.z - mn.z
    for i, d, h in anillo(c, mn.z + H * 0.06, 4, 45):
        if h:
            caja_orientada(h[0], h[1], (0.3, 0.15, 0.04), E["luz"], hundir=0.02)
    h = ray(Vector((c.x, c.y, mx.z + 3)), (0, 0, -1))
    if h and h[1].z > 0.7:
        caja_orientada(h[0], h[1], (0.25, 0.25, 0.04), E["baliza"], hundir=0.04)


FUN = {"hangar_cuadrado": hangar_cuadrado, "hangar_roundA": hangar_roundA, "foco": foco, "taladro": taladro,
       "anthena_juego": anthena_juego, "torreta_simple": torreta, "torreta_doble": torreta}


def mats_usados():
    return {m.name for o in bpy.context.scene.objects if o.type == 'MESH' for m in o.data.materials if m} | \
           {s.material.name for o in bpy.context.scene.objects for s in getattr(o, 'material_slots', []) if s.material}


def ajustar_emision(k):
    for m in bpy.data.materials:
        if m.name.startswith('emisivo_'):
            m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value *= k


# ---------- proceso con invariantes
informe = []
for n in pedidos:
    limpiar()
    importar(os.path.join(MOD, n + ".glb"))
    if any(m.name.startswith('emisivo_') for m in bpy.data.materials):
        # Ya mejorado: el script se aplica sobre los originales de los kits (git show 505e2a0:assets/modelos/<nombre>.glb)
        print("YA MEJORADO, se omite", n)
        continue
    r = raiz()
    xf0 = r.matrix_world.copy()
    nombre0 = r.name
    mn, mx = caja()
    t0 = tris()
    nmat0 = len(mats_usados())
    E = emisivos()
    FUN[n](E, mn, mx)
    construir("detalles_arte", r)
    pbr()
    mn2, mx2 = caja()
    t1 = tris()
    usados = mats_usados()
    tol = 0.01 * max(mx - mn)
    ok_caja = all(abs(a - b) <= tol for a, b in zip(list(mn) + list(mx), list(mn2) + list(mx2)))
    ok_raiz = r.name == nombre0 and all(abs(a - b) < 1e-6 for ra, rb in zip(r.matrix_world, xf0) for a, b in zip(ra, rb))
    ok = ok_caja and ok_raiz and t1 <= MAX_TRIS
    emis = sorted(u for u in usados if u.startswith('emisivo_'))
    linea = (f"{n}: tris {t0}->{t1} | caja {tuple(round(v, 3) for v in mx - mn)} -> {tuple(round(v, 3) for v in mx2 - mn2)}"
             f" | mats {nmat0}->{len(usados)} {emis} | caja={ok_caja} raiz={ok_raiz} OK={ok}")
    print("INFORME", linea)
    informe.append(linea)
    ajustar_emision(0.25)  # brillo diurno que aplica buildings.gd
    render(os.path.join(SP, "render", n + "_dia.png"))
    ajustar_emision(4.0)
    ajustar_emision(1.75)  # brillo nocturno que aplica buildings.gd (0,25 + 1,5 × noche)
    render(os.path.join(SP, "render", n + "_noche.png"), noche=True)
    ajustar_emision(1 / 1.75)
    if EXPORT and ok:
        bpy.ops.export_scene.gltf(filepath=os.path.join(MOD, n + ".glb"), export_format='GLB',
                                  export_draco_mesh_compression_enable=False, export_yup=True,
                                  export_cameras=False, export_lights=False, use_selection=False)
        print("EXPORTADO", n)
    elif EXPORT:
        print("NO EXPORTADO (invariante)", n)
open(os.path.join(SP, "informe_edificios.txt"), "w", encoding="utf8").write("\n".join(informe))
