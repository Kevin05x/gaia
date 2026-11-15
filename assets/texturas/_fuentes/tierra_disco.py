# Recorta el disco de la Tierra de la foto «Earth (B)» de NASA 3D Resources (github.com/nasa/NASA-3D-Resources,
# Images and Textures/Earth (B)/Earth (B).jpg) y la guarda a 1024 px con el fondo transparente (borde suave).
# uso: blender -b --factory-startup -P tierra_disco.py -- <Earth (B).jpg> <salida.webp>
import bpy, sys, numpy as np
entrada, salida = sys.argv[sys.argv.index('--') + 1:][:2]
im = bpy.data.images.load(entrada)
im.colorspace_settings.name = 'Non-Color'
w, h = im.size
px = np.array(im.pixels[:], np.float32).reshape(h, w, 4)
lum = px[..., :3].max(-1)
filas = np.where(lum.max(1) > 0.08)[0]
cols = np.where(lum.max(0) > 0.08)[0]
cy, cx = (filas[0] + filas[-1]) / 2, (cols[0] + cols[-1]) / 2
r = max(filas[-1] - filas[0], cols[-1] - cols[0]) / 2 * 1.02
x0, y0, lado = int(cx - r), int(cy - r), int(2 * r)
rec = px[max(y0, 0):y0 + lado, max(x0, 0):x0 + lado].copy()
L = rec.shape[0]
yy, xx = np.mgrid[0:L, 0:rec.shape[1]]
d = np.sqrt((xx - rec.shape[1] / 2) ** 2 + (yy - L / 2) ** 2) / (r / 1.02)
rec[..., 3] = np.clip((0.975 - d) / 0.015, 0, 1)  # borde suave, sin el halo oscuro del limbo
out = bpy.data.images.new("tierra", rec.shape[1], L, alpha=True, is_data=True)
out.pixels.foreach_set(rec.ravel())
out.scale(1024, 1024)
s = bpy.context.scene.render.image_settings
s.file_format = 'WEBP'
s.color_mode = 'RGBA'
s.quality = 90
out.save_render(salida, scene=bpy.context.scene)
print("ok", salida, "disco", int(2 * r), "px")
