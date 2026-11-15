"""Graba las voces de radio de content/voces.json (plan de mejoras 9.2) con el método de la historia de Tony:
español con voces de Windows (Microsoft Raúl para Houston, Microsoft Pablo para Perseverance) e inglés con Piper
(John para Houston, Joe para Perseverance), y un efecto de walkie-talkie: banda estrecha, saturación suave y ráfagas de
estática al abrir y cerrar. Si Microsoft Raúl no está instalado, Houston en español usa la voz de Piper es_MX «ald»
(se avisa al final: se puede regrabar cuando se instale el paquete de voz «Español (México)» de Windows).

Uso:
  py tools/voces/generar_voces.py --modelos <carpeta con los .onnx de Piper> [--piper-py <carpeta con piper-tts>]
Los modelos: en_US-john-medium, en_US-joe-medium y es_MX-ald-medium (huggingface.co/rhasspy/piper-voices).
Piper: el paquete de Python piper-tts 1.5 o superior (Joe no funciona con el piper.exe 1.2 de 2023).
Escribe assets/voces/<marte|luna|comun>/<evento>_<n>_<sha12>.wav (22 050 Hz, mono, 16 bits). Hecho con ayuda de Claude.
"""
import argparse
import hashlib
import json
import math
import os
import random
import struct
import subprocess
import sys
import tempfile
import wave

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TASA = 22050
VOCES_PIPER = {("en", "houston"): "en_US-john-medium", ("en", "perseverance"): "en_US-joe-medium",
               ("es", "houston"): "es_MX-ald-medium"}  # la última, solo si falta Microsoft Raúl
VOCES_WINDOWS = {("es", "houston"): "Raul", ("es", "perseverance"): "Pablo"}


def sha12(quien, texto):
    return hashlib.sha256((quien + "\n" + texto).encode("utf-8")).hexdigest()[:12]


def carpeta_de(evento, destino_override):
    return destino_override


def lineas(datos):
    """(carpeta, evento, n, quien, idioma, texto) de todas las voces."""
    for evento, ev in datos["eventos"].items():
        destinos = ev.get("destinos", ["marte", "luna"])
        grupos = []
        if "luna" in ev:
            grupos = [("marte", ev["variantes"]), ("luna", ev["luna"])]
        elif destinos == ["marte", "luna"]:
            grupos = [("comun", ev["variantes"])]
        else:
            grupos = [(destinos[0], ev["variantes"])]
        for carpeta, variantes in grupos:
            for n, variante in enumerate(variantes, start=1):
                for idioma in ("es", "en"):
                    yield carpeta, evento, n, ev["quien"], idioma, variante[idioma]


def leer_wav(ruta):
    with wave.open(ruta, "rb") as w:
        canales, ancho, tasa, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        crudo = w.readframes(n)
    if ancho != 2:
        raise SystemExit("solo WAV de 16 bits: " + ruta)
    datos = struct.unpack("<%dh" % (len(crudo) // 2), crudo)
    mono = [sum(datos[i:i + canales]) / canales / 32768.0 for i in range(0, len(datos), canales)]
    if tasa == TASA:
        return mono
    salida = []  # remuestreo lineal
    paso = tasa / TASA
    t = 0.0
    while t < len(mono) - 1:
        i = int(t)
        f = t - i
        salida.append(mono[i] * (1 - f) + mono[i + 1] * f)
        t += paso
    return salida


def biquad(x, tipo, fc, q=0.707):
    w0 = 2 * math.pi * fc / TASA
    alfa = math.sin(w0) / (2 * q)
    c = math.cos(w0)
    if tipo == "paso_bajo":
        b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
    else:  # paso_alto
        b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
    a0, a1, a2 = 1 + alfa, -2 * c, 1 - alfa
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = []
    x1 = x2 = y1 = y2 = 0.0
    for v in x:
        s = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, s
        y.append(s)
    return y


def walkie(voz, semilla):
    """Banda estrecha (300-3000 Hz), saturación suave, estática baja durante la frase y ráfagas al abrir y cerrar."""
    rng = random.Random(semilla)
    voz = biquad(biquad(voz, "paso_alto", 300.0), "paso_bajo", 3000.0)
    pico = max(1e-6, max(abs(v) for v in voz))
    voz = [math.tanh(2.2 * v / pico) / math.tanh(2.2) for v in voz]
    abre, cierra = int(0.16 * TASA), int(0.12 * TASA)
    total = abre + len(voz) + cierra
    ruido = biquad([rng.uniform(-1, 1) for _ in range(total)], "paso_alto", 900.0)
    ruido = biquad(ruido, "paso_bajo", 4200.0)
    salida = []
    for i in range(total):
        if i < abre:
            nivel = 0.32 * (1.0 - 0.5 * i / abre)
            v = 0.0
        elif i < abre + len(voz):
            nivel = 0.035
            v = voz[i - abre] * 0.82
        else:
            nivel = 0.26 * (1.0 - (i - abre - len(voz)) / cierra)
            v = 0.0
        salida.append(max(-1.0, min(1.0, v + ruido[i] * nivel)))
    pico = max(1e-6, max(abs(v) for v in salida))
    return [v * 0.9 / pico for v in salida]


def guardar(ruta, muestras):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TASA)
        w.writeframes(struct.pack("<%dh" % len(muestras), *[int(v * 32767) for v in muestras]))


def sintetizar(idioma, quien, texto, salida, args, usadas):
    voz_win = VOCES_WINDOWS.get((idioma, quien))
    if voz_win:
        ps = os.path.join(RAIZ, "tools", "voces", "hablar_windows.ps1")
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps, "-Voz", voz_win,
                            "-Texto", texto, "-Salida", salida], capture_output=True)
        if r.returncode == 0:
            usadas[(idioma, quien)] = "Microsoft " + voz_win + " (Windows)"
            return
        if (idioma, quien) not in VOCES_PIPER:
            raise SystemExit("falta la voz de Windows «%s» y no hay voz de Piper de respaldo" % voz_win)
    modelo = VOCES_PIPER[(idioma, quien)]
    entorno = dict(os.environ)
    if args.piper_py:
        entorno["PYTHONPATH"] = args.piper_py
    r = subprocess.run([sys.executable, "-m", "piper", "--model", os.path.join(args.modelos, modelo + ".onnx"),
                        "--output_file", salida, "--", texto], capture_output=True, env=entorno)
    if r.returncode != 0:
        raise SystemExit("Piper falló con %s: %s" % (modelo, r.stderr.decode("utf-8", "replace")[-400:]))
    usadas[(idioma, quien)] = "Piper " + modelo


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--modelos", required=True)
    p.add_argument("--piper-py", default="")
    args = p.parse_args()
    datos = json.load(open(os.path.join(RAIZ, "content", "voces.json"), encoding="utf-8"))
    usadas = {}
    hechas = 0
    with tempfile.TemporaryDirectory() as tmp:
        for carpeta, evento, n, quien, idioma, texto in lineas(datos):
            crudo = os.path.join(tmp, "crudo.wav")
            sintetizar(idioma, quien, texto, crudo, args, usadas)
            nombre = "%s_%d_%s.wav" % (evento, n, sha12(quien, texto))
            guardar(os.path.join(RAIZ, "assets", "voces", carpeta, nombre), walkie(leer_wav(crudo), nombre))
            hechas += 1
    print("%d voces grabadas." % hechas)
    for (idioma, quien), voz in sorted(usadas.items()):
        print("  %s · %s: %s" % (idioma, quien, voz))
    if usadas.get(("es", "houston"), "").startswith("Piper"):
        print("AVISO: Microsoft Raúl no está instalado; Houston en español usa Piper es_MX-ald. Para regrabar como en la "
              "historia, instalar la voz «Español (México)» en Windows y volver a ejecutar este script.")


if __name__ == "__main__":
    main()
