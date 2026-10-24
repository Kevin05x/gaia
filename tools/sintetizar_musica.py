"""Música original de GAIA, sintetizada por código (sin muestras ni material de terceros).
Dos piezas en bucle, con carácter distinto a propósito:
  menu : tema del menú y la pantalla de carga (do# menor, 92 BPM, oscuro, 32 compases, pulso e impacto central)
  juego: música dentro de la misión (re lidio, 104 BPM, luminosa: arpegio pulsado, bajo cálido, percusión suave y melodía)
Uso: python sintetizar_musica.py menu|juego salida.wav   (después convertir a .ogg con ffmpeg -c:a libvorbis -q:a 4)
"""

import sys
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
BPM = 92.0
BEAT = 60.0 / BPM
BAR = BEAT * 4


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def env_adsr(n, a, r, sr=SR):
    e = np.ones(n)
    na, nr = int(a * sr), int(r * sr)
    na = min(na, n // 2)
    nr = min(nr, n // 2)
    if na > 0:
        e[:na] = np.linspace(0, 1, na) ** 1.5
    if nr > 0:
        e[-nr:] *= np.linspace(1, 0, nr) ** 1.5
    return e


def lowpass(x, fc, order=2):
    sos = signal.butter(order, fc, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, fc, order=2):
    sos = signal.butter(order, fc, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def saw(f, n, phase=0.0):
    t = np.arange(n) / SR
    return 2.0 * ((f * t + phase) % 1.0) - 1.0


def add(buf, sig, start_s):
    """Suma sig en buf (estéreo n×2) con el inicio en segundos; lo que se pasa del final vuelve al principio (bucle)."""
    i = int(start_s * SR)
    n = len(buf)
    m = len(sig)
    idx = (np.arange(m) + i) % n
    if sig.ndim == 1:
        sig = np.stack([sig, sig], axis=1)
    np.add.at(buf, idx, sig)


def pad_note(f, dur, rng):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for cents, ph in ((-9, 0.0), (0, 0.33), (8, 0.66)):
        out += saw(f * 2 ** (cents / 1200), n, ph) * 0.33
    out += np.sin(2 * np.pi * f * t) * 0.4
    # Dos versiones filtradas que se mezclan con un LFO lento: el timbre «respira».
    suave = lowpass(out, 520)
    claro = lowpass(out, 1700)
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * (0.045 + 0.02 * rng.random()) * t + rng.random() * 6.28)
    out = suave * (1 - lfo) + claro * lfo
    return out * env_adsr(n, 2.6, 3.2)


def pad_stereo(f, dur, rng):
    a = pad_note(f, dur, rng)
    b = pad_note(f * 1.0007, dur, rng)
    d = int(0.011 * SR)
    left = a + 0.0
    right = np.concatenate([np.zeros(d), b[:-d]]) if d else b
    return np.stack([left, right], axis=1)


def bell(f, dur=5.0, bright=1.0, rng=None):
    n = int(dur * SR)
    t = np.arange(n) / SR
    ratio = 3.5
    index = 2.2 * bright * np.exp(-t / 0.55)
    car = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * ratio * t))
    car2 = np.sin(2 * np.pi * f * 2.0 * t + 0.6 * index * np.sin(2 * np.pi * f * 2.01 * t)) * 0.25
    out = (car + car2) * np.exp(-t / 1.6)
    out *= np.minimum(1.0, t / 0.004)
    return out


def thump(dur=0.9, depth=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    freq = 38 + 62 * np.exp(-t * 14)
    ph = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(ph) * np.exp(-t * 6.5) * depth


def boom(dur=5.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    freq = 32 + 40 * np.exp(-t * 3.0)
    ph = 2 * np.pi * np.cumsum(freq) / SR
    body = np.sin(ph) * np.exp(-t / 1.4)
    noise = lowpass(np.random.default_rng(5).standard_normal(n), 340) * np.exp(-t / 0.5) * 2.0
    return body + noise


def noise_swell(dur, lo, hi, curve=2.0, seed=1):
    n = int(dur * SR)
    rng = np.random.default_rng(seed)
    x = bandpass(rng.standard_normal(n), lo, hi)
    t = np.linspace(0, 1, n)
    return x * (t ** curve)


def wind(dur, seed=2):
    n = int(dur * SR)
    rng = np.random.default_rng(seed)
    base = rng.standard_normal(n)
    x = bandpass(base, 180, 1400)
    t = np.arange(n) / SR
    mod = 0.55 + 0.45 * np.sin(2 * np.pi * 0.07 * t + 1.0) * np.sin(2 * np.pi * 0.031 * t + 0.4)
    # estéreo con ruido distinto en cada lado
    x2 = bandpass(np.random.default_rng(seed + 10).standard_normal(n), 180, 1400)
    return np.stack([x * mod, x2 * mod[::-1]], axis=1)


def hat(dur=0.12):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = highpass(np.random.default_rng(11).standard_normal(n), 6500)
    return x * np.exp(-t * 55)


def reverb_ir(rt=3.6, seed=3, damp=3800):
    n = int(rt * SR)
    t = np.arange(n) / SR
    out = []
    for k in range(2):
        r = np.random.default_rng(seed + k).standard_normal(n)
        r = lowpass(r, damp, 1) * np.exp(-6.9 * t / rt)
        r *= np.minimum(1.0, t / 0.02)
        out.append(r)
    return np.stack(out, axis=1) / np.sqrt(n / SR * 30)


def reverb(buf, wet, rt=3.6):
    """Reverberación por convolución circular: la cola se pliega al inicio para que el bucle sea continuo."""
    ir = reverb_ir(rt)
    n = len(buf)
    out = np.zeros_like(buf)
    for c in range(2):
        for cc in range(2):
            full = signal.fftconvolve(buf[:, c], ir[:, cc])
            idx = np.arange(len(full)) % n
            tmp = np.zeros(n)
            np.add.at(tmp, idx, full)
            out[:, cc] += tmp * 0.5
    return buf * (1 - wet * 0.35) + out * wet


def pingpong(sig, delay_s, fb, taps=6, tone=2600):
    """sig mono (cualquier largo) -> estéreo con eco que alterna de lado."""
    d = int(delay_s * SR)
    n = len(sig) + d * taps
    out = np.zeros((n, 2))
    cur = sig.copy()
    for k in range(taps + 1):
        off = k * d
        side = k % 2
        out[off:off + len(cur), side] += cur
        out[off:off + len(cur), 1 - side] += cur * 0.35
        cur = lowpass(cur * fb, tone, 1)
    return out


CHORDS = {
    "C#m": [49, 52, 56],
    "A": [45, 49, 52],
    "E": [52, 56, 59],
    "B": [47, 51, 54],
    "F#m": [54, 57, 61],
    "G#": [56, 60, 63],
    "C#m9": [49, 52, 56, 63],
    "Amaj7": [45, 49, 52, 56],
    "Emaj7": [52, 56, 59, 63],
    "Bsus": [47, 52, 54],
}


def tones_for(chord, lo, hi):
    pcs = {n % 12 for n in CHORDS[chord]}
    return [n for n in range(lo, hi + 1) if n % 12 in pcs]


def render_menu(bars=32):
    rng = np.random.default_rng(42)
    total = bars * BAR
    n = int(total * SR)
    pad = np.zeros((n, 2))
    drone = np.zeros((n, 2))
    bells = np.zeros((n, 2))
    rhythm = np.zeros((n, 2))
    fx = np.zeros((n, 2))

    cycle = ["C#m", "A", "E", "B"]
    prog = cycle * 3 + ["C#m", "A", "F#m", "G#"]
    # --- bajo continuo en do# (34.65 Hz) con un poco de segundo armónico
    t = np.arange(n) / SR
    f1 = round(midi(25) * total) / total  # ciclos enteros: el bajo empalma sin salto al repetirse
    f2 = round(midi(37) * total) / total
    sub = np.sin(2 * np.pi * f1 * t) * 0.5 + np.sin(2 * np.pi * f2 * t) * 0.14
    sub *= 0.6 + 0.4 * np.sin(2 * np.pi * (1.0 / (BAR * 8)) * t - 1.2)
    drone[:, 0] += sub * 0.55
    drone[:, 1] += sub * 0.55
    # --- acordes de 2 compases
    for i, name in enumerate(prog):
        start = i * 2 * BAR
        notes = list(CHORDS[name]) + [CHORDS[name][0] - 12, CHORDS[name][2] + 12]
        level = 0.22 if i < 4 else (0.28 if i < 8 else 0.34)
        if i >= 12:
            level = 0.3
        for k, nn in enumerate(notes):
            add(pad, pad_stereo(midi(nn), 2 * BAR + 3.4, rng) * (level if k < 3 else level * 0.65), start - 0.2)
    # --- viento suave todo el tiempo
    wnd = wind(total, 7) * 0.05
    fx += wnd
    # --- subida y golpe central (compás 17)
    riser_start = 14 * BAR
    sw = noise_swell(3 * BAR, 500, 5200, 2.4, 9)
    add(fx, np.stack([sw, sw[::-1]], axis=1) * 0.2, riser_start)
    add(fx, np.stack([boom(), boom() * 0.95], axis=1) * 0.5, 16 * BAR)
    add(fx, thump(1.0, 1.3), 16 * BAR)
    # --- pulso de latido desde el compás 9 hasta el 28 (más fuerte tras el golpe)
    for bar in range(8, 28):
        gain = 0.22 if bar < 16 else 0.38
        if bar >= 24:
            gain *= max(0.0, 1.0 - (bar - 23) / 5.0)
        for beat in (0, 2):
            when = bar * BAR + beat * BEAT
            add(rhythm, thump(0.9, gain), when)
            add(rhythm, thump(0.7, gain * 0.5), when + BEAT * 0.75)
    # --- notas altas tipo campana, cada vez más presentes
    for i, name in enumerate(prog):
        density = [0.4, 0.55, 0.7, 0.9][min(3, i // 4)] if i < 16 else 0.8
        highs = tones_for(name, 72, 88)
        positions = [0, 1.5, 3, 4.5, 6, 7]
        for pos in positions:
            if rng.random() > density * (0.5 if i < 2 else 1.0):
                continue
            nn = int(rng.choice(highs))
            vel = 0.5 + 0.4 * rng.random()
            when = i * 2 * BAR + pos * BEAT
            b = bell(midi(nn), 6.0, 0.9) * 0.16 * vel
            add(bells, pingpong(b, BEAT * 0.75, 0.5, 5), when)
    # --- arpegio corto de campanas en la parte más intensa (compases 17-24)
    for i in range(8, 12):
        name = prog[i]
        arp = tones_for(name, 60, 76)
        for step in range(16):
            if step % 2 == 1 and rng.random() < 0.45:
                continue
            nn = arp[step % len(arp)]
            when = i * 2 * BAR + step * BEAT * 0.5
            b = bell(midi(nn + 12), 3.0, 0.7) * 0.07
            add(bells, pingpong(b, BEAT * 0.75, 0.4, 3), when)
        # brillo de 8vos
        for step in range(16):
            if i >= 8:
                add(rhythm, hat() * 0.05 * (1.2 if step % 2 == 0 else 0.7), i * 2 * BAR + step * BEAT * 0.5 + BEAT * 0.25)

    mix = pad + drone + bells + rhythm + fx
    mix = reverb(pad * 1.0 + bells * 0.9 + fx * 0.7, 0.8, 3.8) + drone * 1.0 + rhythm * 0.9
    return mix



# ---------------------------------------------------------------------------
# Música de misión: otra tonalidad (re lidio, luminoso), otro tempo (104 BPM) y otro instrumental
# (arpegio pulsado, bajo cálido, percusión suave y melodía principal). Es la pieza «de aventura».
# ---------------------------------------------------------------------------
BPM_J = 104.0
BEAT_J = 60.0 / BPM_J
BAR_J = BEAT_J * 4


def pluck(f, dur=1.4, bright=1.0):
    """Nota pulsada de sintetizador: dientes de sierra detonados cuyo brillo cae rápido."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = saw(f * 2 ** (-6 / 1200), n, 0.1) * 0.5 + saw(f * 2 ** (6 / 1200), n, 0.6) * 0.5
    x += np.sin(2 * np.pi * f * t) * 0.35
    oscura = lowpass(x, min(900, f * 3.2))
    clara = lowpass(x, min(6500, f * 9 * bright))
    mezcla = np.exp(-t / 0.13)
    out = clara * mezcla + oscura * (1 - mezcla)
    ataque = np.minimum(1.0, t / 0.004)
    return out * np.exp(-t / 0.55) * ataque


def cuerdas(f, dur, rng):
    """Colchón cálido, de ataque corto, para sostener cada acorde."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for cents, ph in ((-7, 0.0), (0, 0.4), (7, 0.7)):
        x += saw(f * 2 ** (cents / 1200), n, ph) * 0.3
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * t + rng.random() * 6.28)
    x = lowpass(x, 1100) * (1 - lfo) + lowpass(x, 2200) * lfo
    return x * env_adsr(n, 0.7, 1.4)


def bajo_calido(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) + 0.1 * np.sin(2 * np.pi * 3 * f * t)
    e = np.minimum(1.0, t / 0.008) * np.exp(-t / (dur * 0.8))
    return lowpass(x * e, 700)


def bombo(gain=1.0):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    freq = 46 + 90 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(freq) / SR
    click = highpass(np.random.default_rng(3).standard_normal(n), 2500) * np.exp(-t * 180) * 0.12
    return (np.sin(ph) * np.exp(-t * 9) + click) * gain


def palmada(gain=1.0):
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    x = bandpass(np.random.default_rng(4).standard_normal(n), 900, 4200)
    return x * (np.exp(-t * 26) + 0.5 * np.exp(-((t - 0.012) * 400) ** 2)) * gain


def maraca(gain=1.0):
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    x = highpass(np.random.default_rng(12).standard_normal(n), 7000)
    return x * np.exp(-t * 70) * gain


def lead(f, dur, rng):
    """Melodía principal: triángulo + senoidal con vibrato tardío."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1.0, t / 0.35)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.sin(ph) * 0.7 + (2 / np.pi) * np.arcsin(np.sin(ph)) * 0.35 + np.sin(2 * ph) * 0.08
    return x * env_adsr(n, 0.02, min(0.5, dur * 0.4))


# acorde: (nombre, fundamental del bajo, notas del colchón, notas del arpegio)
ACORDES_J = {
    "Dmaj7": (38, [57, 61, 64, 66], [62, 66, 69, 73]),
    "Bm7": (35, [54, 57, 61, 66], [59, 62, 66, 69]),
    "Gmaj7": (43, [55, 59, 62, 66], [55, 59, 62, 66]),
    "A6": (45, [57, 61, 64, 66], [57, 61, 64, 66]),
}
PROG_J = ["Dmaj7", "Bm7", "Gmaj7", "A6"]
# frases de la melodía por compás: (tiempo, nota midi, duración en pulsos)
FRASES_J = [
    [(0.0, 81, 1.5), (1.5, 78, 0.5), (2.0, 81, 1.0), (3.0, 83, 1.0)],      # Dmaj7
    [(0.0, 85, 2.0), (2.0, 83, 1.0), (3.0, 81, 1.0)],                       # Bm7
    [(0.0, 83, 1.5), (1.5, 81, 0.5), (2.0, 78, 1.0), (3.0, 79, 1.0)],      # Gmaj7
    [(0.0, 78, 1.0), (1.0, 81, 1.0), (2.0, 81, 2.0)],                       # A6
]
FRASES_J2 = [
    [(0.0, 86, 1.5), (1.5, 85, 0.5), (2.0, 83, 1.0), (3.0, 81, 1.0)],
    [(0.0, 83, 1.0), (1.0, 85, 1.0), (2.0, 90, 2.0)],
    [(0.0, 86, 1.0), (1.0, 83, 1.0), (2.0, 79, 1.0), (3.0, 83, 1.0)],
    [(0.0, 85, 2.0), (2.0, 81, 1.0), (3.0, 78, 1.0)],
]
ARP_J = [0, 2, 1, 3, 2, 3, 1, 2]


def render_game(bars=32):
    rng = np.random.default_rng(11)
    total = bars * BAR_J
    n = int(total * SR)
    cuer = np.zeros((n, 2))
    arp = np.zeros((n, 2))
    bajo = np.zeros((n, 2))
    perc = np.zeros((n, 2))
    mel = np.zeros((n, 2))
    for bar in range(bars):
        nombre = PROG_J[bar % 4]
        raiz, cama, notas = ACORDES_J[nombre]
        t0 = bar * BAR_J
        seccion = bar // 8  # 0: apertura, 1: entra bajo+ritmo, 2: melodía, 3: variación y cierre
        # colchón: un acorde por compás
        for k, nn in enumerate(cama):
            v = cuerdas(midi(nn), BAR_J + 1.6, rng) * (0.10 if seccion != 3 else 0.09)
            add(cuer, np.stack([v, np.roll(v, int(0.009 * SR))], axis=1), t0 - 0.05)
        # arpegio pulsado en corcheas
        for step in range(8):
            if seccion == 0 and step % 2 == 1 and bar < 4:
                continue
            nn = notas[ARP_J[step]] + (12 if step == 5 else 0)
            acento = 1.0 if step % 4 == 0 else 0.7
            p = pluck(midi(nn + 12), 1.3, 1.0) * 0.11 * acento
            add(arp, pingpong(p, BEAT_J * 0.75, 0.33, 3), t0 + step * BEAT_J / 2)
        # bajo: desde la sección 1
        if seccion >= 1:
            for pos, dur_b, oct_b in ((0.0, 1.4, 0), (2.5, 0.8, 0), (3.0, 0.9, 12)):
                if pos == 3.0 and bar % 2 == 0:
                    continue
                b = bajo_calido(midi(raiz + oct_b), dur_b * BEAT_J * 1.2) * 0.42
                add(bajo, np.stack([b, b], axis=1), t0 + pos * BEAT_J)
        # percusión suave
        if seccion >= 1:
            for beat in (0, 2):
                add(perc, bombo(0.85), t0 + beat * BEAT_J)
            for beat in (1, 3):
                add(perc, palmada(0.2 if seccion == 1 else 0.26), t0 + beat * BEAT_J)
            for step in range(8):
                g = 0.05 if step % 2 == 0 else 0.03
                add(perc, np.stack([maraca(g), maraca(g * 0.7)], axis=1), t0 + step * BEAT_J / 2 + BEAT_J * 0.25)
        # melodía principal
        if seccion >= 2:
            frases = FRASES_J if seccion == 2 else FRASES_J2
            for pos, nn, dur_b in frases[bar % 4]:
                v = lead(midi(nn), dur_b * BEAT_J * 1.05, rng) * (0.13 if seccion == 2 else 0.15)
                add(mel, pingpong(v, BEAT_J * 0.75, 0.3, 3), t0 + pos * BEAT_J)
    # paso largo y suave de aire al inicio de cada sección
    aire = np.zeros((n, 2))
    for s in range(4):
        sw = noise_swell(2 * BAR_J, 600, 5200, 2.0, 40 + s)
        add(aire, np.stack([sw, sw[::-1]], axis=1) * 0.05, (s * 8 - 2) * BAR_J % total)
    humedo = reverb(cuer + arp * 0.8 + mel + aire, 0.55, 2.6)
    return humedo + bajo + perc * 1.6



def finish(mix, peak_db=-2.0):
    mix = mix - mix.mean(axis=0, keepdims=True)
    mix = highpass_stereo(mix, 24)
    p = np.max(np.abs(mix))
    mix = mix / p * 10 ** (peak_db / 20)
    # suavizado final de picos
    mix = np.tanh(mix * 1.15) / np.tanh(1.15)
    return mix


def highpass_stereo(mix, fc):
    # Filtro circular: se filtra una copia triple y se toma la central, para no crear un salto en el empalme del bucle.
    n = len(mix)
    out = []
    for c in range(2):
        tri = np.concatenate([mix[:, c]] * 3)
        out.append(highpass(tri, fc, 2)[n:2 * n])
    return np.stack(out, axis=1)


def save(path, mix):
    pcm = (np.clip(mix, -1, 1) * 32767).astype(np.int16)
    wavfile.write(path, SR, pcm)


if __name__ == "__main__":
    which = sys.argv[1]
    out = sys.argv[2]
    mix = render_menu() if which == "menu" else render_game()
    mix = finish(mix, -2.0 if which == "menu" else -3.0)
    save(out, mix)
    print(which, len(mix) / SR, "s")
