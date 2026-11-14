# Texturas PBR procedurales de la Luna, repetibles sin costuras (ruido periódico por FFT, cráteres y Voronoi).
# Paleta medida en la foto NASA as11-40-5903 (Aldrin en la superficie lunar, Apolo 11). No usa píxeles de fotos.
# Genera color, detalle (color / media × 0,8), normal y rugosidad de «luna_regolito» y «luna_roca».
# uso: blender -b --factory-startup -P texturas_luna.py
import bpy, numpy as np, os

N = 1024
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
rng = np.random.default_rng(1969)
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)


def hexc(s):
    return np.array([int(s[i:i + 2], 16) / 255 for i in (1, 3, 5)], dtype=np.float32)


def fbm(beta, lo=1.0, hi=None, seed=0):
    r = np.random.default_rng(seed)
    f = np.fft.fftfreq(N) * N
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1
    amp = k ** (-beta / 2)
    amp[k < lo] = 0
    if hi:
        amp *= np.exp(-(k / hi) ** 2)
    n = np.real(np.fft.ifft2(np.fft.fft2(r.standard_normal((N, N))) * amp))
    n -= n.mean()
    return n / (n.std() + 1e-9)


def norm01(a):
    a = a - a.min()
    return a / (a.max() + 1e-9)


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def normal_map(h, fuerza):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * fuerza
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * fuerza
    nx, ny, nz = -dx, dy, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5], -1)


def distancia_periodica(cx, cy):
    dx = np.abs(xx - cx)
    dx = np.minimum(dx, N - dx)
    dy = np.abs(yy - cy)
    dy = np.minimum(dy, N - dy)
    return np.sqrt(dx * dx + dy * dy)


def crateres(n, rmin, rmax, seed):
    """Altura de cráteres: cuenco hundido con borde elevado y eyecta clara alrededor."""
    r = np.random.default_rng(seed)
    h = np.zeros((N, N), np.float32)
    eyecta = np.zeros((N, N), np.float32)
    for _ in range(n):
        cx, cy = r.uniform(0, N, 2)
        rad = rmin * (rmax / rmin) ** r.uniform(0, 1) ** 2  # muchos pequeños, pocos grandes
        d = distancia_periodica(cx, cy) / rad
        cuenco = np.where(d < 1, -(1 - d * d), 0)
        borde = np.exp(-((d - 1.0) / 0.18) ** 2) * 0.45
        h += (cuenco + borde) * rad * 0.06
        eyecta = np.maximum(eyecta, np.exp(-np.maximum(d - 1, 0) * 2.5) * (d < 2.5))
    return h, eyecta


def voronoi(gx, gy, seed, warp=None):
    r = np.random.default_rng(seed)
    cx, cy = np.meshgrid((np.arange(gx) + 0.5) / gx * N, (np.arange(gy) + 0.5) / gy * N)
    P = np.stack([cx.ravel() + r.uniform(-0.4, 0.4, gx * gy) * N / gx, cy.ravel() + r.uniform(-0.4, 0.4, gx * gy) * N / gy], 1) % N
    X, Y = (xx, yy) if warp is None else (xx + warp[0], yy + warp[1])
    f1 = np.full((N, N), 1e9, np.float32)
    f2 = f1.copy()
    cid = np.zeros((N, N), np.int32)
    for i, (px, py) in enumerate(P):
        dx = np.abs(X - px) % N
        dx = np.minimum(dx, N - dx)
        dy = np.abs(Y - py) % N
        dy = np.minimum(dy, N - dy)
        d = np.sqrt(dx * dx + dy * dy)
        m1 = d < f1
        f2 = np.where(m1, f1, np.minimum(f2, d))
        cid = np.where(m1, i, cid)
        f1 = np.where(m1, d, f1)
    return f1, f2, cid, len(P)


def guardar(nombre, rgb, calidad=90):
    img = bpy.data.images.new(nombre, N, N, alpha=False, float_buffer=False, is_data=True)
    px = np.ones((N, N, 4), np.float32)
    px[..., :3] = np.clip(rgb if rgb.ndim == 3 else rgb[..., None], 0, 1)
    img.pixels.foreach_set(px[::-1].ravel())
    s = bpy.context.scene.render.image_settings
    s.file_format = 'JPEG'
    s.quality = calidad
    s.color_mode = 'RGB'
    destino = os.path.dirname(os.path.abspath(__file__)) if nombre.endswith("_color") else OUT  # el color no va en el juego
    ruta = os.path.join(destino, nombre + ".jpg")
    img.save_render(ruta, scene=bpy.context.scene)
    print("ok", ruta)


def guardar_con_detalle(base, col):
    guardar(base + "_color", col)
    media = col.reshape(-1, 3).mean(0)
    guardar(base + "_detalle", np.clip(col / media * 0.8, 0, 1))
    print(base, "media", "#%02X%02X%02X" % tuple(int(v * 255) for v in media))


# ---------------- regolito lunar: polvo gris fino, microcráteres y gravilla
SOMBRA, OSC, MED, CLA, BRI = hexc("#3B3634"), hexc("#646166"), hexc("#848589"), hexc("#9DA0A5"), hexc("#BDC2CA")
grande = fbm(2.6, lo=1, hi=40, seed=1)
medio = fbm(2.0, lo=4, hi=200, seed=2)
grano = fbm(0.3, lo=80, seed=3)
cr_h, eyecta = crateres(140, 6, 90, seed=4)
t = norm01(grande * 0.6 + medio * 0.4)
col = lerp(lerp(OSC, MED, np.clip(t * 1.7, 0, 1)), CLA, np.clip(t * 1.7 - 0.7, 0, 1))
col = lerp(col, BRI, np.clip(eyecta * 0.35, 0, 1))  # eyecta reciente, más clara
f1, f2, cid, nc = voronoi(18, 18, seed=5)
rr = np.random.default_rng(6)
tam = rr.uniform(4, 14, nc)
keep = rr.uniform(0, 1, nc) < 0.35
forma = fbm(1.4, lo=6, hi=160, seed=7)
piedra = (keep[cid] & (f1 < tam[cid] * (1 + 0.4 * forma))).astype(np.float32)
piedra_h = np.clip(1 - f1 / (tam[cid] * 1.3), 0, 1) ** 0.5 * piedra
tono_piedra = rr.uniform(0.55, 1.1, nc)[cid]
col = lerp(col, (MED * tono_piedra[..., None]), piedra * 0.9)
col *= (1 + 0.09 * grano)[..., None]
h = 0.3 * grande + 0.2 * medio + 0.08 * grano + cr_h * 0.6 + 1.2 * piedra_h
pendiente = np.abs(np.roll(h, -1, 1) - np.roll(h, 1, 1)) + np.abs(np.roll(h, -1, 0) - np.roll(h, 1, 0))
col *= (1 - np.clip(pendiente * 1.5, 0, 0.25))[..., None]
rugosidad = np.clip(0.95 + 0.03 * grano - 0.1 * piedra, 0, 1)
guardar_con_detalle("luna_regolito", col)
guardar("luna_regolito_normal", normal_map(h, 3.5))
guardar("luna_regolito_rugosidad", rugosidad, 88)

# ---------------- roca lunar: brecha (fragmentos claros de anortosita y oscuros de basalto) con vesículas
wv = (fbm(2.6, lo=2, hi=22, seed=10) * 16, fbm(2.6, lo=2, hi=22, seed=11) * 16)
f1, f2, cid, nc = voronoi(22, 22, seed=12, warp=wv)
rr = np.random.default_rng(13)
tipo = rr.uniform(0, 1, nc)
tonos = np.where(tipo < 0.5, 1.3, 0.68) * rr.uniform(0.92, 1.08, nc)  # fragmentos claros (anortosita) y oscuros (basalto)
tam = rr.uniform(6, 20, nc)
forma = fbm(1.4, lo=6, hi=160, seed=17)
clasto = ((rr.uniform(0, 1, nc) < 0.55)[cid] & (f1 < tam[cid] * (1 + 0.35 * forma))).astype(np.float32)
matriz = hexc("#77777A")
col = matriz * (1 + (tonos[cid] - 1) * clasto)[..., None]
junta = np.clip(1 - np.abs(f1 - tam[cid] * (1 + 0.35 * forma)) / 2.0, 0, 1) * (rr.uniform(0, 1, nc) < 0.55)[cid] * 0.6
grano = fbm(0.4, lo=60, seed=14)
det = fbm(1.8, lo=8, hi=300, seed=15)
col *= (0.93 + 0.1 * norm01(det))[..., None] * (1 + 0.08 * grano)[..., None]
col *= (1 - 0.4 * junta)[..., None]
ves = np.zeros((N, N), np.float32)
r2 = np.random.default_rng(16)
for _ in range(500):  # vesículas: poros redondos y oscuros de la lava
    cx, cy = r2.uniform(0, N, 2)
    rad = r2.uniform(1.5, 5)
    d = distancia_periodica(cx, cy) / rad
    ves = np.maximum(ves, np.clip(1 - d, 0, 1))
col *= (1 - 0.55 * np.clip(ves * 2, 0, 1))[..., None]
h = 0.15 * det + 0.05 * grano + 0.25 * clasto - 0.5 * junta - 0.9 * ves
rugosidad = np.clip(0.82 + 0.08 * grano + 0.08 * junta, 0, 1)
guardar_con_detalle("luna_roca", col)
guardar("luna_roca_normal", normal_map(h, 6.0))
guardar("luna_roca_rugosidad", rugosidad, 88)
