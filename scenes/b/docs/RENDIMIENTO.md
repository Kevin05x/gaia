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

# Ronda F: la web ya no se congela (31 oct 2026)

Kevin reportó tres cosas en el navegador: el juego se congelaba al entrar o al crear partida («Esperar / Salir»), iba a 20–30 cuadros por segundo y el fondo del menú temblaba. Su equipo: gráficos Intel UHD con Chrome sobre ANGLE/Direct3D 11.

## Fuentes consultadas

- Godot, issue #72584: en la web los congelamientos al cargar vienen sobre todo de **compilar sombreadores**. ANGLE en Chrome es lento porque valida cada sombreador.
- Foro de Godot (lag por compilación de partículas en Compatibility): mostrar los efectos un cuadro detrás de una pantalla opaca al cargar. Los ubershaders se desactivaron en la web.
- Godot, *Optimizing 3D performance*: el agrupado automático de mallas solo existe en Forward+. En Compatibility (WebGL) cada malla visible es una llamada de dibujo, así que conviene reutilizar mallas y materiales y usar MultiMesh.
- Guías de exportación web de Godot 4: la versión sin hilos corre todo en el hilo principal. Hay que tener poco trabajo en `_process` y no hacer trabajos largos de golpe.

## Medición

Exportación web real, Chromium sin pantalla y GPU por software, así que sirve para comparar, no como cifra absoluta. Escena de medición en `_medir.gd`, fuera del repo.

| | antes | después |
|---|---|---|
| Cuadro más largo durante la carga | 8,7 s | 3,5 s |
| `_ready` del juego (escritorio) | 2,26 s | 0,29 s |
| Llamadas de dibujo en partida | 325 | 267–273 |
| Cuadro medio al construir (GPU por software) | 529 ms | 342 ms |

Sin dibujar, el trabajo de CPU por cuadro ya iba a 16,7 ms (el tope de 60 cuadros por segundo). El cuello de botella era la GPU y las compilaciones, no la lógica.

## Cambios

- **Carga por pasos** (`scenes/menu/loading.gd`): un recurso por cuadro, luego se monta el juego y la pantalla espera a que la vista avise `listo`.
- **Terreno por pasos** (`terrain.gd`, `por_pasos`): suelo, colinas, cuenca y decorado se construyen en cuadros distintos y al final se emite `mundo_listo`.
- **Precalentado gradual** (`shader_warmup.gd`): 4 muestras por cuadro, primero con sombras y luego sin ellas. Se descartan las muestras repetidas, que tienen los mismos materiales.
- **Vista previa del editor sin cargar**: `mission.tscn` instanciaba y borraba la escena de vista previa de B en cada partida. Ahora es un *placeholder*.
- **Menos llamadas de dibujo**: los modelos del equipo se funden en una malla con una superficie por material (un cristal pasa de 16 a 2 o 3). Los trozos del decorado menudo pasan de 48 m a 96 m.
- **Resolución 3D automática** (`calidad_dinamica.gd`): si durante 2,5 s el juego va a menos de unos 42 cuadros por segundo, el mundo 3D se dibuja al 85 %, luego al 72 % y como mínimo al 60 %. La interfaz sigue nítida. Si el equipo va sobrado, vuelve a subir.
- **Exportación**: fuera de la web van GUT, las pruebas, las herramientas y los documentos.
- **Menú**: sin acercamiento lento del fondo (con pocos cuadros por segundo se veía temblar) y sin logotipo flotante. El logotipo entra con un fundido y un destello, y cada 9 s un brillo sutil lo cruza.

# Ronda G (1 nov 2026)

La medición y los cambios están en `RONDA_G.md`: paisaje lejano indexado, calidad automática que empieza con MSAA 2x, barrera en MultiMesh y la interfaz sin rehacerse en cada snapshot.
