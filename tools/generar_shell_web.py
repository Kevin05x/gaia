"""Genera deploy/web/gaia_shell.html: la página que envuelve el juego en la web (pantalla de carga con el rover de la NASA,
logo de GAIA en la pestaña y en la carga). La usa el preset «Web» de export_presets.cfg (html/custom_html_shell).

Uso:  py tools/generar_shell_web.py
Entradas: assets/_blender/rover_carga.png (lo hace tools/renderizar_rover.gd) y assets/menu/gaia_logo.png.
Todo va dentro del propio HTML (imágenes en base64): la carga no depende de ningún otro archivo.
"""
import base64
import io
import json
import os

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, "deploy", "web", "gaia_shell.html")


def b64(imagen, formato="PNG", **opciones):
    memoria = io.BytesIO()
    imagen.save(memoria, formato, **opciones)
    return base64.b64encode(memoria.getvalue()).decode("ascii")


def rover():
    """Cuerpo del rover de perfil (mira a la izquierda) y sus tres ruedas del lado visible, para que giren con CSS."""
    carpeta = os.path.join(RAIZ, "assets", "_blender")
    cuerpo = Image.open(os.path.join(carpeta, "rover_cuerpo.png")).convert("RGBA")
    datos = json.load(open(os.path.join(carpeta, "rover_ruedas.json"), encoding="utf-8"))
    lado = datos["lado_rueda"]
    caja = list(cuerpo.getbbox())
    for x, y in datos["ruedas"]:  # que el recorte incluya las ruedas enteras
        caja = [min(caja[0], x - lado / 2), min(caja[1], y - lado / 2), max(caja[2], x + lado / 2), max(caja[3], y + lado / 2)]
    caja = [int(caja[0]), int(caja[1]), int(caja[2]) + 1, int(caja[3]) + 1]
    cuerpo = cuerpo.crop(caja)
    ancho = 360
    escala = ancho / cuerpo.width
    cuerpo = cuerpo.resize((ancho, round(cuerpo.height * escala)), Image.LANCZOS)
    rueda = Image.open(os.path.join(carpeta, "rover_rueda.png")).convert("RGBA")
    lado_px = round(lado * escala)
    rueda = rueda.resize((lado_px, lado_px), Image.LANCZOS)
    ruedas = []
    for x, y in datos["ruedas"]:
        ruedas.append(((x - caja[0]) * escala / ancho * 100, (y - caja[1]) * escala / cuerpo.height * 100))
    return {"cuerpo": b64(cuerpo, "PNG", optimize=True), "rueda": b64(rueda, "PNG", optimize=True), "ruedas": ruedas,
            "ancho_rueda": lado_px / ancho * 100, "relacion": cuerpo.height / ancho}


def logo():
    imagen = Image.open(os.path.join(RAIZ, "assets", "menu", "gaia_logo.png")).convert("RGBA")
    imagen = imagen.crop(imagen.getbbox())
    ancho = 520
    imagen = imagen.resize((ancho, round(imagen.height * ancho / imagen.width)), Image.LANCZOS)
    return b64(imagen, "PNG", optimize=True)


def icono(lado):
    imagen = Image.open(os.path.join(RAIZ, "assets", "menu", "gaia_logo.png")).convert("RGBA")
    planeta = imagen.crop((10, 30, 490, 510))  # el planeta de la izquierda del logo
    return b64(planeta.resize((lado, lado), Image.LANCZOS), "PNG", optimize=True)


PLANTILLA = r"""<!DOCTYPE html>
<html lang="es">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0">
		<title>$GODOT_PROJECT_NAME</title>
		<link id="gaia-icono" rel="icon" type="image/png" href="data:image/png;base64,@@ICONO64@@">
		<link rel="apple-touch-icon" href="data:image/png;base64,@@ICONO180@@">
		<style>
html, body, #canvas { margin: 0; padding: 0; border: 0; }
body { color: #FFF5E4; background-color: #120A08; overflow: hidden; touch-action: none; }
#canvas { display: block; }
#canvas:focus { outline: none; }
#cargando {
	position: absolute; left: 0; right: 0; top: 0; bottom: 0; z-index: 5;
	background: radial-gradient(ellipse at 50% 30%, #2a1a12 0%, #120A08 70%);
	display: flex; flex-direction: column; justify-content: center; align-items: center; gap: 0;
	font-family: 'Noto Sans', 'Droid Sans', Arial, sans-serif;
	transition: opacity 0.6s ease;
}
#cargando.fuera { opacity: 0; pointer-events: none; }
#logo { width: min(70vw, 460px); height: auto; margin-bottom: 8vh; }
#pista { position: relative; width: min(82vw, 640px); height: 8px; background: #2d1d14; border-radius: 6px; margin-top: 64px; box-shadow: 0 0 0 1px rgba(240,192,121,.25); display: flex; justify-content: flex-end; }
#barra { height: 100%; width: 0%; border-radius: 6px; background: linear-gradient(270deg, #B8742E, #F0C079); transition: width .25s linear; }
/* El rover avanza de derecha a izquierda: la barra se llena desde la derecha y el rover mira a la izquierda. */
#rover {
	position: absolute; right: 0%; bottom: 100%; margin-bottom: -7px; width: 110px; height: @@ALTO@@px;
	transform: translateX(50%); transition: right .25s linear;
	animation: rebote .45s ease-in-out infinite alternate;
	filter: drop-shadow(0 4px 4px rgba(0,0,0,.5));
}
#rover.quieto, #rover.quieto .rueda { animation: none; }
#rover.indet { animation: rebote .45s ease-in-out infinite alternate, cruzar 3.2s linear infinite; transition: none; }
@keyframes cruzar { from { transform: translateX(50%); } to { transform: translateX(calc(50% - min(82vw, 640px))); } }
#rover .cuerpo { position: absolute; left: 0; top: 0; width: 100%; height: 100%; }
#rover .rueda { position: absolute; background: url(data:image/png;base64,@@RUEDA64@@) center / 100% 100% no-repeat; aspect-ratio: 1; width: @@ANCHORUEDA@@%; transform: translate(-50%, -50%); animation: girar .5s linear infinite; }
/* «translate» y «transform» se animan en el hilo del compositor: el rover sigue rodando aunque el juego bloquee la página un rato. */
@keyframes rebote { from { translate: 0 0; } to { translate: 0 -2px; } }
@keyframes girar { to { transform: translate(-50%, -50%) rotate(-360deg); } }
#texto { margin-top: 26px; font-size: 15px; letter-spacing: .16em; text-transform: uppercase; color: #F0C079; font-family: 'Oxanium', 'Noto Sans', Arial, sans-serif; }
#aviso { margin-top: 10px; font-size: 13px; color: rgba(255,245,228,.62); text-align: center; max-width: min(82vw, 560px); line-height: 1.4; }
#notice {
	display: none; background-color: #5b3943; border-radius: .5rem; border: 1px solid #9b3943; color: #e0e0e0;
	line-height: 1.3; margin: 1.5rem 2rem 0; overflow: hidden; padding: 1rem; text-align: center; max-width: 80vw;
}
		</style>
		$GODOT_HEAD_INCLUDE
	</head>
	<body>
		<canvas id="canvas">Your browser does not support the canvas tag.</canvas>
		<noscript>Your browser does not support JavaScript.</noscript>

		<div id="cargando">
			<img id="logo" alt="GAIA" src="data:image/png;base64,@@LOGO64@@">
			<div id="pista">
				<div id="barra"></div>
				<div id="rover">
					<img class="cuerpo" alt="" src="data:image/png;base64,@@CUERPO64@@">
					@@RUEDAS@@
				</div>
			</div>
			<div id="texto">...</div>
			<div id="aviso"></div>
			<div id="notice"></div>
		</div>

		<script src="$GODOT_URL"></script>
		<script>
const GODOT_CONFIG = $GODOT_CONFIG;
const GODOT_THREADS_ENABLED = $GODOT_THREADS_ENABLED;
const engine = new Engine(GODOT_CONFIG);

(function () {
	const ES = (navigator.language || 'es').toLowerCase().indexOf('es') === 0;
	const cargando = document.getElementById('cargando');
	const barra = document.getElementById('barra');
	const rover = document.getElementById('rover');
	const texto = document.getElementById('texto');
	const aviso = document.getElementById('aviso');
	const notice = document.getElementById('notice');
	let oculto = false;

	// El icono de la pestaña es el de GAIA: el motor intenta poner el suyo al arrancar, así que se vuelve a poner.
	const icono = document.getElementById('gaia-icono').href;
	function ponerIcono() {
		document.querySelectorAll('link[rel~="icon"]').forEach(function (l) {
			if (l.id !== 'gaia-icono' && l.href !== icono) { l.href = icono; }
		});
	}
	new MutationObserver(ponerIcono).observe(document.head, { childList: true, subtree: true, attributes: true });

	function mostrarTexto(pct, mb) {
		if (pct === null) { texto.textContent = ES ? 'Cargando...' : 'Loading...'; return; }
		texto.textContent = (ES ? 'Cargando ' : 'Loading ') + pct + ' %';
		if (mb) {
			aviso.textContent = ES
				? 'La primera vez baja unos ' + mb + ' MB. Después queda guardado en tu navegador y abre mucho más rápido.'
				: 'The first visit downloads about ' + mb + ' MB. It is then kept in your browser and opens much faster.';
		}
	}

	let reserva = null;
	let minimo = null;
	function ocultar() {
		if (oculto) { return; }
		oculto = true;
		clearTimeout(reserva);
		clearTimeout(minimo);
		cargando.classList.add('fuera');
		setTimeout(function () {
			if (oculto) { cargando.style.display = 'none'; rover.classList.remove('indet'); }
		}, 700);
	}
	// El juego avisa cuando ya pinta su primera pantalla (scenes/menu/intro.gd); si no avisara, se quita igualmente.
	window.gaiaListo = ocultar;
	// Y vuelve a pedirlo cuando va a compilar gráficos nuevos (la página se queda quieta un rato): scenes/b/web_carga.gd.
	// El rover sigue rodando porque su animación corre en el hilo del compositor, no en el de la página.
	window.gaiaCargando = function (es, en, ms) {
		oculto = false;
		clearTimeout(reserva);
		clearTimeout(minimo);
		cargando.style.display = 'flex';
		void cargando.offsetWidth;
		cargando.classList.remove('fuera');
		rover.classList.add('indet');
		rover.style.right = '0%';
		barra.style.width = '0%';
		texto.textContent = ES ? 'Un momento...' : 'One moment...';
		aviso.textContent = ES ? es : en;
		if (ms) { minimo = setTimeout(ocultar, ms); }
	};

	function fallo(err) {
		console.error(err);
		let msg = 'An unknown error occurred.';
		if (err instanceof Error) { msg = err.message; } else if (typeof err === 'string') { msg = err; }
		notice.textContent = msg;
		notice.style.display = 'block';
		texto.textContent = 'Error';
		rover.className = 'quieto';
	}

	const faltan = Engine.getMissingFeatures({ threads: GODOT_THREADS_ENABLED });
	if (faltan.length !== 0) {
		fallo('Error\nThe following features required to run Godot projects on the Web are missing:\n' + faltan.join('\n'));
		return;
	}
	mostrarTexto(null, 0);
	engine.startGame({
		'onProgress': function (actual, total) {
			if (actual > 0 && total > 0) {
				const pct = Math.min(100, Math.floor(actual * 100 / total));
				barra.style.width = pct + '%';
				rover.style.right = pct + '%';
				mostrarTexto(pct, Math.round(total / 1048576));
			}
		},
	}).then(function () {
		barra.style.width = '100%';
		rover.style.right = '100%';
		texto.textContent = ES ? 'Iniciando...' : 'Starting...';
		reserva = setTimeout(ocultar, 25000);
	}, fallo);
}());
		</script>
	</body>
</html>
"""


def main():
    r = rover()
    ruedas = "\n\t\t\t\t\t".join('<div class="rueda" style="left:%.2f%%;top:%.2f%%"></div>' % (x, y) for x, y in r["ruedas"])
    html = (PLANTILLA.replace("@@ICONO64@@", icono(64)).replace("@@ICONO180@@", icono(180)).replace("@@LOGO64@@", logo())
            .replace("@@CUERPO64@@", r["cuerpo"]).replace("@@RUEDA64@@", r["rueda"]).replace("@@RUEDAS@@", ruedas)
            .replace("@@ANCHORUEDA@@", "%.2f" % r["ancho_rueda"]).replace("@@ALTO@@", "%.1f" % (110 * r["relacion"])))
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    with open(SALIDA, "w", encoding="utf-8", newline="\n") as f:
        f.write(html)
    print("deploy/web/gaia_shell.html (%d KB)" % (len(html) // 1024))


if __name__ == "__main__":
    main()
