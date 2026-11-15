# Cristales (cristal*.glb): textura de estrías de crecimiento e inclusiones (color × detalle y normal), barniz de gema
# (clearcoat) y un brillo interior suave de su mismo color. El color de cada mineral no cambia (lo identifica en el
# juego). Misma caja, nodos y triángulos. Se aplica sobre los cristales ya reparados (reparar_minerales.py).
# uso: blender -b --factory-startup -P cristales_textura.py -- [--export]
import os, sys
SP = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SP)
from comun import *
import bpy, numpy as np

EXPORT = '--export' in sys.argv
CRISTALES = ["cristal", "cristal2", "cristal3_rojo", "cristal5_brillo"]
T = 512


def periodico(beta, lo, hi, semilla):
    r = np.random.default_rng(semilla)
    f = np.fft.fftfreq(T) * T
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1
    amp = k ** (-beta / 2)
    amp[(k < lo) | (k > hi)] = 0
    n = np.real(np.fft.ifft2(np.fft.fft2(r.standard_normal((T, T))) * amp))
    return (n - n.mean()) / (n.std() + 1e-9)


# estrías: ruido estirado en una dirección (las caras de un cristal crecen en capas paralelas) e inclusiones
yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
estiradas = np.real(np.fft.ifft2(np.fft.fft2(periodico(1.2, 2, 200, 7)) * (np.abs(np.fft.fftfreq(T))[None, :] < 0.004)))
estiradas = (estiradas - estiradas.mean()) / (estiradas.std() + 1e-9)
grano = periodico(0.6, 20, 256, 8)
inclusion = np.clip(periodico(2.2, 3, 60, 9) - 1.4, 0, None)
detalle = np.clip(0.88 + 0.07 * estiradas + 0.03 * grano + 0.25 * inclusion, 0, 1)  # inclusiones lechosas
altura = 0.6 * estiradas + 0.15 * grano
dx = (np.roll(altura, -1, 1) - np.roll(altura, 1, 1)) * 0.6
dy = (np.roll(altura, -1, 0) - np.roll(altura, 1, 0)) * 0.6
nrm = np.stack([-dx, dy, np.ones_like(altura)], -1)
nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
NORMAL = nrm * 0.5 + 0.5


def imagen(nombre, rgb, datos=False):
    img = bpy.data.images.new(nombre, T, T, alpha=False, is_data=datos)  # is_data antes de escribir (si no, queda en blanco)
    px = np.ones((T, T, 4), np.float32)
    px[..., :3] = rgb
    img.pixels.foreach_set(px.ravel())
    img.pack()
    return img


def lineal_a_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


for n in CRISTALES:
    limpiar()
    importar(os.path.join(MOD, n + ".glb"))
    raices = sorted(o.name for o in bpy.context.scene.objects if o.parent is None)
    mn, mx = caja()
    t0 = tris()
    mallas = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in mallas:  # UV por proyección inteligente (los cristales no traían UV útiles)
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    for m in bpy.data.materials:
        if not m.use_nodes or not m.name.startswith("cristal"):
            continue
        nt = m.node_tree
        b = nt.nodes.get('Principled BSDF')
        base = np.array(b.inputs['Base Color'].default_value[:3])
        color = lineal_a_srgb(base[None, None, :] * detalle[..., None])  # el color del mineral, con estrías e inclusiones
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = imagen(n + "_cristal_color", color)
        nt.links.new(tex.outputs['Color'], b.inputs['Base Color'])
        ntex = nt.nodes.new('ShaderNodeTexImage')
        ntex.image = imagen(n + "_cristal_normal", NORMAL, True)
        nmap = nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(ntex.outputs['Color'], nmap.inputs['Color'])
        nt.links.new(nmap.outputs['Normal'], b.inputs['Normal'])
        b.inputs['Roughness'].default_value = 0.1
        b.inputs['Metallic'].default_value = 0.0
        b.inputs['Coat Weight'].default_value = 1.0
        b.inputs['Coat Roughness'].default_value = 0.04
        emi_actual = b.inputs['Emission Strength'].default_value * max(b.inputs['Emission Color'].default_value[:3])
        if emi_actual < 0.05:  # brillo interior suave del mismo color (cristal5_brillo ya brilla: se respeta)
            b.inputs['Emission Color'].default_value = (*base, 1)
            b.inputs['Emission Strength'].default_value = 0.25
    mn2, mx2 = caja()
    tol = 0.01 * max(mx - mn)
    ok = all(abs(a - c) <= tol for a, c in zip(list(mn) + list(mx), list(mn2) + list(mx2))) and tris() == t0 and \
        raices == sorted(o.name for o in bpy.context.scene.objects if o.parent is None)
    print("INFORME", n, "tris", t0, "OK", ok)
    os.makedirs(os.path.join(SP, "render"), exist_ok=True)
    render(os.path.join(SP, "render", n + "_textura.png"))
    if EXPORT and ok:
        bpy.ops.export_scene.gltf(filepath=os.path.join(MOD, n + ".glb"), export_format='GLB',
                                  export_draco_mesh_compression_enable=False, export_yup=True, export_image_format='WEBP',  # JPEG de color con CICP: Godot 4.7 no lo lee
                                  export_cameras=False, export_lights=False, use_selection=False)
        print("EXPORTADO", n)
