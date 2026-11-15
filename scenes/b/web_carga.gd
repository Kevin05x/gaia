class_name WebCarga
extends RefCounted
## Puente con la pantalla de carga de la web (deploy/web/gaia_shell.html, que genera tools/generar_shell_web.py).
## En el navegador la primera vez que se dibuja algo nuevo hay que compilar sus sombreadores y la página se queda quieta de 5
## a 50 segundos según el equipo (Chrome guarda el resultado: la segunda vez es rápido). Un aviso HTML con el rover rodando
## se queda por encima del juego mientras tanto: sus animaciones corren en otro hilo del navegador y no se congelan.
## Fuera de la web no hace nada.


## Muestra el aviso (con texto en español e inglés). «minimo_ms»: se quita solo pasado ese rato; como los temporizadores del
## navegador no corren mientras la página está bloqueada, se quita en cuanto el juego vuelve a responder.
static func mostrar(es: String, en: String, minimo_ms: int = 1500) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (window.gaiaCargando) { window.gaiaCargando(%s, %s, %d); }" % [JSON.stringify(es), JSON.stringify(en), minimo_ms])


## Quita el aviso ya.
static func ocultar() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.gaiaListo) { window.gaiaListo(); }")
