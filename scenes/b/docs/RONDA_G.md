# Ronda G (1 nov 2026): paisaje lejano, ciencia por etapas, bodega, barrera y animaciones

## Fuentes consultadas

- Godot, *3D antialiasing*: en Compatibility (web) el suavizado disponible es MSAA; escalar la resolución 3D con filtro bilineal emborrona. Por eso ya no se baja la resolución al empezar.
- Godot, *Optimization using MultiMeshes*: miles de copias de una malla en una sola llamada de dibujo. La barrera usa MultiMesh.
- Objetivos científicos de Mars 2020 (geología, astrobiología, muestras para la Tierra y preparar la llegada humana): son los cuatro grupos de hitos de `content/hitos.json`.
- NASA e ICON, *Project Olympus*: construcción en la Luna imprimiendo regolito por capas. Es la base visual de los muros.

## Qué cambió

1. **Paisaje lejano nítido** (`horizonte.gd`): las lomas tienen más anillos y crestas finas, estratos de color y, detrás, mesetas escalonadas aclaradas hacia el cielo. Ya no hace falta niebla espesa. Ahora es una malla indexada (cada vértice se calcula una vez), así que construirla cuesta 15 ms en vez de unas 6 veces más. El plano cercano de la cámara está a 0,35 m y hay más precisión de profundidad lejos.
2. **Calidad automática** (`calidad_dinamica.gd`): se empieza con MSAA 2x a resolución completa. Si el juego va lento, primero se quita el MSAA y luego se baja la resolución, como mucho hasta el 80 %. Antes se empezaba al 85 % y se veía pixelado.
3. **Ciencia por etapas** (`hitos.json`, `HitosSystem`, `HudCiencia`): 13 hitos dan tramos de datos (88 en total). Por ejemplo, la Antena Nv. 1 da 6 y la Nv. 2 da 8. Los análisis sueltos dan poco, así que el 100 % llega cerca del final.
4. **Objetivos agotados**: se hunden con polvo, desaparecen del mapa y del minimapa y liberan la casilla para construir.
5. **Bodega del rover** (90): lo que se recoge va a la bodega. Hay que descargarlo en la estación o junto a un domo/almacén con el botón «Descargar» o «Ir a descargar». Al volver a la base se descarga solo.
6. **Barrera** (`barrera`, `compuerta`, `MurosView`):
   - Los muros son de regolito impreso por capas, con tapa de compuesto y una línea de energía. La compuerta tiene una cortina de energía y el rover pasa por ella; los monstruos no.
   - Se pueden poner hasta 2 casillas más afuera que los edificios. Se trazan arrastrando, se imprimen en paralelo y no ocupan la obra.
   - Los monstruos rodean la barrera si tiene un hueco (Dijkstra con coste de muro 12). Si está cerrada, golpean el muro que les cierra el paso. Los muros no atraen ataques por sí solos.
   - Escudo: tras 5 s sin golpes recupera 3 PV/s. Cada golpe produce un destello hexagonal.
7. **Animaciones**:
   - El rover arranca y frena suave, se inclina con la pendiente, se balancea al girar y tiene suspensión.
   - Aparecen textos «+3 Olivino» al recoger y al descargar.
   - La cámara tiembla con las explosiones, según la distancia.
   - El edificio rebota al terminar su obra.
   - El menú de construcción y la ficha entran suavemente.

## Arquitectura

- Lo nuevo va en clases propias, no dentro de las grandes: `HitosSystem`, `HudCiencia`, `MurosView`, `TextosFlotantes` y `Horizonte`.
- Los avisos salieron de `hud.gd` a `hud_avisos.gd`, que pasa de 1422 a unas 1330 líneas. El paisaje lejano salió de `terrain.gd`, que pasa de 1332 a unas 1215.
- Se corrigieron dos reconstrucciones de interfaz en cada snapshot: la lista de avisos y la ficha abierta. Ahora solo se rehacen si cambian.
- Pendiente (sugerido, no hecho para no romper el trabajo de otros): renombrar `scenes/a` y `scenes/b` por función (`scenes/juego`, `scenes/vista`) en un PR aparte, y seguir partiendo `hud.gd` (panel del objetivo y menú de pausa).

## Medición web (mismo día y misma máquina, Chromium + SwiftShader, 640×360)

| | F | G (MSAA 2x) | G sin MSAA |
|---|---|---|---|
| Hasta «juego listo» | 80,1 s | 79,1 s | 86,7 s |
| Peor cuadro de la carga | 5,18 s | 4,16 s | 4,81 s |
| Cuadro medio en operaciones | 796 ms | 920 ms | 802 ms |
| Cuadro medio en obra | 427 ms | 474 ms | 443 ms |
| CPU por cuadro (sin dibujar) | 16,6 ms | 16,5 ms | — |
| Llamadas de dibujo | 277 | 293 | 301 |

La GPU por software exagera el coste del MSAA (~15 %). En una GPU real cuesta mucho menos y, si el juego baja de unos 42 cuadros/s, la calidad automática lo quita a los 2,5 s. Con todo lo nuevo (muros, horizonte, bodega, ciencia), el juego cuesta lo mismo que en la ronda F.

## Gráficos H1: sombras de contacto (1 nov 2026)

El renderer de la web (Compatibility) no tiene SSAO, así que la oclusión ambiental se hornea o se pinta de forma barata:

- **Rocas** (`world_art.gd › _con_oclusion`): la parte baja de cada malla de roca se oscurece en el color de vértice. Se calcula una vez al crear la malla.
- **Suelo** (`terrain.gd › _oclusion_suelo`): los fondos más bajos que su entorno se oscurecen y las crestas se aclaran un poco. Se calcula al construir el terreno.
- **Estación, edificios, muros, Rocky y el dron** (`sombras_contacto.gd`): una mancha suave inclinada con el suelo. Son dos MultiMesh (dos llamadas de dibujo). La capa de edificios solo se rehace cuando cambia la base. La mancha del dron se aclara y se agranda cuanto más alto vuela.
- La textura de contacto ahora es una campana suave: núcleo más denso y borde que se desvanece.

## Interfaz (1 nov 2026)

- El panel del relé ya no tapa «Construir antena». La fila de acciones se coloca usando el ancho del panel desplegado, y si aun así no cabe, el relé sube por encima de la fila.
- Al pasar el mouse por un botón se explica qué hace (`ACT_INFO_*`). Debajo aparece el atajo, o el motivo y el costo si no se puede usar ahora. Aplica a las acciones globales, a las del objetivo, a Transmitir, a Construir y al relé.

## Gráficos H2–H6 y opciones gráficas (1–2 nov 2026)

Referencias: Astroneer (formas grandes, color y silueta antes que detalle), No Man's Sky (atmósfera y niebla de color como dirección de arte) y las fotos de los rovers de la NASA (cielo ocre de día y halo azul alrededor del Sol al atardecer).

- **Opciones › Gráficos** (`graficos.gd` + `opciones_graficos.gd`, en el menú principal y en el de pausa):
  - Ajustes Baja, Media, Alta (por defecto) y Ultra, más Personalizada.
  - Opciones: sombras (apagadas, normales o altas con 2 cascadas y atlas de 4096), suavizado (no, MSAA 2x o 4x), distancia de dibujo, resolución 3D (70–100 %), postproceso, texturas detalladas, polvo en el aire y ajuste automático (solo baja desde lo elegido).
  - Se guarda en `user://b_preferences.cfg`, sección `graficos`. Reemplaza al interruptor «Calidad».
- **Cielo propio** (`cielo_marte.gd`, shader de cielo):
  - Degradado ocre con bruma luminosa en el horizonte.
  - Halo del Sol estrecho y ancho, y halo azul al amanecer y al atardecer.
  - Disco solar y estrellas de noche. Con tormenta, el cielo es más plano y el halo más ancho.
- **Luz**: el sol es más fuerte (0,86) y la luz ambiente más baja y de tono malva frío. Así las caras al sol son cálidas y las de sombra frías, y eso da volumen. Los atardeceres son azul violeta.
- **Postproceso** (Media, Alta y Ultra):
  - Tonemap Filmic, que evita que los blancos se quemen.
  - Brillo suave (glow con umbral 1,15) para energía, focos y cortinas.
  - Contraste 1,08 y saturación 1,12.
  - Dispersión del sol en la niebla.
- **Materiales**: las rocas tienen un borde iluminado suave (rim) cuando las texturas detalladas están activas.
- **Polvo en el aire** (`polvo_ambiente.gd`): 140 motas flotando delante de la cámara, en una sola llamada de dibujo. Con tormenta van más rápido.
- **Interfaz**:
  - El panel del relé ya no se corre a la izquierda al plegarse. Esa era la causa real de que tapara «Construir antena».
  - Con el menú de pausa abierto, el HUD queda por encima de la base y de la radio.

### Medición web por ajuste (Chromium + SwiftShader, 640×360; solo sirve para comparar)

| | Ronda G | Alta (por defecto) | Baja |
|---|---|---|---|
| Cuadro medio en operaciones | 920 ms | 1040 ms | 642 ms |
| Cuadro medio en obra | 474 ms | 534 ms | 310 ms |
| Llamadas de dibujo | 293 | 296 | 225 |
| Primitivas | 131 000 | 131 000 | 86 000 |
| CPU por cuadro | 16,5 ms | 16,6 ms | 16,5 ms |

Alta cuesta un ~13 % más que la ronda G en una GPU por software, por el brillo, el Filmic y el cielo. En una GPU real cuesta menos. Baja va un 20–30 % más rápido que la ronda F: sin sombras, sin postproceso y con menos decorado lejano.

### Ajustes finales de la imagen (2 nov 2026)

- **Reflejos del cielo**: el mapa de reflejos del cielo se pinta al 42 % (`AT_CUBEMAP_PASS`). Con un cielo de Marte tan claro, el reflejo lavaba el suelo y lo dejaba pálido. Los metales siguen reflejando y el cielo que se ve no cambia.
- El regolito casi no tiene brillo especular (0,04) y las rocas tienen 0,12.
- **Luz ambiente**: malva cálido (AC8A80, 0,44). El suelo conserva su rojo y las sombras siguen algo más frías que el sol.
- **Postproceso**: exposición 0,94, saturación 1,2 y glow con umbral 1,6 (solo lo que de verdad brilla).
- **Sin niebla de altura**: en Compatibility se suma también cerca de la cámara y lo lavaba todo (probado y descartado).
- **Ajuste automático**: en un equipo muy justo, tras quitar el suavizado y bajar la resolución, también quita el brillo y luego las sombras. Solo vale para esa partida y no cambia lo guardado.

## Ajustes tras la prueba en el PC de Kevin (Intel UHD, Chrome)

Reporte: Ultra a 7–25 FPS, unos 4 GB más de RAM en Chrome con el juego abierto, el aviso de batería tapaba el contador
de FPS, textos «+6 Xenolito» encima del botón de acción, sonidos que se oían dobles y una vez una pantalla marrón que no
dejaba entrar.

- Sonidos dobles: en la web, cada `stream_paused = false` reinicia el sonido (Godot crea otra fuente en WebAudio) y
  `audio.gd` lo asignaba en cada snapshot al viento y a la herramienta. Ahora solo se cambia si de verdad cambia.
- Pantalla marrón: la carga se iba a los 40 s fijos aunque el precalentado de sombreadores siguiera; quedaba la cortina
  marrón sin barra. Ahora la carga espera mientras haya avance (se rinde a los 45 s sin avance o 4 min en total) y, si
  se rinde, termina el precalentado (`forzar_listo`) para entrar igual. Durante la carga el 3D se dibuja al 30 % y sin
  MSAA (nadie lo ve: lo tapa la pantalla de carga).
- Tope de píxeles del 3D (`Graficos.MAX_PIXELES_3D`, 1920×1080): con escala de Windows o pantallas grandes el navegador
  pedía lienzos de 2,5–4 millones de píxeles.
- En el navegador se empieza en Media (Alta en el escritorio) y Ultra también tiene ajuste automático.
- Contador de FPS: 3 líneas (FPS, mínimo, ms · ajuste, resolución 3D real, nivel automático · RAM del juego (memoria
  WebAssembly), VRAM, llamadas de dibujo, triángulos). Las franjas de avisos bajan cuando está visible.
- Textos flotantes: arrancan 70 px por encima del rover (sobre el menú de acciones) y, si salen juntos, cada uno en su
  fila.

Medición de memoria (Chromium + SwiftShader, 1920×1080, Media): WebAssembly 157 MB, pestaña completa ~1,1 GB (de ellos
~550 MB del proceso de GPU) y estable durante la partida. En el escritorio (Godot nativo): 111 MB de RAM del motor y
94 MB de VRAM. Los ~4 GB vistos en Windows no salen del juego en sí: hay que mirar el Administrador de tareas de Chrome
(Shift+Esc) para separar pestaña y «Proceso de GPU».
