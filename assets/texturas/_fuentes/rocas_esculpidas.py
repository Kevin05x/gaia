# Rocas esculpidas (no convexas, erosionadas) para las familias grandes del decorado: block, boulder, outcrop y cliff,
# 4 variantes de cada una, en assets/modelos/rocas_esculpidas.glb (objetos «familia_variante»). El juego las ajusta a
# la caja de la roca procedural que sustituyen (world_art.gd), así que el tamaño de cada obstáculo no cambia.
# Cada vértice lleva un tono gris (variación y, en cantos y acantilados, estratos) que el juego multiplica por su color.
# uso: blender -b --factory-startup -P rocas_esculpidas.py
import bpy, bmesh, math, os, numpy as np
from mathutils import Vector

SALIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "modelos", "rocas_esculpidas.glb")
OBJETIVO_TRIS = 300
FAMILIAS = {  # proporciones, cortes planos (fracturas), estratos, aplanado de la base
    "block": {"escala": (1.0, 0.8, 0.95), "cortes": 7, "estratos": False, "base": -0.3},
    "boulder": {"escala": (1.0, 0.9, 0.9), "cortes": 4, "estratos": True, "base": -0.15},
    "outcrop": {"escala": (1.7, 0.7, 0.95), "cortes": 6, "estratos": True, "base": -0.2},
    "cliff": {"escala": (1.4, 1.05, 1.15), "cortes": 8, "estratos": True, "base": -0.3},
}


def ruido(p, semilla, octavas=4):
    """Ruido de valor 3D suave (suma de senos rotados, determinista y sin dependencias)."""
    r = np.random.default_rng(semilla)
    total = np.zeros(len(p))
    amp, frec = 1.0, 1.6
    for _ in range(octavas):
        d = r.normal(size=(3, 3))
        q, _ = np.linalg.qr(d)
        fase = r.uniform(0, math.tau, 3)
        pr = p @ q * frec
        total += amp * (np.sin(pr[:, 0] + fase[0]) * np.sin(pr[:, 1] + fase[1]) * np.sin(pr[:, 2] + fase[2]))
        amp *= 0.5
        frec *= 2.1
    return total


def roca(familia, variante):
    datos = FAMILIAS[familia]
    semilla = sum(map(ord, familia)) * 31 + 7 * variante  # estable entre ejecuciones (hash() de texto no lo es)
    r = np.random.default_rng(semilla)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=1.0)
    ob = bpy.context.active_object
    ob.name = "%s_%d" % (familia, variante)
    me = ob.data
    v = np.array([vv.co[:] for vv in me.vertices])
    n = v / np.linalg.norm(v, axis=1, keepdims=True)
    # bultos grandes y medianos, y grietas finas (ruido «ridged»)
    desp = 0.22 * ruido(n, semilla, 3) + 0.06 * ruido(n * 2.3, semilla + 1, 3)
    grieta = 1 - np.abs(ruido(n * 3.1, semilla + 2, 2))
    desp -= 0.05 * grieta ** 6
    v = n * (1.0 + desp)[:, None]
    # fracturas: planos al azar que «cortan» la roca (caras planas de arista viva, típicas de una roca partida)
    for _ in range(datos["cortes"]):
        normal = r.normal(size=3)
        normal[1] *= 0.6
        normal /= np.linalg.norm(normal)
        dist = r.uniform(0.62, 0.9)
        proy = v @ normal
        fuera = proy > dist
        v[fuera] -= np.outer(proy[fuera] - dist, normal)
    # estratos: escalones suaves en altura (capas sedimentarias)
    if datos["estratos"]:
        capas = r.uniform(5, 8)
        y = v[:, 1] * capas
        escalon = np.floor(y) + np.clip((y - np.floor(y) - 0.75) * 4, 0, 1)
        v[:, 1] = np.where(v[:, 1] > -0.1, (escalon / capas) * 0.6 + v[:, 1] * 0.4, v[:, 1])
        retranqueo = 1 - 0.06 * np.clip((y - np.floor(y)) * 3, 0, 1)
        v[:, 0] *= retranqueo
        v[:, 2] *= retranqueo
    v *= np.array(datos["escala"])
    v[:, 1] = np.maximum(v[:, 1], datos["base"])  # base plana: apoya en el suelo
    for i, vv in enumerate(me.vertices):
        vv.co = Vector((v[i, 0], -v[i, 2], v[i, 1]))  # se esculpe con Y arriba; Blender usa Z arriba
    # reducir a ~OBJETIVO_TRIS triángulos conservando la silueta
    dec = ob.modifiers.new("dec", 'DECIMATE')
    dec.ratio = OBJETIVO_TRIS / (len(me.polygons))
    bpy.ops.object.modifier_apply(modifier="dec")
    # sombreado: suave salvo en aristas vivas (fracturas)
    for p in me.polygons:
        p.use_smooth = True
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(38))
    except Exception:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(38))
    # tono por vértice: variación y estratos; las grietas y la base, más oscuras
    color = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    pts = np.array([vv.co[:] for vv in me.vertices])[:, [0, 2, 1]]  # de vuelta a Y arriba
    tono = 0.95 + 0.08 * ruido(pts * 1.5, semilla + 3, 3)
    if datos["estratos"]:
        tono *= np.array([1.0, 0.86, 1.06, 0.92, 1.03])[(np.floor((pts[:, 1] + 1) * 6)).astype(int) % 5]
    tono *= 0.8 + 0.2 * np.clip((pts[:, 1] - datos["base"]) / 0.4, 0, 1)
    for i in range(len(me.vertices)):
        color.data[i].color = (tono[i], tono[i], tono[i], 1.0)
    ob.location = (variante * 3.5, list(FAMILIAS).index(familia) * 3.5, 0)  # separadas en el suelo (el juego usa su malla local)
    return ob


bpy.ops.wm.read_factory_settings(use_empty=True)
for familia in FAMILIAS:
    for variante in range(4):
        o = roca(familia, variante)
        print("ROCA", o.name, "tris", sum(len(p.vertices) - 2 for p in o.data.polygons))
bpy.ops.export_scene.gltf(filepath=os.path.normpath(SALIDA), export_format='GLB', export_draco_mesh_compression_enable=False,
                          export_yup=True, export_cameras=False, export_lights=False, use_selection=False,
                          export_vertex_color='ACTIVE', export_all_vertex_colors=True, export_materials='NONE')
print("EXPORTADO", os.path.normpath(SALIDA))
