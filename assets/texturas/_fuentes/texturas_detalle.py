# Versión «detalle» de las texturas de color: color / color medio × 0,8 (por canal).
# El juego multiplica la textura por el color de vértice (que da el tono de cada zona) y por 1,25: así la media
# queda en 1 y solo se añade la variación (grano, gravilla, cantos, estratos), sin cambiar la paleta del terreno.
# uso: blender -b --factory-startup -P texturas_detalle.py
import bpy, numpy as np, os

CARPETA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
for nombre in ("marte_regolito", "marte_roca_estratos"):
    im = bpy.data.images.load(os.path.join(os.path.dirname(os.path.abspath(__file__)), nombre + "_color.jpg"))  # el color vive en _fuentes
    im.colorspace_settings.name = 'Non-Color'
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    media = px[..., :3].reshape(-1, 3).mean(0)
    px[..., :3] = np.clip(px[..., :3] / media * 0.8, 0.0, 1.0)
    out = bpy.data.images.new(nombre + "_detalle", w, h, alpha=False, float_buffer=False, is_data=True)
    out.pixels.foreach_set(px.ravel())
    sc = bpy.context.scene
    s = sc.render.image_settings
    s.file_format = 'JPEG'
    s.quality = 90
    s.color_mode = 'RGB'
    ruta = os.path.join(CARPETA, nombre + "_detalle.jpg")
    out.save_render(ruta, scene=sc)
    print("ok", ruta, "media original", np.round(media, 3))
