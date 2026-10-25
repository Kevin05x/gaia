#!/usr/bin/env python3
"""Genera content/mapa.json: el mapa grande de 71x71 casillas con las 3 zonas de la historia.

Conserva tal cual el mapa original (los 9 objetivos JZ-01..JZ-09, sus 10 obstáculos, la estación en (-9,-9) y el
rover en (0,0)) y le añade objetivos y rocas por zona con una semilla fija, así que el resultado es siempre el mismo.
Uso:  python tools/generar_mapa.py > content/mapa.json
"""
import json
import random
import sys
from collections import deque

LIM = 35
ESTACION = (-9, -9)
INICIO = (0, 0)
ZONAS = [  # cada casilla es de la zona cuyo centro queda más cerca
    ("orilla", (-12, -12)),
    ("falla", (18, 2)),
    ("nucleo", (10, 26)),
]
# Objetivos nuevos por zona: (tipo, revelado). Los enterrados guardan hielo y xenolito: están lejos de la base.
NUEVOS = {
    "orilla": [("rock", True), ("rock", True), ("mineral", True), ("mineral", False), ("buried", False), ("rock", True)],
    "falla": [("rock", True), ("rock", True), ("rock", False), ("mineral", True), ("mineral", False), ("mineral", False),
              ("buried", False), ("buried", False), ("buried", False), ("buried", False), ("buried", False),
              ("rock", True), ("buried", False), ("mineral", True)],
    "nucleo": [("rock", True), ("rock", False), ("rock", True), ("mineral", True), ("mineral", False), ("mineral", False),
               ("buried", False), ("buried", False), ("buried", False), ("buried", False)],
}
OBSTACULOS_ORIGINALES = [[-1, -2], [-2, -2], [4, -1], [4, 0], [4, 1], [-3, 3], [-4, 3], [0, 4], [1, 4], [6, -6]]
OBJETIVOS_ORIGINALES = [
    ("JZ-01", (2, -2), "rock", True), ("JZ-02", (-3, -2), "rock", True), ("JZ-03", (5, -4), "rock", True),
    ("JZ-04", (-5, 3), "rock", True), ("JZ-05", (-2, -6), "buried", False), ("JZ-06", (6, 2), "mineral", True),
    ("JZ-07", (-6, -5), "buried", False), ("JZ-08", (1, 6), "rock", True), ("JZ-09", (7, -1), "mineral", False),
]
VECINOS = [(0, -1), (0, 1), (-1, 0), (1, 0)]
# Nidos de los monstruos (bloque C): casilla deseada; si está ocupada se usa la libre más cercana. Lejos de la base.
NIDOS = [("nido_falla_1", (25, -10)), ("nido_falla_2", (28, 9)), ("nido_nucleo_1", (4, 31)), ("nido_nucleo_2", (18, 31)),
         ("nido_nucleo_3", (-3, 22))]


def zona_de(c):
    return min(ZONAS, key=lambda z: (c[0] - z[1][0]) ** 2 + (c[1] - z[1][1]) ** 2)[0]


def dentro(c, margen=0):
    return abs(c[0]) <= LIM - margen and abs(c[1]) <= LIM - margen


def dist(a, b):
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


def alcanzables(bloqueadas):
    vistas = {INICIO}
    cola = deque([INICIO])
    while cola:
        x, y = cola.popleft()
        for dx, dy in VECINOS:
            s = (x + dx, y + dy)
            if s in vistas or not dentro(s) or s in bloqueadas:
                continue
            vistas.add(s)
            cola.append(s)
    return vistas


def main():
    rng = random.Random(20261024)
    obstaculos = {tuple(o) for o in OBSTACULOS_ORIGINALES}
    objetivos = [(i, c, t, r) for i, c, t, r in OBJETIVOS_ORIGINALES]
    ocupadas = set(obstaculos) | {c for _, c, _, _ in objetivos} | {ESTACION, INICIO}
    n = len(objetivos)
    # Objetivos nuevos: separados entre sí y de la base, lejos del borde.
    for zona, lista in NUEVOS.items():
        for tipo, revelado in lista:
            for _ in range(5000):
                c = (rng.randint(-LIM + 3, LIM - 3), rng.randint(-LIM + 3, LIM - 3))
                if zona_de(c) != zona or c in ocupadas:
                    continue
                if dist(c, ESTACION) < 9 or dist(c, INICIO) < 6:
                    continue
                if any(dist(c, o[1]) < 6 for o in objetivos):
                    continue
                n += 1
                objetivos.append(("JZ-%02d" % n, c, tipo, revelado))
                ocupadas.add(c)
                break
            else:
                sys.exit("no cabe un objetivo en " + zona)
    reservadas = set()  # casillas que las rocas nuevas no pueden tapar
    for _, c, _, _ in objetivos:
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                reservadas.add((c[0] + dx, c[1] + dy))
    for dx in range(-7, 8):  # la base: aquí se construye
        for dy in range(-7, 8):
            reservadas.add((ESTACION[0] + dx, ESTACION[1] + dy))
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            reservadas.add((INICIO[0] + dx, INICIO[1] + dy))
    # Rocas: grupos pequeños que serpentean (2 a 6 casillas), más densos hacia la falla y el núcleo.
    grupos = 0
    densidad = {"orilla": 14, "falla": 20, "nucleo": 18}
    for zona, cuantos in densidad.items():
        hechos = 0
        intentos = 0
        while hechos < cuantos and intentos < 4000:
            intentos += 1
            c = (rng.randint(-LIM + 1, LIM - 1), rng.randint(-LIM + 1, LIM - 1))
            if zona_de(c) != zona or c in reservadas or c in ocupadas:
                continue
            grupo = [c]
            for _ in range(rng.randint(1, 5)):
                x, y = grupo[-1]
                dx, dy = rng.choice(VECINOS)
                s = (x + dx, y + dy)
                if dentro(s, 1) and s not in reservadas and s not in ocupadas and s not in grupo:
                    grupo.append(s)
            prueba = obstaculos | set(grupo)
            if len(alcanzables(prueba | {ESTACION})) < 0.9 * (2 * LIM + 1) ** 2 - len(prueba):
                continue  # no encierres zonas
            obstaculos |= set(grupo)
            ocupadas |= set(grupo)
            hechos += 1
            grupos += 1
    vistas = alcanzables(obstaculos | {ESTACION} | {c for _, c, _, _ in objetivos})
    for i, c, _, _ in objetivos:
        if not any((c[0] + dx, c[1] + dy) in vistas for dx, dy in VECINOS):
            sys.exit("objetivo inalcanzable: " + i)
    nidos = []
    prohibidas = set(ocupadas) | {c for _, c, _, _ in objetivos}
    for id_nido, deseada in NIDOS:
        for radio in range(0, 6):
            libres = [(deseada[0] + dx, deseada[1] + dy) for dx in range(-radio, radio + 1) for dy in range(-radio, radio + 1)
                      if max(abs(dx), abs(dy)) == radio and dentro((deseada[0] + dx, deseada[1] + dy), 2)
                      and (deseada[0] + dx, deseada[1] + dy) not in prohibidas
                      and (deseada[0] + dx, deseada[1] + dy) in vistas]
            if libres:
                nidos.append((id_nido, libres[0]))
                prohibidas.add(libres[0])
                break
        else:
            sys.exit("no cabe el nido " + id_nido)
    originales = [tuple(o) for o in OBSTACULOS_ORIGINALES]
    nuevos = sorted(o for o in obstaculos if o not in originales)
    salida = {
        "version": 3,
        "estado": "provisional (24 oct 2026): mapa de 71x71 casillas con las 3 zonas de la historia (orilla del lago, falla del "
                  "glaciar y núcleo del cráter). Los 9 objetivos y 10 obstáculos del mapa original se conservan; el resto lo "
                  "genera tools/generar_mapa.py con semilla fija. Los tipos son ids del contrato con la vista: rock, mineral, buried.",
        "limites": {"min": [-LIM, -LIM], "max": [LIM, LIM]},
        "inicio_rover": list(INICIO),
        "estacion": list(ESTACION),
        "zonas": [{"id": z, "centro": list(c)} for z, c in ZONAS],
        "nidos": [{"id": i, "casilla": list(c), "zona": zona_de(c)} for i, c in nidos],
        "obstaculos": [list(o) for o in originales] + [list(o) for o in nuevos],
        "objetivos": [{"id": i, "casilla": list(c), "tipo": t, "revelado": r} for i, c, t, r in objetivos],
    }
    # Un objetivo / obstáculo por línea para que los cambios se lean bien en git.
    texto = json.dumps(salida, ensure_ascii=False, indent=2)
    import re
    texto = re.sub(r"\[\s+(-?\d+),\s+(-?\d+)\s+\]", r"[\1, \2]", texto)
    texto = re.sub(r'\{\s+"id": ("[^"]+"),\s+"casilla": (\[[^\]]+\]),\s+"tipo": ("[^"]+"),\s+"revelado": (true|false)\s+\}',
                   r'{ "id": \1, "casilla": \2, "tipo": \3, "revelado": \4 }', texto)
    texto = re.sub(r'\{\s+"id": ("[^"]+"),\s+"casilla": (\[[^\]]+\]),\s+"zona": ("[^"]+")\s+\}', r'{ "id": \1, "casilla": \2, "zona": \3 }', texto)
    texto = re.sub(r'\{\s+"id": ("[^"]+"),\s+"centro": (\[[^\]]+\])\s+\}', r'{ "id": \1, "centro": \2 }', texto)
    print(texto)
    sys.stderr.write("objetivos: %d, obstáculos: %d, zonas: %s\n" % (len(objetivos), len(obstaculos), {
        z: sum(1 for x in range(-LIM, LIM + 1) for y in range(-LIM, LIM + 1) if zona_de((x, y)) == z) for z, _ in ZONAS}))


if __name__ == "__main__":
    main()
