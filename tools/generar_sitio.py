"""Genera las páginas de sitio/ (la web de GAIA) a partir de tools/sitio_fuentes/*.html.

Uso:  py tools/generar_sitio.py
Cada página tiene su cuerpo en tools/sitio_fuentes/<id>.html; aquí se le pone la cabecera, el menú y el pie comunes.
Los textos están en español e inglés con <span class="es"> y <span class="en">; el idioma lo elige el visitante con ES / EN.
"""
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTES = os.path.join(RAIZ, "tools", "sitio_fuentes")
SALIDA = os.path.join(RAIZ, "sitio")
JUEGO = "https://gaianasa.tech"

# id, menú es, menú en, título es, título en, descripción es, descripción en, imagen de cabecera, etiqueta es, etiqueta en, título grande es, título grande en
PAGINAS = [
    ("index", "Inicio", "Home", "GAIA | Diseña la misión, sobrevive en otro mundo", "GAIA | Design the mission, survive on another world",
     "GAIA es un juego 3D y web de diseño y operación de misiones espaciales para 1 a 4 jugadores. Equipo Full Galácticos, Cajamarca.",
     "GAIA is a 3D and web game about designing and operating space missions for 1 to 4 players. Team Full Galácticos, Cajamarca.",
     "hero", "", "", "", ""),
    ("reto", "El reto", "The challenge", "El reto | GAIA", "The challenge | GAIA",
     "Qué problema quisimos resolver con GAIA para el NASA Space Apps Challenge 2026.",
     "The problem we wanted to solve with GAIA for the NASA Space Apps Challenge 2026.",
     "nasa_aterrizaje", "El reto", "The challenge", "Un simulador para entender cómo se diseña una misión", "A simulator to understand how a mission is designed"),
    ("nacio", "Cómo nació", "How it began", "Cómo nació | GAIA", "How it began | GAIA",
     "La pregunta de la que salió GAIA y cómo fue creciendo.", "The question GAIA came from and how it grew.",
     "hist_intro3", "Cómo nació", "How it began", "De una pregunta a un juego completo", "From one question to a full game"),
    ("juego", "Cómo se juega", "How to play", "Cómo se juega | GAIA", "How to play | GAIA",
     "Del taller al lanzamiento y las operaciones, solo o hasta con cuatro jugadores.",
     "From the workshop to launch and operations, alone or with up to four players.",
     "juego_marte", "Cómo se juega", "How to play", "Briefing, taller, lanzamiento y operaciones", "Briefing, workshop, launch and operations"),
    ("mundo", "El mundo", "The world", "El mundo | GAIA", "The world | GAIA",
     "La historia de GAIA, Marte, la Luna y los datos reales de la NASA.", "The story of GAIA, Mars, the Moon and the real NASA data.",
     "hist_noche", "El mundo", "The world", "Una historia que cambia con lo que decides", "A story that changes with what you decide"),
    ("equipo", "El equipo", "The team", "El equipo | GAIA", "The team | GAIA",
     "Quiénes hicimos GAIA, cómo está hecho y qué parte se hizo con IA.", "Who made GAIA, how it is built and what was done with AI.",
     "juego_equipo", "El equipo", "The team", "Full Galácticos, Cajamarca", "Full Galácticos, Cajamarca"),
]


def bi(es, en):
    return '<span class="es">%s</span><span class="en">%s</span>' % (es, en)


def menu(actual):
    items = []
    for p in PAGINAS[1:]:
        clase = ' class="activa"' if p[0] == actual else ""
        items.append('<li><a%s href="%s.html">%s</a></li>' % (clase, p[0], bi(p[1], p[2])))
    return "\n      ".join(items)


NAV = """<nav id="nav">
  <div class="ancho">
    <a class="marca" href="index.html" aria-label="GAIA"><img src="img/gaia_logo.png" alt="GAIA"></a>
    <ul>
      %(menu)s
    </ul>
    <div style="display:flex;align-items:center;gap:14px">
      <div class="idioma"><button data-l="es" type="button">ES</button><button data-l="en" type="button">EN</button></div>
      <a class="boton principal" href="%(juego)s" style="padding:10px 20px;font-size:.8rem">%(jugar)s</a>
    </div>
  </div>
</nav>"""

PIE = """<footer>
  <div class="ancho">
    <div class="cols3">
      <div><h4>GAIA</h4>
        <p>%(p1)s</p></div>
      <div><h4>%(creditos)s</h4><ul>
        <li>%(c1)s</li>
        <li>%(c2)s</li>
        <li>%(c3)s</li>
        <li>%(c4)s</li></ul></div>
      <div><h4>%(honestidad)s</h4><p>%(h1)s</p><p class="pequeno">© Full Galácticos, Cajamarca, Perú</p>
        <p class="pequeno"><a href="https://github.com/Kevin05x/gaia">GitHub</a> · <a href="https://www.spaceappschallenge.org/2026/find-a-team/full-galacticos/">Space Apps</a></p></div>
    </div>
  </div>
</footer>"""


def pie():
    return PIE % {
        "p1": bi("Un juego de Full Galácticos para el NASA Space Apps Challenge 2026, reto Space Mission Design Game. GAIA no está afiliado a la NASA ni a ninguna agencia espacial. El nombre es provisional.",
                 "A game by Full Galácticos for the NASA Space Apps Challenge 2026, Space Mission Design Game challenge. GAIA is not affiliated with NASA or any space agency. The name is provisional."),
        "creditos": bi("Créditos", "Credits"),
        "c1": bi("Datos e imágenes de la NASA, cada uno con su crédito: NASA/JPL, NASA Science, NASA Image and Video Library y NASA 3D Resources.",
                 "NASA data and images, each with its credit: NASA/JPL, NASA Science, NASA Image and Video Library and NASA 3D Resources."),
        "c2": bi('Cohete Saturno V: «Cohete» de albertomarun en Sketchfab, licencia <a href="https://creativecommons.org/licenses/by/4.0/">CC BY 4.0</a>.',
                 'Saturn V rocket: "Cohete" by albertomarun on Sketchfab, <a href="https://creativecommons.org/licenses/by/4.0/">CC BY 4.0</a> license.'),
        "c3": "Kenney, Space Kit, y Kay Lousberg, Space Base Bits, ambos CC0.",
        "c4": bi("Tipografías Oxanium e Inter, licencia OFL.", "Typefaces Oxanium and Inter, OFL license."),
        "honestidad": bi("Honestidad", "Honesty"),
        "h1": bi("Las imágenes de la historia están hechas con IA y llevan la marca «Imagen generada con IA». Parte del código se hizo con ayuda de IA, Claude de Anthropic, bajo la dirección del equipo.",
                 "The story images are made with AI and carry the mark \"AI-generated\". Part of the code was written with AI help, Claude by Anthropic, under the team's direction."),
    }


def pagina(p):
    id_, m_es, m_en, t_es, t_en, d_es, d_en, img, et_es, et_en, h_es, h_en = p
    cuerpo = open(os.path.join(FUENTES, id_ + ".html"), encoding="utf-8").read()
    nav = NAV % {"menu": menu(id_), "juego": JUEGO, "jugar": bi("Jugar", "Play")}
    if id_ == "index":
        cabecera = ""  # la portada va dentro del cuerpo
    else:
        cabecera = """<header class="cabecera">
  <div class="fondo" style="background-image:url(img/%s.jpg)" aria-hidden="true"></div>
  <div class="barra arriba"></div>
  <div class="ancho contenido">
    <div class="etiqueta">%s</div>
    <h1>%s</h1>
  </div>
</header>""" % (img, bi(et_es, et_en), bi(h_es, h_en))
    html = """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(t_es)s</title>
<meta name="description" content="%(d_es)s">
<meta property="og:title" content="%(t_es)s">
<meta property="og:description" content="%(d_es)s">
<meta property="og:image" content="img/hero.jpg">
<link rel="stylesheet" href="estilo.css">
</head>
<body>
<div class="grano" aria-hidden="true"></div>
<div class="vineta" aria-hidden="true"></div>

%(nav)s

%(cabecera)s
<main>
%(cuerpo)s
</main>

%(pie)s
<script src="app.js"></script>
</body>
</html>
""" % {"t_es": t_es, "d_es": d_es, "nav": nav, "cabecera": cabecera, "cuerpo": cuerpo, "pie": pie()}
    # el título y la descripción en inglés los cambia app.js según el idioma
    html = html.replace("<title>%s</title>" % t_es, '<title data-es="%s" data-en="%s">%s</title>' % (t_es, t_en, t_es), 1)
    open(os.path.join(SALIDA, id_ + ".html"), "w", encoding="utf-8", newline="\n").write(html)
    print("sitio/%s.html" % id_)


if __name__ == "__main__":
    for p in PAGINAS:
        pagina(p)
