# Minerales realistas para los objetivos del juego, con materiales PBR físicos y texturas procedurales (512 px):
#   mineral_cobre.glb  cobre nativo: pepitas ramificadas metálicas, oxidadas, con pátina verde de malaquita
#   mineral_oro.glb    pepitas de oro picadas en una veta de cuarzo blanco con manchas de óxido de hierro
#   mineral_plata.glb  plata nativa en hilos y pepitas, con matiz celeste y deslustre negro de acantita
#   hielo_2.glb, hielo_3.glb  hielo: prismas hexagonales translúcidos con burbujas, grietas y escarcha, sobre roca
# Cada uno sobre una roca anfitriona esculpida. Textura de metal y rugosidad (glTF: G = rugosidad, B = metal), así las
# zonas de pátina, cuarzo o deslustre no son metálicas aunque compartan material. Los minerales del juego son ficticios
# en su abundancia (decisión de diseño); el aspecto de cada material imita el real.
# uso: blender -b --factory-startup -P minerales_reales.py
import bpy, bmesh, math, os, numpy as np
from mathutils import Vector

CARPETA = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "modelos"))
T = 512
yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)


# ------------------------------------------------------------------ texturas
def fbm(beta, lo, hi, semilla):
    r = np.random.default_rng(semilla)
    f = np.fft.fftfreq(T) * T
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1
    amp = k ** (-beta / 2)
    amp[(k < lo) | (k > hi)] = 0
    n = np.real(np.fft.ifft2(np.fft.fft2(r.standard_normal((T, T))) * amp))
    return (n - n.mean()) / (n.std() + 1e-9)


def hexc(s):
    return np.array([int(s[i:i + 2], 16) / 255 for i in (1, 3, 5)], np.float32)


def mezcla(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a + (b - a) * t


def normal_de(h, fuerza):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * fuerza
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * fuerza
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True) * 0.5 + 0.5


def manchas(n, rmin, rmax, semilla):
    """Puntos redondos (picaduras, burbujas): 0..1."""
    r = np.random.default_rng(semilla)
    m = np.zeros((T, T), np.float32)
    for _ in range(n):
        cx, cy = r.uniform(0, T, 2)
        rad = r.uniform(rmin, rmax)
        dx = np.minimum(np.abs(xx - cx), T - np.abs(xx - cx))
        dy = np.minimum(np.abs(yy - cy), T - np.abs(yy - cy))
        m = np.maximum(m, np.clip(1 - np.sqrt(dx * dx + dy * dy) / rad, 0, 1))
    return m


def grietas(semilla, ancho=0.08):
    return np.clip(1 - np.abs(fbm(1.6, 3, 120, semilla)) / ancho, 0, 1) ** 2


def tex_cobre():
    ox = fbm(2.2, 2, 80, 11)
    patina = np.clip((fbm(2.4, 2, 40, 12) - 0.6) * 1.6, 0, 1)  # malaquita/verdigrís en manchas y cavidades
    grano = fbm(0.5, 30, 256, 13)
    col = mezcla(hexc("#D9895A"), hexc("#7A3E22"), 0.5 + 0.35 * ox)  # cobre vivo / oxidado (cuprita)
    col = mezcla(col, mezcla(hexc("#2F7D5B"), hexc("#7CC0A0"), 0.5 + 0.5 * grano), patina)
    col *= (1 + 0.06 * grano)[..., None]
    rug = np.clip(0.32 + 0.15 * ox + 0.5 * patina, 0, 1)
    metal = np.clip(1 - patina * 1.2, 0, 1)
    h = 0.5 * fbm(2.0, 3, 120, 14) + 0.6 * patina + 0.1 * grano
    return col, rug, metal, normal_de(h, 3.0)


def tex_oro():
    pic = manchas(260, 1.5, 5, 21)  # superficie picada y martillada de las pepitas
    grano = fbm(0.6, 30, 256, 22)
    suc = np.clip((fbm(2.4, 2, 40, 23) - 1.0) * 1.5, 0, 1)  # restos de óxido de hierro en los huecos
    col = mezcla(hexc("#F7D774"), hexc("#D9AE45"), 0.5 + 0.3 * fbm(2, 2, 60, 24))  # oro amarillo (no ámbar)
    col = mezcla(col, hexc("#8A5A22"), np.maximum(suc * 0.8, pic * 0.3))
    rug = np.clip(0.22 + 0.25 * pic + 0.4 * suc + 0.05 * grano, 0, 1)
    metal = np.clip(1 - suc, 0, 1)
    h = -0.9 * pic + 0.2 * fbm(1.8, 4, 160, 25) + 0.05 * grano
    return col, rug, metal, normal_de(h, 4.0)


def tex_cuarzo():
    nube = fbm(2.0, 2, 80, 31)
    oxido = np.clip((fbm(2.3, 2, 50, 32) - 0.9) * 1.4, 0, 1)  # manchas de limonita (óxido de hierro) típicas
    col = mezcla(hexc("#EDEAE2"), hexc("#C9C4B8"), 0.5 + 0.4 * nube)
    col = mezcla(col, hexc("#B06A2C"), oxido)
    rug = np.clip(0.3 + 0.2 * nube + 0.4 * oxido, 0, 1)
    h = 0.4 * nube + 0.6 * grietas(33, 0.05)
    return col, rug, np.zeros((T, T), np.float32), normal_de(h, 2.5)


def tex_plata():
    desl = np.clip((fbm(2.3, 2, 50, 41) - 0.9) * 1.3, 0, 1)  # deslustre negro de acantita (sulfuro de plata)
    grano = fbm(0.5, 30, 256, 42)
    estria = fbm(1.4, 2, 200, 43)
    col = mezcla(hexc("#DCE8F0"), hexc("#9FB2C0"), 0.5 + 0.3 * estria)  # plata con matiz celeste
    col = mezcla(col, hexc("#2B2C31"), desl * 0.85)
    rug = np.clip(0.25 + 0.5 * desl + 0.05 * grano, 0, 1)
    metal = np.clip(1 - desl * 0.7, 0, 1)
    h = 0.4 * estria + 0.3 * desl + 0.08 * grano
    return col, rug, metal, normal_de(h, 3.0)


def tex_hielo():
    burb = manchas(180, 1, 4, 51)
    gr = grietas(52, 0.05)
    escarcha = np.clip((fbm(2.2, 2, 60, 53) - 0.3) * 1.2, 0, 1)
    grano = fbm(0.4, 40, 256, 54)
    col = mezcla(hexc("#9CC9E8"), hexc("#D8ECF8"), 0.5 + 0.3 * fbm(2, 2, 40, 55))  # azul glaciar
    col = mezcla(col, hexc("#F4FAFF"), np.maximum.reduce([burb * 0.8, gr * 0.9, escarcha * 0.7]))
    rug = np.clip(0.06 + 0.5 * escarcha + 0.2 * gr + 0.04 * grano, 0, 1)
    h = 0.3 * fbm(1.8, 3, 100, 56) - 0.5 * gr + 0.2 * escarcha * grano
    return col, rug, np.zeros((T, T), np.float32), normal_de(h, 2.5)


def tex_roca(tono):
    base = hexc(tono)
    n1 = fbm(2.2, 2, 60, 61)
    grano = fbm(0.5, 30, 256, 62)
    gr = grietas(63, 0.06)
    col = base * (0.85 + 0.12 * n1 + 0.06 * grano)[..., None] * (1 - 0.35 * gr)[..., None]
    rug = np.clip(0.88 + 0.06 * grano, 0, 1)
    h = 0.5 * n1 + 0.1 * grano - 0.6 * gr
    return col, rug, np.zeros((T, T), np.float32), normal_de(h, 3.0)


def imagen(nombre, rgb, datos=False):
    # is_data desde el principio: cambiar el espacio de color después regenera la imagen en blanco
    img = bpy.data.images.new(nombre, T, T, alpha=False, is_data=datos)
    px = np.ones((T, T, 4), np.float32)
    px[..., :3] = np.clip(rgb, 0, 1)
    img.pixels.foreach_set(px.ravel())
    img.pack()
    return img


def srgb_a_lineal(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def material_pbr(nombre, tex, coat=0.0):
    col, rug, metal, nrm = tex
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    t_col = nt.nodes.new('ShaderNodeTexImage')
    t_col.image = imagen(nombre + "_color", srgb_a_lineal(col))  # imagen en lineal; Blender la guarda en sRGB
    nt.links.new(t_col.outputs['Color'], b.inputs['Base Color'])
    mr = np.stack([np.zeros_like(rug), rug, metal], -1)  # glTF: G = rugosidad, B = metal
    t_mr = nt.nodes.new('ShaderNodeTexImage')
    t_mr.image = imagen(nombre + "_mr", mr, True)
    sep = nt.nodes.new('ShaderNodeSeparateColor')
    nt.links.new(t_mr.outputs['Color'], sep.inputs['Color'])
    nt.links.new(sep.outputs['Green'], b.inputs['Roughness'])
    nt.links.new(sep.outputs['Blue'], b.inputs['Metallic'])
    t_n = nt.nodes.new('ShaderNodeTexImage')
    t_n.image = imagen(nombre + "_normal", nrm, True)
    nmap = nt.nodes.new('ShaderNodeNormalMap')
    nt.links.new(t_n.outputs['Color'], nmap.inputs['Color'])
    nt.links.new(nmap.outputs['Normal'], b.inputs['Normal'])
    if coat:
        b.inputs['Coat Weight'].default_value = coat
        b.inputs['Coat Roughness'].default_value = 0.08
    return m


# ------------------------------------------------------------------ geometría
def ruido3(p, semilla, octavas=3, frec=1.6):
    r = np.random.default_rng(semilla)
    total = np.zeros(len(p))
    amp = 1.0
    for _ in range(octavas):
        q, _ = np.linalg.qr(r.normal(size=(3, 3)))
        fase = r.uniform(0, math.tau, 3)
        pr = p @ q * frec
        total += amp * np.sin(pr[:, 0] + fase[0]) * np.sin(pr[:, 1] + fase[1]) * np.sin(pr[:, 2] + fase[2])
        amp *= 0.5
        frec *= 2.1
    return total


def bulto(centro, radio, escala, semilla, rugosidad=0.25, subdiv=2, material=None):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1.0)
    o = bpy.context.active_object
    v = np.array([p.co[:] for p in o.data.vertices])
    n = v / np.linalg.norm(v, axis=1, keepdims=True)
    v = n * (1 + rugosidad * ruido3(n, semilla))[:, None] * radio * np.array(escala)
    for i, p in enumerate(o.data.vertices):
        p.co = Vector(v[i]) + Vector(centro)
    if material:
        o.data.materials.append(material)
    return o


def roca_anfitriona(semilla, material):
    o = bulto((0, 0, 0.2), 1.0, (1.1, 0.95, 0.42), semilla, 0.2, 3, material)  # roca baja: el mineral es el protagonista
    for p in o.data.vertices:  # base plana
        p.co.z = max(p.co.z, 0.0)
    return o


def rama(origen, direccion, pasos, radio, semilla, material, rng):
    """Cadena de bultos que sigue un camino quebrado (crecimiento dendrítico del cobre y la plata nativos)."""
    objs = []
    p = Vector(origen)
    d = Vector(direccion).normalized()
    for i in range(pasos):
        r = radio * (1 - 0.55 * i / pasos)
        objs.append(bulto(p, r, (1, 1, 1.15), semilla + i, 0.35, 1, material))
        d = (d + Vector(rng.normal(0, 0.45, 3))).normalized()
        d.z = abs(d.z) * 0.8 + 0.2
        p = p + d * r * 1.3
        if rng.uniform() < 0.25 and pasos - i > 2:
            objs += rama(p, Vector(rng.normal(0, 1, 3)), pasos - i - 2, r * 0.8, semilla + 50 + i, material, rng)
    return objs


def prisma_hexagonal(base, direccion, radio, largo, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radio, depth=largo)
    c = bpy.context.active_object
    bm = bmesh.new()
    bm.from_mesh(c.data)
    arriba = [v for v in bm.verts if v.co.z > 0]
    for v in arriba:  # punta piramidal
        v.co.x *= 0.15
        v.co.y *= 0.15
        v.co.z += radio * 1.4
    bm.to_mesh(c.data)
    bm.free()
    d = Vector(direccion).normalized()
    c.rotation_mode = 'QUATERNION'
    c.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    c.location = Vector(base) + d * (largo / 2)
    c.data.materials.append(material)
    return c


def unir_y_exportar(nombre, objetos):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objetos:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objetos[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = nombre
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    for p in o.data.polygons:
        p.use_smooth = True
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(45))
    except Exception:
        pass
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tris > 2400:
        dec = o.modifiers.new("dec", 'DECIMATE')
        dec.ratio = 2300 / tris
        bpy.ops.object.modifier_apply(modifier="dec")
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    ruta = os.path.join(CARPETA, nombre + ".glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format='GLB', export_draco_mesh_compression_enable=False, export_yup=True,
                              export_cameras=False, export_lights=False, use_selection=True, export_image_format='WEBP')  # JPEG de color de Blender 5.3 lleva CICP y Godot 4.7 no lo lee
    print("MINERAL", nombre, "tris", tris, "materiales", [m.name for m in o.data.materials])


def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ------------------------------------------------------------------ modelos
def cobre():
    limpiar()
    rng = np.random.default_rng(101)
    roca = material_pbr("roca_basalto", tex_roca("#4A3B35"))
    metal = material_pbr("cobre_nativo", tex_cobre())
    objs = [roca_anfitriona(101, roca)]
    objs.append(bulto((0, 0, 0.45), 0.42, (1.2, 1, 0.75), 109, 0.4, 2, metal))  # masa central de cobre
    for i in range(7):
        a = i / 7 * math.tau + rng.uniform(-0.3, 0.3)
        objs += rama((math.cos(a) * 0.35, math.sin(a) * 0.3, 0.45), (math.cos(a), math.sin(a), 0.9), 6, 0.28, 110 + i * 10, metal, rng)
    unir_y_exportar("mineral_cobre", objs)


def oro():
    limpiar()
    rng = np.random.default_rng(202)
    roca = material_pbr("roca_basalto", tex_roca("#4A4038"))
    cuarzo = material_pbr("cuarzo", tex_cuarzo(), coat=0.3)
    metal = material_pbr("oro_nativo", tex_oro())
    objs = [roca_anfitriona(202, roca)]
    objs.append(bulto((0.05, 0, 0.5), 1.0, (1.05, 0.45, 0.48), 203, 0.15, 3, cuarzo))  # veta de cuarzo que cruza la roca
    for i in range(13):
        x = rng.uniform(-0.8, 0.8)
        objs.append(bulto((x, rng.uniform(-0.3, 0.3), 0.75 + 0.2 * (1 - abs(x))), rng.uniform(0.16, 0.3), (1.2, 1, 0.8), 210 + i, 0.4, 2, metal))
    unir_y_exportar("mineral_oro", objs)


def plata():
    limpiar()
    rng = np.random.default_rng(303)
    roca = material_pbr("roca_basalto", tex_roca("#3F3C3E"))
    metal = material_pbr("plata_nativa", tex_plata())
    objs = [roca_anfitriona(303, roca)]
    for i in range(8):  # hilos de plata: ramas largas que se rizan
        a = i / 8 * math.tau + rng.uniform(-0.2, 0.2)
        objs += rama((math.cos(a) * 0.4, math.sin(a) * 0.35, 0.4), (math.cos(a) * 0.4, math.sin(a) * 0.4, 1), 7, 0.17, 310 + i * 10, metal, rng)
    for i in range(5):
        objs.append(bulto((rng.uniform(-0.5, 0.5), rng.uniform(-0.4, 0.4), 0.55), 0.24, (1, 1, 0.8), 380 + i, 0.4, 2, metal))
    unir_y_exportar("mineral_plata", objs)


def hielo(nombre, semilla):
    limpiar()
    rng = np.random.default_rng(semilla)
    roca = material_pbr("roca_hielo", tex_roca("#5A4A42"))
    hielo_m = material_pbr("hielo", tex_hielo(), coat=1.0)
    objs = [roca_anfitriona(semilla, roca)]
    for i in range(12):  # prismas hexagonales de hielo que brotan de la roca en abanico
        a = rng.uniform(0, math.tau)
        incl = rng.uniform(0.1, 0.7)
        d = (math.cos(a) * incl, math.sin(a) * incl, 1)
        base = (math.cos(a) * rng.uniform(0, 0.55), math.sin(a) * rng.uniform(0, 0.45), 0.3)
        objs.append(prisma_hexagonal(base, d, rng.uniform(0.18, 0.32), rng.uniform(0.6, 1.4), hielo_m))
    objs.append(bulto((0, 0, 0.42), 0.7, (1.4, 1.2, 0.4), semilla + 9, 0.3, 2, hielo_m))  # costra de hielo y escarcha
    unir_y_exportar(nombre, objs)


cobre()
oro()
plata()
hielo("hielo_2", 404)
hielo("hielo_3", 505)
