"""Música original de GAIA, sintetizada por código (sin muestras ni material de terceros).
Ambiente oscuro en do# menor, ~92 BPM, crecimiento lento. Dos piezas en bucle:
  menu : tema del menú y la pantalla de carga (32 compases, con pulso e impacto central)
  juego: ambiente dentro de la misión (más quieto, sin ritmo)
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


def bass_pulse(root_midi, bars_len, gate_pattern, gain=0.2):
    """Bajo de corcheas con compuerta suave: da movimiento sin romper el ambiente."""
    n = int(bars_len * BAR * SR)
    t = np.arange(n) / SR
    f = midi(root_midi)
    tone = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) + 0.12 * np.sin(2 * np.pi * 3 * f * t)
    eighth = BEAT / 2
    env = np.zeros(n)
    for k in range(int(bars_len * 8)):
        if not gate_pattern[k % len(gate_pattern)]:
            continue
        s = int(k * eighth * SR)
        ln = int(eighth * 0.92 * SR)
        e = np.exp(-np.arange(ln) / SR * 5.5) * np.minimum(1.0, np.arange(ln) / (0.01 * SR))
        env[s:s + ln] = np.maximum(env[s:s + ln], e[:max(0, min(ln, n - s))])
    return lowpass(tone * env, 420) * gain


def render_game(bars=36):
    """Ambiente de la misión: la misma familia que el menú (do# menor, 92 BPM) pero con pulso suave, bajo de corcheas,
    arpegios de campanas y un ligero brillo rítmico durante todo el recorrido."""
    rng = np.random.default_rng(7)
    total = bars * BAR
    n = int(total * SR)
    pad = np.zeros((n, 2))
    drone = np.zeros((n, 2))
    bells = np.zeros((n, 2))
    rhythm = np.zeros((n, 2))
    fx = np.zeros((n, 2))
    t = np.arange(n) / SR
    f1 = round(midi(25) * total) / total
    sub = np.sin(2 * np.pi * f1 * t) * 0.45
    sub *= 0.55 + 0.45 * np.sin(2 * np.pi * (1.0 / (BAR * 12)) * t)
    drone[:, 0] += sub * 0.4
    drone[:, 1] += sub * 0.4
    prog = ["C#m9", "Amaj7", "Emaj7", "Bsus"] * 4 + ["C#m9", "Amaj7"]
    roots = {"C#m9": 37, "Amaj7": 33, "Emaj7": 40, "Bsus": 35}
    patterns = [
        [1, 0, 1, 1, 0, 1, 0, 1],
        [1, 0, 0, 1, 1, 0, 1, 0],
    ]
    for i in range(bars // 2):
        name = prog[i % len(prog)]
        notes = list(CHORDS[name]) + [CHORDS[name][0] - 12]
        for k, nn in enumerate(notes):
            add(pad, pad_stereo(midi(nn), 2 * BAR + 3.6, rng) * 0.19, i * 2 * BAR - 0.3)
        # bajo de corcheas (desde el segundo acorde; más lleno en la segunda mitad)
        if i >= 1:
            gain = 0.34 if i < 9 else 0.46
            b = bass_pulse(roots[name], 2, patterns[i % 2], gain)
            add(rhythm, np.stack([b, b], axis=1), i * 2 * BAR)
        # arpegio de campanas, 8vos
        arp = tones_for(name, 60, 79)
        for step in range(16):
            if step % 4 == 3 and rng.random() < 0.5:
                continue
            nn = arp[(step * 2 + i) % len(arp)] + 12
            vel = 0.6 + 0.4 * rng.random()
            bl = bell(midi(nn), 3.0, 0.7) * 0.055 * vel
            add(bells, pingpong(bl, BEAT * 0.75, 0.38, 3), i * 2 * BAR + step * BEAT * 0.5)
        # melodía de campanas más lenta por encima
        highs = tones_for(name, 74, 91)
        for pos in (0.0, 2.5, 4.0, 6.5):
            if rng.random() < 0.8:
                nn = int(rng.choice(highs))
                bl = bell(midi(nn), 6.0, 0.9) * 0.14 * (0.55 + 0.45 * rng.random())
                add(bells, pingpong(bl, BEAT * 0.75, 0.5, 5), i * 2 * BAR + pos * BEAT)
    # latido suave y brillo rítmico durante toda la pieza
    for bar in range(bars):
        for beat in (0, 2):
            add(rhythm, thump(0.8, 0.34), bar * BAR + beat * BEAT)
        for step in range(8):
            add(rhythm, hat() * (0.07 if step % 2 == 0 else 0.04), bar * BAR + step * BEAT * 0.5 + BEAT * 0.25)
    fx += wind(total, 21) * 0.06
    for k in range(3):
        sw = noise_swell(5 * BAR, 300, 2400, 1.6, 30 + k)
        sw = sw * np.linspace(1, 0, len(sw)) ** 0.3
        add(fx, np.stack([sw, sw[::-1]], axis=1) * 0.06, (k * 12 + 3) * BAR)
    mix = reverb(pad + bells + fx * 0.8, 0.8, 4.0) + drone + rhythm * 2.8
    return mix


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
