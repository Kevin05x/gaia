# Nido de los monstruos como caverna que sale del suelo: montículo de roca oscura con una boca que se hunde en diagonal,
# espolones de roca, sacos de huevos con brillo violeta y telarañas (láminas con textura de tela, recorte por alfa).
# Sale a assets/modelos/nido_caverna.glb. Materiales: nido_roca (color por vértice), nido_interior, nido_telarana y
# emisivo_nido (el brillo que late; combat_view.gd lo busca por nombre). Fauna y nido son ficticios (decisión de diseño).
# uso: blender -b --factory-startup -P nido_caverna.py
import bpy, bmesh, math, os, numpy as np
from mathutils import Vector, Matrix

SALIDA = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "modelos", "nido_caverna.glb"))
rng = np.random.default_rng(666)


def ruido(p, semilla, octavas=4):
    r = np.random.default_rng(semilla)
    total = np.zeros(len(p))
    amp, frec = 1.0, 1.4
    for _ in range(octavas):
        q, _ = np.linalg.qr(r.normal(size=(3, 3)))
        fase = r.uniform(0, math.tau, 3)
        pr = p @ q * frec
        total += amp * np.sin(pr[:, 0] + fase[0]) * np.sin(pr[:, 1] + fase[1]) * np.sin(pr[:, 2] + fase[2])
        amp *= 0.5
        frec *= 2.1
    return total


def material(nombre, color, rugosidad=0.9, emision=None, fuerza=0.0):
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rugosidad
    if emision:
        b.inputs['Emission Color'].default_value = (*emision, 1)
        b.inputs['Emission Strength'].default_value = fuerza
    return m


def textura_telarana(T=512):
    """Tela de araña: radios desde un centro descentrado y espiral, con hilos algo combados. RGBA (alfa = hilo)."""
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32) / T
    cx, cy = 0.46, 0.52
    dx, dy = xx - cx, yy - cy
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    radios = 9
    a = (ang / math.tau * radios) % 1.0
    dist_radial = np.minimum(a, 1 - a) * math.tau * r * T / radios  # distancia al radio más cercano, en píxeles
    hilo_radial = np.clip(1 - dist_radial / 6.0, 0, 1)  # hilos gruesos (~12 px): se leen de lejos
    vuelta = (r * 10 - ang / math.tau + 0.03 * np.sin(ang * radios)) % 1.0  # espiral de captura, combada entre radios
    hilo_espiral = np.clip(1 - np.minimum(vuelta, 1 - vuelta) * (T / 10) / 5.0, 0, 1)
    velo = 0.22 * np.clip(1 - r / 0.4, 0, 1) * (0.7 + 0.3 * np.sin(ang * 3 + r * 20))  # velo de seda lechoso entre hilos
    tela = np.maximum.reduce([hilo_radial, hilo_espiral * (r > 0.05), velo])
    roto = ruido(np.stack([xx.ravel() * 6, yy.ravel() * 6, np.zeros(T * T)], 1), 3, 3).reshape(T, T)
    tela *= np.clip(1.0 - (r - 0.32) * 6, 0, 1) * (roto > -0.55)  # borde deshilachado y algún hueco roto
    px = np.ones((T, T, 4), np.float32)
    px[..., :3] = 0.92
    px[..., 3] = np.clip(tela * 1.6, 0, 0.9)
    img = bpy.data.images.new("telarana", T, T, alpha=True)
    img.pixels.foreach_set(px.ravel())
    print("TELA alfa media", float(px[..., 3].mean()), "hilos", float((px[..., 3] > 0.4).mean()))
    img.pack()
    return img


bpy.ops.wm.read_factory_settings(use_empty=True)
M_ROCA = material("nido_roca", (0.06, 0.035, 0.045), 0.92)
M_INTERIOR = material("nido_interior", (0.004, 0.002, 0.005), 1.0)
M_BRILLO = material("emisivo_nido", (0.25, 0.1, 0.45), 0.4, (0.61, 0.42, 1.0), 1.2)
M_TELA = material("nido_telarana", (0.82, 0.82, 0.82), 0.6)
nt = M_TELA.node_tree
tex = nt.nodes.new('ShaderNodeTexImage')
tex.image = textura_telarana()
nt.links.new(tex.outputs['Color'], nt.nodes['Principled BSDF'].inputs['Base Color'])
# Transparencia por mezcla (BLEND): con recorte por alfa, los hilos finos desaparecen de lejos (los mipmaps los promedian
# por debajo del umbral); con mezcla se desvanecen poco a poco. Es una sola superficie pequeña.
nt.links.new(tex.outputs['Alpha'], nt.nodes['Principled BSDF'].inputs['Alpha'])
M_TELA.use_backface_culling = False  # la tela se ve por los dos lados
for m_ in (M_ROCA, M_INTERIOR, M_BRILLO):
    m_.use_backface_culling = True

# ---- montículo: media esfera deformada, más alta por detrás, con la boca delante (+Y en Blender)
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=1.0)
monte = bpy.context.active_object
monte.name = "nido_monticulo"
me = monte.data
v = np.array([p.co[:] for p in me.vertices])
n = v / np.linalg.norm(v, axis=1, keepdims=True)
desp = 0.18 * ruido(n, 1, 4) + 0.06 * ruido(n * 3, 2, 3)
v = n * (1 + desp)[:, None]
v *= np.array([1.55, 1.45, 1.05])
v[:, 2] += 0.25 * np.clip(-v[:, 1], 0, None)  # joroba trasera: la boca queda en la cara delantera, más baja
v[:, 2] = np.maximum(v[:, 2], -0.25)
for i, p in enumerate(me.vertices):
    p.co = Vector(v[i])
me.materials.append(M_ROCA)
me.materials.append(M_INTERIOR)
# boca: túnel inclinado que entra en el montículo y baja hacia el suelo (resta booleana)
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.55, depth=1.9, location=(0, 1.35, 0.35))  # corto: no sale por arriba
tunel = bpy.context.active_object
tunel.rotation_euler = (math.radians(70), 0, 0)
tunel.scale = (1.15, 0.85, 1.0)
tunel.data.materials.append(M_INTERIOR)
mod = monte.modifiers.new("boca", 'BOOLEAN')
mod.operation = 'DIFFERENCE'
mod.object = tunel
mod.solver = 'EXACT'
bpy.context.view_layer.objects.active = monte
bpy.ops.object.modifier_apply(modifier="boca")
bpy.data.objects.remove(tunel)
# las caras dentro del túnel, negras: todo lo que mira hacia dentro de la boca y queda bajo su labio
for p in me.polygons:
    c = p.center
    if c.y > 0.2 and abs(c.x) < 0.75 and c.z < 0.85 and (Vector((0, 1.1, 0.25)) - c).length < 1.25 and p.normal.y < 0.3:
        p.material_index = 1
# tono por vértice: grietas más oscuras, crestas algo más claras, con un tinte violeta enfermizo cerca de la boca
col = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
pts = np.array([p.co[:] for p in me.vertices])
tono = 0.75 + 0.35 * np.clip(ruido(pts * 2.2, 4, 3), -1, 1) * 0.5 + 0.3 * np.clip(pts[:, 2] / 1.4, 0, 1)
violeta = np.exp(-np.linalg.norm(pts - np.array([0, 1.0, 0.3]), axis=1) ** 2 / 0.5)
for i in range(len(pts)):
    t = tono[i]
    col.data[i].color = (t * (1 + 0.6 * violeta[i]), t * 0.85, t * (1 + 1.2 * violeta[i]), 1)
for p in me.polygons:
    p.use_smooth = True
dec = monte.modifiers.new("dec", 'DECIMATE')
dec.ratio = 0.55
bpy.ops.object.modifier_apply(modifier="dec")

# ---- un fondo negro dentro del túnel (no se ve el cielo a través del suelo) y sacos de huevos que brillan
bpy.ops.mesh.primitive_circle_add(vertices=12, radius=0.7, fill_type='NGON', location=(0, 0.55, -0.2))
fondo = bpy.context.active_object
fondo.name = "nido_fondo"
fondo.data.materials.append(M_INTERIOR)
for i in range(6):
    a = rng.uniform(-0.9, 0.9)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=rng.uniform(0.12, 0.2),
                                         location=(0.35 * math.sin(a * 2), 0.55 + 0.25 * math.cos(a * 3), -0.1 + 0.12 * i / 6))
    saco = bpy.context.active_object
    saco.name = "nido_saco_%d" % i
    saco.scale = (1, 1, 1.35)
    saco.data.materials.append(M_BRILLO)

# ---- espolones de roca curvados alrededor de la boca, como garras
for i in range(7):
    a = math.radians(-70 + i * 23 + rng.uniform(-6, 6))
    base = Vector((math.sin(a) * 1.15, 0.9 + math.cos(a) * 0.55, 0.2))
    largo = rng.uniform(0.9, 1.5)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.16, radius2=0.01, depth=largo, location=base)
    garra = bpy.context.active_object
    garra.name = "nido_garra_%d" % i
    garra.rotation_euler = (math.radians(-35 + rng.uniform(-10, 10)), math.radians(math.degrees(a) * 0.6), 0)
    garra.location = base + garra.matrix_world.to_3x3() @ Vector((0, 0, largo / 2))
    garra.data.materials.append(M_ROCA)
    c = garra.data.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    for d in c.data:
        d.color = (0.55, 0.45, 0.55, 1)

# ---- telarañas: láminas tendidas sobre la boca y entre espolones
def lamina(nombre, centro, tam, rot):
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=centro)
    t = bpy.context.active_object
    t.name = nombre
    t.scale = (tam[0], tam[1], 1)
    t.rotation_euler = rot
    t.data.materials.append(M_TELA)
    return t


lamina("nido_tela_boca", (0, 1.75, 0.45), (1.5, 1.0), (math.radians(80), 0, 0))
lamina("nido_tela_izq", (-1.05, 1.45, 0.7), (1.0, 0.9), (math.radians(80), 0, math.radians(40)))
lamina("nido_tela_der", (1.05, 1.5, 0.65), (1.1, 0.8), (math.radians(85), 0, math.radians(-35)))
lamina("nido_tela_techo", (0.3, 0.4, 1.45), (1.3, 1.1), (math.radians(15), math.radians(10), 0))

# todo en un objeto (una malla por material en el juego). Antes, color de vértice blanco en las piezas que no lo tienen:
# al unir heredarían negro con alfa 0 y Godot (que multiplica por el color de vértice) las vería negras e invisibles.
for o in bpy.context.scene.objects:
    if o.type == 'MESH' and "Col" not in o.data.color_attributes:
        c = o.data.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
        for d in c.data:
            d.color = (1, 1, 1, 1)
for o in bpy.context.scene.objects:
    o.select_set(o.type == 'MESH')
bpy.context.view_layer.objects.active = monte
bpy.ops.object.join()
monte.name = "nido_caverna"
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
tri = sum(len(p.vertices) - 2 for p in monte.data.polygons)
print("NIDO tris", tri, "materiales", [m.name for m in monte.data.materials])
bpy.ops.export_scene.gltf(filepath=SALIDA, export_format='GLB', export_draco_mesh_compression_enable=False, export_yup=True,
                          export_cameras=False, export_lights=False, use_selection=False, export_vertex_color='ACTIVE',
                          export_image_format='AUTO')
print("EXPORTADO", SALIDA)
