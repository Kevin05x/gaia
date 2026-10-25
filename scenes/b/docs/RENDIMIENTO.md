# Rendimiento y fluidez (ronda E, 25 oct 2026)

Objetivo: que el juego no se trabe al construir, al extraer ni en el combate, sin bajar la calidad visual.

## Causas encontradas

- **Sombreadores que se compilan al primer uso.** En la web (WebGL) cada material nuevo se compila la primera vez que se dibuja y congela la imagen un momento. Le pasaba a la primera obra (material de revelado, andamio, cartel), al taladro (partículas, rayo, columna de trabajo), a la primera explosión, a la primera oleada y al contorno de selección.
- **Modelos `.glb` leídos en cada obra.** `modelos_equipo.gd` cargaba e instanciaba el archivo al empezar cada obra y otra vez al terminarla. Godot lo descargaba entre medias, así que se volvía a leer del disco.
- **Menú de construcción rehecho entero** cada vez que cambiaban los recursos, es decir, en cada extracción.
- **Snapshot copiado dos veces.** Se copiaba en profundidad en el Port y otra vez en la vista. Además, en combate se publicaba en cada cuadro.

## Cambios

- `shader_warmup.gd`: al empezar la misión, una cortina oscura de unas décimas de segundo tapa la pantalla. Detrás se dibuja una muestra diminuta de todo lo que aún no está a la vista, con y sin sombras del sol: cada edificio terminado y en obra, los monstruos, los efectos guardados en reserva y las partículas del taladro. Después se borra.
- `modelos_equipo.gd`: cada `.glb` se lee una sola vez por misión (`precargar`, caché de mallas) y se suelta al salir (`vaciar`).
- `base_hud.gd`: el menú solo se rehace si cambia su forma (qué edificios hay o el idioma). Si no, solo se actualizan los textos de cada fila.
- `mission_view.gd`: sin la segunda copia profunda del snapshot.
- `mission_runner.gd`: en combate, 30 snapshots por segundo en vez de uno por cuadro. La vista ya suaviza el movimiento de los monstruos.
- `sky_light.gd`: cada propiedad del cielo y la niebla solo se escribe si cambió. La niebla empieza lejos, así que todo el mapa jugable se ve nítido.

La calidad no cambia: mismas sombras, mismos modelos, misma resolución y mismos efectos.

## Medir

`F3` muestra el panel de rendimiento en el juego. En escritorio: `godot --headless -s` con los pasos `tparts`, `spike=N` y `tcmd=…` del script de capturas de desarrollo.
