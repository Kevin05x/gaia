# Texturas PBR procedurales, repetibles sin costuras, para que los edificios se vean realistas.
# (El juego estira los paneles a 3 m por repetición: juntas de 37 cm a 1,1 m, como los paneles de un módulo.)
# No usan píxeles de fotos: todo sale de ruido periódico (FFT), rejillas y formas simples.
#
#  · edificio_paneles_*  (2 m por repetición; 1 px ≈ 2 mm): chapa de paneles atornillados como la de los módulos
#    y vehículos espaciales: juntas hundidas, remaches, tapas de registro, rayones y suciedad que baja desde las juntas.
#      _detalle    gris claro (media ≈ 0,9): multiplica el color de cada pieza (no cambia la paleta del modelo).
#      _normal     relieve de juntas, remaches y abolladuras suaves.
#      _mascaras   R = rugosidad, G = dónde se pega el polvo (rincones y juntas), B = oclusión de juntas.
#
# uso: blender -b --factory-startup -P texturas_edificios.py
import bpy, numpy as np, os

N = 1024
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)


def fbm(beta, lo=1.0, hi=None, seed=0, anis=(1.0, 1.0)):
    r = np.random.default_rng(seed)
    f = np.fft.fftfreq(N) * N
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt((fx * anis[0]) ** 2 + (fy * anis[1]) ** 2)
    k[0, 0] = 1
    amp = k ** (-beta / 2)
    amp[k < lo] = 0
    if hi:
        amp *= np.exp(-(k / hi) ** 2)
    n = np.real(np.fft.ifft2(np.fft.fft2(r.standard_normal((N, N))) * amp))
    n -= n.mean()
    return (n / (n.std() + 1e-9)).astype(np.float32)


def normal_map(h, fuerza):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * fuerza
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * fuerza
    nx, ny, nz = -dx, dy, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5], -1)


def desenfoque(a, radio):
    """Desenfoque gaussiano periódico (por FFT)."""
    f = np.fft.fftfreq(N)
    fx, fy = np.meshgrid(f, f)
    g = np.exp(-2 * (np.pi * radio) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g)).astype(np.float32)


def caida(a, largo):
    """Arrastra hacia abajo (como la suciedad que escurre): suma desplazada con peso que decae."""
    out = np.zeros_like(a)
    peso = 0.0
    for i in range(0, largo, 2):
        w = np.exp(-i / (largo * 0.35))
        out += np.roll(a, i, 0) * w
        peso += w
    return out / peso


def guardar(nombre, rgb, calidad=92):
    img = bpy.data.images.new(nombre, N, N, alpha=False, float_buffer=False, is_data=True)
    px = np.ones((N, N, 4), np.float32)
    px[..., :3] = np.clip(rgb if rgb.ndim == 3 else rgb[..., None], 0, 1)
    img.pixels.foreach_set(px[::-1].ravel())
    s = bpy.context.scene.render.image_settings
    s.file_format = 'JPEG'
    s.quality = calidad
    s.color_mode = 'RGB'
    ruta = os.path.join(OUT, nombre + ".jpg")
    img.save_render(ruta, scene=bpy.context.scene)
    print("ok", ruta, "media", np.round(np.asarray(rgb).reshape(-1, rgb.shape[-1] if rgb.ndim == 3 else 1).mean(0), 3))


def disco_periodico(cx, cy):
    dx = np.abs(xx - cx)
    dx = np.minimum(dx, N - dx)
    dy = np.abs(yy - cy)
    dy = np.minimum(dy, N - dy)
    return dx, dy


# =============================================================== paneles de los edificios
def paneles():
    rng = np.random.default_rng(1971)
    alto = np.zeros((N, N), np.float32)        # relieve (0 = chapa)
    tono = np.ones((N, N), np.float32)         # tono de cada panel
    rug = np.full((N, N), 0.58, np.float32)    # rugosidad
    junta = np.zeros((N, N), np.float32)       # 1 en las juntas (para oclusión y polvo)
    U = 64                                      # módulo de 12,5 cm
    filas = [4, 2, 4, 6]                        # 50, 25, 50 y 75 cm (suman 16 módulos = 2 m)
    y0 = 0
    for fi, fh in enumerate(filas):
        x0 = 0
        anchos = []
        while sum(anchos) < 16:
            anchos.append(int(min(rng.choice([2, 4, 4, 6, 8]), 16 - sum(anchos))))
        desfase = int(rng.integers(0, 16)) * U  # las juntas verticales no coinciden de una fila a otra
        for aw in anchos:
            px0, py0, pw, ph = x0 + desfase, y0 * U, aw * U, fh * U
            ys = (np.arange(py0, py0 + ph)) % N
            xs = (np.arange(px0, px0 + pw)) % N
            sub = np.ix_(ys, xs)
            # cada panel: tono, rugosidad y una leve abolladura (almohadillado)
            tono[sub] = 1.0 + rng.normal(0, 0.035)
            rug[sub] = 0.55 + rng.normal(0, 0.06)
            ly, lx = np.meshgrid(np.linspace(-1, 1, ph), np.linspace(-1, 1, pw), indexing="ij")
            alto[sub] += (1 - lx * lx) * (1 - ly * ly) * rng.uniform(0.2, 0.6)
            # juntas: ranura de 3 px en el borde izquierdo y superior del panel (el vecino pone la otra)
            borde = np.minimum(np.minimum(lx + 1, 1 - lx) * pw / 2, np.minimum(ly + 1, 1 - ly) * ph / 2)
            j = np.clip(1.6 - borde, 0, 1)
            junta[sub] = np.maximum(junta[sub], j)
            # remaches a 7 px del borde, cada 32 px
            for t in range(16, pw, 32):
                for yy_r in (7, ph - 8):
                    _remache(alto, rug, (px0 + t) % N, (py0 + yy_r) % N)
            for t in range(16, ph, 32):
                for xx_r in (7, pw - 8):
                    _remache(alto, rug, (px0 + xx_r) % N, (py0 + t) % N)
            # algunas tapas de registro: ranura interior y cuatro tornillos
            if pw >= 4 * U and ph >= 4 * U and rng.random() < 0.55:
                m = 40
                tx0, ty0, tw, th = px0 + m, py0 + m, pw - 2 * m, min(ph - 2 * m, int(rng.uniform(0.4, 0.8) * (ph - 2 * m)) + 20)
                ys2 = np.arange(ty0, ty0 + th) % N
                xs2 = np.arange(tx0, tx0 + tw) % N
                sub2 = np.ix_(ys2, xs2)
                ly2, lx2 = np.meshgrid(np.linspace(-1, 1, th), np.linspace(-1, 1, tw), indexing="ij")
                b2 = np.minimum(np.minimum(lx2 + 1, 1 - lx2) * tw / 2, np.minimum(ly2 + 1, 1 - ly2) * th / 2)
                junta[sub2] = np.maximum(junta[sub2], np.clip(1.4 - b2, 0, 1) * 0.8)
                tono[sub2] *= 1.0 + rng.normal(0, 0.03)
                for cx, cy in ((tx0 + 10, ty0 + 10), (tx0 + tw - 11, ty0 + 10), (tx0 + 10, ty0 + th - 11), (tx0 + tw - 11, ty0 + th - 11)):
                    _remache(alto, rug, cx % N, cy % N, 3.2)
            x0 += pw
        y0 += fh
    alto -= junta * 2.2
    # chapa: ruido fino y cepillado horizontal
    fino = fbm(1.2, lo=60, seed=3)
    cepillado = fbm(1.0, lo=20, seed=4, anis=(0.08, 1.0))
    alto += fino * 0.03
    # rayones: líneas finas al azar (más claras y más lisas)
    ray = np.zeros((N, N), np.float32)
    for _ in range(140):
        x1, y1 = rng.uniform(0, N, 2)
        ang = rng.uniform(0, np.pi)
        largo = rng.uniform(15, 120)
        t = np.linspace(0, 1, int(largo * 1.5))
        xs = ((x1 + np.cos(ang) * largo * t) % N).astype(int)
        ys = ((y1 + np.sin(ang) * largo * t) % N).astype(int)
        ray[ys, xs] = np.maximum(ray[ys, xs], rng.uniform(0.3, 1.0))
    ray = np.clip(desenfoque(ray, 0.7) * 2.5, 0, 1)
    # suciedad: manchas grandes + lo que escurre desde juntas y remaches
    manchas = np.clip(fbm(2.6, lo=2, seed=5) * 0.5 + 0.2, 0, 1)
    escurre = np.clip(caida(junta, 70) * 1.3, 0, 1) * np.clip(fbm(1.6, lo=8, seed=6) * 0.6 + 0.6, 0, 1)
    sucio = np.clip(manchas * 0.55 + escurre * 0.7, 0, 1)
    ao = np.clip(1 - desenfoque(junta, 2.5) * 0.9, 0, 1)

    detalle = tono * (0.93 + cepillado * 0.012 + fino * 0.012) * (0.86 + 0.14 * ao) * (1 - sucio * 0.14) + ray * 0.06
    detalle = detalle / detalle.mean() * 0.9
    guardar("edificio_paneles_detalle", np.repeat(detalle[..., None], 3, -1))
    guardar("edificio_paneles_normal", normal_map(alto, 1.6))
    r = np.clip(rug + sucio * 0.25 - ray * 0.28 + cepillado * 0.02, 0.15, 1.0)
    polvo = np.clip(desenfoque(junta, 4) * 1.6 + manchas * 0.35 + escurre * 0.3, 0, 1)
    guardar("edificio_paneles_mascaras", np.stack([r, polvo, ao], -1))


def _remache(alto, rug, cx, cy, radio=2.6):
    x0, y0 = int(cx) - 5, int(cy) - 5
    ys = np.arange(y0, y0 + 11) % N
    xs = np.arange(x0, x0 + 11) % N
    ly, lx = np.meshgrid(np.arange(11) - 5.0, np.arange(11) - 5.0, indexing="ij")
    d = np.sqrt(lx * lx + ly * ly) / radio
    cupula = np.where(d < 1, np.sqrt(np.clip(1 - d * d, 0, 1)), 0) * 1.2
    sub = np.ix_(ys, xs)
    alto[sub] = np.maximum(alto[sub], cupula)
    rug[sub] = np.where(d < 1, rug[sub] * 0.9, rug[sub])  # casi igual que la chapa: sin destellos en los bordes


paneles()
