"""Cordillera del horizonte de GAIA (plan del 15 nov, pedido de Kevin: «los paisajes y cumbres del fondo se ven mal»).

Genera con Blender un anillo de montañas que rodea el cráter 360° y lo guarda como .glb (solo geometría: el color, la
neblina y la paleta de Marte o la Luna los pone el juego, scenes/b/horizonte.gd) y como .blend.

  blender -b -P tools/blender/horizonte.py -- assets/horizonte/cordillera.glb assets/_blender/horizonte.blend

Qué lleva el anillo, de dentro a fuera: lomas bajas con barrancos, crestas afiladas y, al fondo, picos altos y mesetas
escalonadas con acantilados (el ruido de Blender, «ridged multifractal», da las aristas; el escalonado da las terrazas).
Todo es procedural con semilla fija: el mismo comando da siempre la misma cordillera. Sin texturas ni imágenes de nadie:
no hay nada que atribuir ni licenciar fuera del propio script. Medidas en metros, anillo centrado en el origen.
"""
import math
import sys

import bpy
import bmesh
from mathutils import Vector, noise

SALIDA_GLB = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "cordillera.glb"
SALIDA_BLEND = sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else ""

SEGMENTOS = 960  # vueltas alrededor del cráter
FILAS = 44  # de dentro hacia fuera
R_DENTRO = 290.0  # m, para el mapa de referencia de ±140 m (el juego lo escala a otros mapas)
R_FUERA = 575.0
ALTURA_BASE = -0.55  # la cuenca del juego (BASIN_Y)


def suave(a: float, b: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def crestas(p: Vector, octavas: int = 5) -> float:
    """0..1, aristas finas (ruido «ridged multifractal» de Blender)."""
    v = noise.ridged_multi_fractal(p, 1.0, 2.1, octavas, 0.9, 1.6, noise_basis="PERLIN_ORIGINAL")
    return max(0.0, min(1.0, v * 0.55))


def relieve(ang: float, t: float) -> float:
    """Altura (m) del anillo en el ángulo «ang» y la fila relativa «t» (0 dentro, 1 fuera)."""
    c, s = math.cos(ang), math.sin(ang)
    # Dónde se levanta la sierra: grandes macizos con valles entre ellos (sin cortes: el ruido se cierra en círculo).
    masa = noise.noise(Vector((c * 1.5 + 5.0, s * 1.5, 2.0))) * 0.5 + 0.5
    masa = suave(0.28, 0.78, masa)
    # Lomas bajas de dentro, sierra de fuera.
    envolvente = 4.0 + 12.0 * suave(0.0, 0.4, t) + 78.0 * suave(0.35, 0.82, t) * (0.25 + 0.75 * masa) - 70.0 * suave(0.9, 1.0, t)
    p = Vector((c * 3.2, s * 3.2, t * 2.4))
    forma = noise.fractal(p, 0.9, 2.0, 5, noise_basis="PERLIN_ORIGINAL") * 0.5 + 0.5
    arista = crestas(Vector((c * 5.0 + 11.0, s * 5.0, t * 3.4)))
    h = envolvente * (0.30 + 0.45 * forma + 0.55 * arista * (0.4 + 0.6 * suave(0.2, 0.7, t)))
    # Mesetas: en algunos sectores la cima se aplana y baja en escalones (paredes casi verticales).
    mesa = suave(0.50, 0.66, noise.noise(Vector((c * 2.3 + 40.0, s * 2.3, 7.0))) * 0.5 + 0.5) * suave(0.45, 0.8, t)
    escalon = 15.0
    plano = math.floor(h / escalon) * escalon + escalon * suave(0.0, 0.18, (h / escalon) % 1.0)
    h = h + (plano - h) * mesa * 0.85
    # Barrancos en las laderas: surcos finos que cortan la silueta.
    surco = noise.noise(Vector((c * 38.0, s * 38.0, t * 11.0)))
    h += surco * 2.2 * suave(0.3, 0.8, t) * min(1.0, h / 30.0)
    h += noise.noise(Vector((c * 90.0, s * 90.0, t * 30.0))) * 0.7 * suave(0.2, 0.9, t)
    return ALTURA_BASE + max(0.0, h)


def construir():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    malla = bpy.data.meshes.new("Cordillera")
    obj = bpy.data.objects.new("Cordillera", malla)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    anillos = []
    for k in range(FILAS):
        t = k / (FILAS - 1)
        radio = R_DENTRO + (R_FUERA - R_DENTRO) * t
        fila = []
        for i in range(SEGMENTOS):
            ang = math.tau * i / SEGMENTOS
            r = radio + noise.noise(Vector((math.cos(ang) * 3.0, math.sin(ang) * 3.0, k * 0.5))) * 6.0
            fila.append(bm.verts.new((math.cos(ang) * r, math.sin(ang) * r, relieve(ang, t))))
        anillos.append(fila)
    bm.verts.ensure_lookup_table()
    for k in range(FILAS - 1):
        for i in range(SEGMENTOS):
            a, b = anillos[k][i], anillos[k][(i + 1) % SEGMENTOS]
            c, d = anillos[k + 1][(i + 1) % SEGMENTOS], anillos[k + 1][i]
            try:
                bm.faces.new((a, b, c, d))
            except ValueError:
                pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Cuadros a triángulos y normales hacia arriba/hacia dentro (se ve desde el centro del cráter).
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(malla)
    bm.free()
    for poli in malla.polygons:
        poli.use_smooth = True
    return obj


def main():
    obj = construir()
    print("cordillera: %d vértices, %d triángulos" % (len(obj.data.vertices), len(obj.data.polygons)))
    alturas = [v.co.z for v in obj.data.vertices]
    print("alturas: min %.1f  max %.1f m" % (min(alturas), max(alturas)))
    if SALIDA_BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=SALIDA_BLEND)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=SALIDA_GLB, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_normals=True, export_materials="NONE")
    print("guardado:", SALIDA_GLB)


main()
