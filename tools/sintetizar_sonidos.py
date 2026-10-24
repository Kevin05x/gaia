"""Efectos de sonido originales de GAIA, sintetizados por código (sin muestras de terceros).
Uso: python3 sintetizar_sonidos.py carpeta_de_salida
Cada acción del rover tiene su propio sonido; los bucles son de ciclos enteros para empalmar sin clics.
"""
import sys
from pathlib import Path
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 22050


def t_of(dur):
    return np.arange(int(dur * SR)) / SR


def lp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, btype="low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, btype="high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def circ_filter(fn, x):
    """Aplica un filtro en circular (copia triple) para que el bucle no tenga salto."""
    n = len(x)
    return fn(np.concatenate([x, x, x]))[n:2 * n]


def add_circ(buf, sig, start_s):
    n = len(buf)
    idx = (np.arange(len(sig)) + int(start_s * SR)) % n
    np.add.at(buf, idx, sig)


def norm(x, peak=0.9):
    x = x - x.mean()
    return x / np.max(np.abs(x)) * peak


def save(folder, name, x, fade_ms=0):
    x = norm(x)
    if fade_ms:
        n = int(fade_ms / 1000 * SR)
        x[-n:] *= np.linspace(1, 0, n)
        x[:int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    wavfile.write(str(Path(folder) / name), SR, (x * 32767).astype(np.int16))
    print(name, round(len(x) / SR, 2), "s")


def gravel(dur, density, seed, lo=500, hi=4500):
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    out = np.zeros(n)
    for _ in range(int(density * dur)):
        s = rng.random() * dur
        ln = int((0.004 + 0.012 * rng.random()) * SR)
        burst = bp(rng.standard_normal(ln), lo, hi, 1) * np.exp(-np.arange(ln) / (ln / 4)) * (0.3 + rng.random())
        add_circ(out, burst, s)
    return out


# ---------------------------------------------------------------- rover rodando (motor.wav, bucle 1.6 s)
def rover(dur=1.6):
    t = t_of(dur)
    f0 = 120.0  # 192 ciclos en 1.6 s
    wob = 1 + 0.012 * np.sin(2 * np.pi * (1 / dur) * 5 * t)
    hum = np.sin(2 * np.pi * f0 * t * wob) * 0.5 + np.sin(2 * np.pi * 2 * f0 * t) * 0.25 + np.sin(2 * np.pi * 3 * f0 * t) * 0.12
    whine = np.sin(2 * np.pi * 1200 * t + 2.0 * np.sin(2 * np.pi * (1 / dur) * 8 * t)) * 0.07
    step = 0.55 + 0.45 * np.cos(2 * np.pi * (1 / dur) * 8 * t)  # 8 pasos de rueda por ciclo: crujido rítmico
    crunch = gravel(dur, 90, 3) * 0.55 * step
    return hum + whine + circ_filter(lambda z: lp(z, 2600), crunch)


# ---------------------------------------------------------------- taladro (drill.wav, bucle 1.2 s)
def drill(dur=1.2):
    t = t_of(dur)
    base = 2 * ((170 * t) % 1.0) - 1
    buzz = circ_filter(lambda z: bp(z, 150, 1800), base) * 0.8
    out = buzz + gravel(dur, 160, 5, 800, 6000) * 0.5
    # martilleo: 12 golpes por segundo
    hits = np.zeros(len(t))
    for k in range(int(dur * 12)):
        s = k / 12.0
        ln = int(0.09 * SR)
        tt = np.arange(ln) / SR
        thud = np.sin(2 * np.pi * (60 + 90 * np.exp(-tt * 50)) * tt) * np.exp(-tt * 38)
        crack = hp(np.random.default_rng(k).standard_normal(ln), 1500) * np.exp(-tt * 120) * 0.6
        add_circ(hits, thud + crack, s)
    return out * 0.75 + hits * 0.9


# ---------------------------------------------------------------- espectrómetro láser (laser.wav, bucle 1.5 s)
def laser(dur=1.5):
    out = np.zeros(int(dur * SR))
    for k, s in enumerate([0.0, 0.18, 0.36, 0.78, 0.96, 1.14]):
        ln = int(0.11 * SR)
        tt = np.arange(ln) / SR
        f = 3000 * np.exp(-tt * 9) + 500
        zap = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 20)
        crackle = hp(np.random.default_rng(40 + k).standard_normal(ln), 3000) * np.exp(-tt * 45) * 0.5
        add_circ(out, zap * 0.8 + crackle, s)
    tt = t_of(dur)
    out += np.sin(2 * np.pi * 1760 * tt) * 0.05 * (0.5 + 0.5 * np.sin(2 * np.pi * 4 * tt / dur * 4))
    return out


# ---------------------------------------------------------------- radar de subsuelo (radar.wav, bucle 2.4 s)
def radar(dur=2.4):
    out = np.zeros(int(dur * SR))
    for rep, g in ((0.0, 1.0), (0.55, 0.38), (1.0, 0.16)):
        ln = int(1.35 * SR)
        tt = np.arange(ln) / SR
        sweep = 260 + 340 * (1 - np.exp(-tt * 18))
        ping = np.sin(2 * np.pi * np.cumsum(sweep) / SR) * np.exp(-tt * 3.2)
        ping += np.sin(2 * np.pi * np.cumsum(sweep * 2.01) / SR) * np.exp(-tt * 5) * 0.25
        add_circ(out, ping * g, rep)
    tt = t_of(dur)
    out += np.sin(2 * np.pi * 55 * tt) * 0.28 * (0.6 + 0.4 * np.cos(2 * np.pi * tt / dur * 2))
    return out


# ---------------------------------------------------------------- panorámica (panorama.wav, bucle 2.0 s)
def panorama(dur=2.0):
    t = t_of(dur)
    sweep = 320 + 90 * np.sin(2 * np.pi * t / dur)
    servo = circ_filter(lambda z: bp(z, 250, 1600), 2 * ((np.cumsum(sweep) / SR) % 1.0) - 1) * 0.25
    out = servo
    for s in (0.25, 0.75, 1.25, 1.75):
        for d in (0.0, 0.07):
            ln = int(0.012 * SR)
            tt = np.arange(ln) / SR
            click = hp(np.random.default_rng(int(s * 100) + int(d * 100)).standard_normal(ln), 1200) * np.exp(-tt * 380)
            click += np.sin(2 * np.pi * 900 * tt) * np.exp(-tt * 420) * 0.5
            add_circ(out, click * 1.3, s + d)
    return out


# ---------------------------------------------------------------- dron: arranque (drone_start.wav) y vuelo (drone.wav, bucle 0.8 s)
def drone_start(dur=1.9):
    t = t_of(dur)
    ramp = (t / dur) ** 1.6
    f = 18 + 105 * ramp
    ph = 2 * np.pi * np.cumsum(f) / SR
    buzz = sum(np.sin(ph * k) / k for k in range(1, 8))
    air = lp(np.random.default_rng(9).standard_normal(len(t)), 1800) * ramp
    out = (buzz * 0.5 * (0.3 + ramp) + air * 0.9) * np.minimum(1.0, t / 0.05)
    return out


def drone(dur=0.8):
    t = t_of(dur)
    f0 = 100.0  # 80 ciclos
    am = 0.6 + 0.4 * np.sin(2 * np.pi * 40 * t)  # aleteo de las aspas
    buzz = sum(np.sin(2 * np.pi * f0 * k * t) / k for k in range(1, 9)) * am
    air = circ_filter(lambda z: bp(z, 400, 3500), np.random.default_rng(12).standard_normal(len(t))) * 0.8
    return buzz * 0.5 + air


# ---------------------------------------------------------------- compañero (companion.wav, bucle 1.6 s)
def companion(dur=1.6):
    out = np.zeros(int(dur * SR))
    notes = [(0.0, 880, 0.07), (0.12, 1320, 0.06), (0.26, 990, 0.09), (0.5, 1480, 0.05), (0.62, 1175, 0.08),
             (0.9, 740, 0.09), (1.05, 1100, 0.06), (1.2, 1570, 0.1)]
    for s, f, d in notes:
        ln = int(d * SR)
        tt = np.arange(ln) / SR
        blip = np.sin(2 * np.pi * (f + 260 * tt / d) * tt) * np.minimum(1, tt / 0.005) * np.exp(-tt * 14)
        blip += np.sign(np.sin(2 * np.pi * f * 0.5 * tt)) * 0.12 * np.exp(-tt * 20)
        add_circ(out, blip, s)
    tt = t_of(dur)
    out += np.sin(2 * np.pi * 150 * tt) * 0.12
    return out


# ---------------------------------------------------------------- estación meteorológica (meteo.wav, bucle 1.6 s)
def meteo(dur=1.6):
    out = np.zeros(int(dur * SR))
    for s, f in ((0.0, 1046), (0.4, 1568), (0.85, 1318)):
        ln = int(1.0 * SR)
        tt = np.arange(ln) / SR
        add_circ(out, np.sin(2 * np.pi * f * tt) * np.exp(-tt * 6) + np.sin(2 * np.pi * f * 2.76 * tt) * np.exp(-tt * 12) * 0.15, s)
    out += circ_filter(lambda z: lp(z, 1200), np.random.default_rng(3).standard_normal(len(out))) * 0.06
    return out


# ---------------------------------------------------------------- transmisión: datos (radio.wav, bucle 1.6 s) y subida (uplink.wav)
def radio(dur=1.6):
    rng = np.random.default_rng(21)
    out = np.zeros(int(dur * SR))
    freqs = [1200, 1500, 1800, 2200, 2700, 3200]
    for k in range(int(dur * 14)):
        s = k / 14.0
        ln = int(0.035 * SR)
        tt = np.arange(ln) / SR
        f = freqs[int(rng.integers(len(freqs)))]
        sq = np.sign(np.sin(2 * np.pi * f * tt)) * 0.5 + np.sin(2 * np.pi * f * tt) * 0.5
        add_circ(out, sq * np.minimum(1, tt / 0.002) * np.exp(-tt * 40), s + (0.012 if k % 3 == 0 else 0.0))
    tt = t_of(dur)
    out += np.sin(2 * np.pi * 220 * tt) * 0.08
    return out


def uplink(dur=1.3):
    t = t_of(dur)
    p = t / dur
    f = 180 + 3200 * p ** 2.2
    sweep = np.sin(2 * np.pi * np.cumsum(f) / SR) * (p ** 0.5) * (1 - p) ** 0.6
    shimmer = hp(np.random.default_rng(4).standard_normal(len(t)), 4000) * (p ** 2) * (1 - p) * 0.4
    return sweep + shimmer


if __name__ == "__main__":
    out = sys.argv[1]
    Path(out).mkdir(parents=True, exist_ok=True)
    save(out, "motor.wav", rover())
    save(out, "drill.wav", drill())
    save(out, "laser.wav", laser())
    save(out, "radar.wav", radar())
    save(out, "panorama.wav", panorama())
    save(out, "drone_start.wav", drone_start(), 80)
    save(out, "drone.wav", drone())
    save(out, "companion.wav", companion())
    save(out, "meteo.wav", meteo())
    save(out, "radio.wav", radio())
    save(out, "uplink.wav", uplink(), 60)
