# Integra los materiales de las escenas del proyecto (estación, compañero, dron y rover de bloques) con el entorno de
# Marte: tinte de polvo en las piezas claras, PBR por tipo de pieza (paneles solares brillantes, metal gris, goma mate)
# y ventanas con un brillo suave. Solo cambia las propiedades de los StandardMaterial3D; no toca mallas ni nodos.
# Es idempotente: marca cada escena con un comentario y no se vuelve a aplicar.
# uso: python materiales_entorno.py
import os, re

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")
ESCENAS = ["scenes/b/assets/models/station.tscn", "scenes/b/assets/models/companion.tscn",
           "scenes/b/assets/models/drone.tscn", "scenes/b/assets/models/rover.tscn"]
MARCA = "; materiales_entorno: polvo y PBR aplicados"
POLVO = (0.95, 0.89, 0.81)  # mismo tinte que los edificios (mejorar_edificios.py)


def clasificar(r, g, b):
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    if b > r + 0.1 and lum < 0.4:
        return "panel"  # paneles solares y cristal azul oscuro
    if g > r + 0.15 and b > r + 0.1 and lum > 0.5:
        return "ventana"  # verde agua claro: pantallas y ventanas
    if lum < 0.25:
        return "oscuro"  # goma, ruedas, juntas
    if abs(r - b) < 0.07 and abs(r - g) < 0.05 and lum < 0.72:
        return "metal"  # grises neutros (los beis claros son paneles pintados, no metal)
    if r > g + 0.2:
        return "acento"  # naranja y rojo
    return "cuerpo"  # blancos y beis cálidos


def propiedades(tipo, r, g, b):
    """Devuelve (color, rugosidad, metal, emisión o None)."""
    if tipo == "panel":
        return (r, g, b), 0.22, 0.35, None
    if tipo == "ventana":
        return (r * 0.6, g * 0.6, b * 0.6), 0.15, 0.0, (r, g, b, 0.6)
    if tipo == "oscuro":
        return (r, g * 0.97, b * 0.93), 0.72, 0.05, None
    if tipo == "metal":
        return (r * POLVO[0], g * POLVO[1], b * POLVO[2]), 0.5, 0.45, None
    if tipo == "acento":
        return (r * 0.95, g * 0.9, b * 0.86), 0.6, 0.1, None
    return (r * POLVO[0], g * POLVO[1], b * POLVO[2]), 0.8, 0.0, None


def procesar(ruta):
    texto = open(ruta, encoding="utf8").read()
    if MARCA in texto:
        print("ya aplicado:", ruta)
        return {}
    cuenta = {}

    def bloque(m):
        cuerpo = m.group(2)
        c = re.search(r"albedo_color = Color\(([\d.e-]+), ([\d.e-]+), ([\d.e-]+), ([\d.e-]+)\)", cuerpo)
        if not c:
            return m.group(0)
        r, g, b, a = (float(x) for x in c.groups())
        tipo = clasificar(r, g, b)
        cuenta[tipo] = cuenta.get(tipo, 0) + 1
        col, rug, met, emi = propiedades(tipo, r, g, b)
        lineas = [l for l in cuerpo.split("\n") if l and not l.startswith(("albedo_color", "roughness", "metallic", "emission"))]
        lineas.insert(0, "albedo_color = Color(%.6g, %.6g, %.6g, %.6g)" % (col[0], col[1], col[2], a))
        lineas.append("metallic = %.2f" % met)
        lineas.append("roughness = %.2f" % rug)
        if emi:
            lineas.append("emission_enabled = true")
            lineas.append("emission = Color(%.6g, %.6g, %.6g, 1)" % emi[:3])
            lineas.append("emission_energy_multiplier = %.2f" % emi[3])
        return m.group(1) + "\n".join(lineas) + "\n\n"

    nuevo = re.sub(r'(\[sub_resource type="StandardMaterial3D" id="[^"]+"\]\n)(.*?)\n\n', bloque, texto, flags=re.S)
    lineas = nuevo.split("\n", 1)
    nuevo = lineas[0] + "\n" + MARCA + "\n" + lineas[1]
    open(ruta, "w", encoding="utf8", newline="\n").write(nuevo)
    print(ruta, cuenta)
    return cuenta


if __name__ == "__main__":
    for e in ESCENAS:
        procesar(os.path.normpath(os.path.join(RAIZ, e)))
