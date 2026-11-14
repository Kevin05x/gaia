# Arte y licencias de la parte B

Todos los modelos, materiales, geometría del terreno, ilustración `jezero.svg` y audios WAV de esta carpeta se crearon originalmente para esta entrega con asistencia de IA. No contienen mallas, fotos, logotipos o audios descargados de terceros. Su autoría no debe atribuirse a NASA. El titular del repositorio puede incorporarlos al proyecto y decidir la licencia final de la obra; aquí no se cambia la licencia del repositorio ni se promete revisión jurídica.

## Pipeline con Blender

1. Importar `assets/models/rover.glb` (o dron/compañero/estación) con File > Import > glTF 2.0.
2. Conservar 1 unidad = 1 metro, frente -Z, pivotes de ruedas y brazo. Mantener nombres `RoverVisual`, `Wheel0` a `Wheel5`, `arm`, `solar`, `rtg`, `drill`, `radar`, `spectrometer`, `meteo`, `head`.
3. Hacer ajustes originales del grupo, aplicar escala/rotación antes de animar y exportar GLB sin Draco. Para mantener los scripts, introducir la malla en la TSCN preservando sus nodos pivote/nombres.
4. Usar colores planos; si añaden texturas, <=1024 px rover y <=512 secundarios. Comprobar LODs y triángulos en el importador de Godot.
5. Una persona (B) exporta; fuentes .blend se guardan en assets_src si se crean. Esta entrega incluye fuentes generativas y GLB; no se inventan archivos .blend no trabajados.

## Audio

`wind.wav`: ambiente filtrado; `motor.wav`: motor suave; `radio.wav`: pulso de enlace; `confirm.wav`: confirmación de operación; `drill.wav`: perforación; `landing.wav`: descenso. Ambiente/motor/radio son bucles configurados por importador. Audio se desbloquea tras interacción. Hay volumen y silencio persistentes. No se usan sonidos extraídos de películas u otros juegos.

## Fotos y modelos NASA posteriores

Si el equipo decide sustituir el rover original por el modelo NASA específico del plan, registre URL y condiciones de ese asset; no asuma licencia idéntica para todos los recursos. A entrega fotos/creditos mediante el informe; B ya admite Texture2D y metadatos. En ausencia de foto se muestra la ilustración original identificada.

## Tipografías (23 oct 2026)

| Archivo | Uso | Licencia | Origen |
| --- | --- | --- | --- |
| `assets/fonts/Inter.ttf` (variable) | Texto de la interfaz | SIL Open Font License 1.1 (`assets/fonts/OFL-Inter.txt`) | Repositorio google/fonts (ofl/inter) |
| `assets/fonts/SpaceGrotesk.ttf` (variable) | Títulos, cifras y etiquetas | SIL Open Font License 1.1 (`assets/fonts/OFL-SpaceGrotesk.txt`) | Repositorio google/fonts (ofl/spacegrotesk) |

El emblema de GAIA (`scenes/b/gaia_mark.gd`) y el mapa se dibujan por código; no usan imágenes externas.

## Imágenes de menú, logotipo y carga (23 oct 2026)

| Archivo | Uso | Origen |
| --- | --- | --- |
| `assets/menu/gaia_logo.png` | Logotipo de GAIA (intro, menú, carga y HUD), PNG con transparencia | Generada con inteligencia artificial (Canva, generador de imágenes), recortada al contenido |
| `assets/menu/menu_fondo.jpg` | Fondo del menú principal (1920×1080) | Generada con inteligencia artificial (Canva) |
| `assets/menu/pantalla_carga.jpg` | Pantalla de carga (1920×1080) | Generada con inteligencia artificial (Canva) |

Son arte original del proyecto creado con IA; no copian el logotipo, la mascota ni la imagen de otro juego, película o marca. Deben declararse como generadas con IA en cualquier entrega o presentación (los créditos del menú ya lo indican). Si falta alguno de estos archivos, el juego usa un logotipo 3D hecho por código (`scenes/menu/gaia_logo.gd`) y fondos lisos. Las imágenes viajan por Git LFS.

## Música (23 oct 2026)

| Archivo | Uso | Origen |
| --- | --- | --- |
| `assets/audio/gaia_menu.ogg` | Intro, menú y carga (83 s, en bucle) | Música original sintetizada por código |
| `assets/audio/gaia_juego.ogg` | Música dentro de la misión (74 s, en bucle; re lidio, 104 BPM) | Música original sintetizada por código |

Se generan con `tools/sintetizar_musica.py` (numpy y scipy: pads, bajo, pulso, campanas FM, arpegio pulsado, melodía y reverberación; menú en do# menor a 92 BPM, partida en re lidio a 104 BPM). No usan muestras, grabaciones ni fragmentos de terceros. El vídeo de referencia solo sirvió para fijar la atmósfera (oscura, crecimiento lento); no se copió su música. `scenes/menu/musica.gd` las reproduce con fundido cruzado y respeta el volumen y el silencio guardados.

## Efectos de sonido de las acciones (23 oct 2026)

`motor.wav` (rover rodando), `drill.wav` (taladro), `laser.wav` (espectrómetro), `radar.wav` (radar de subsuelo), `panorama.wav` (cámara), `drone_start.wav` y `drone.wav` (dron), `companion.wav`, `meteo.wav`, `radio.wav` (chorro de datos al transmitir) y `uplink.wav` (subida del enlace) son originales, sintetizados con `tools/sintetizar_sonidos.py` (numpy y scipy). No usan muestras ni grabaciones de terceros. `wind.wav`, `confirm.wav` y `landing.wav` siguen siendo los de la entrega inicial.

La pista `assets/audio/gaia_juego.ogg` se rehízo (24 oct 2026) para que suene distinta a la del menú: otra tonalidad (re lidio, luminosa), otro tempo (104 BPM) y otro instrumental (arpegio pulsado, bajo cálido, percusión suave y melodía principal que entra en la segunda mitad). Se genera con `python tools/sintetizar_musica.py juego salida.wav` y se convierte a ogg con `ffmpeg -c:a libvorbis -q:a 4`. La del menú no cambia.

## Modelos 3D del equipo de diseño (24 oct 2026)

Entregados por el equipo de diseño del proyecto (renders de Arturo Valdivieso y archivos `.glb`), guardados en `assets/modelos/`. Se cargan con `scenes/b/modelos_equipo.gd`, que los ajusta a la escala del juego y los apoya en el suelo.

| Archivo | Uso en el juego |
| --- | --- |
| `hielo_2.glb`, `hielo_3.glb` | Hielo enterrado (capa que se descubre con el radar y el taladro) |
| `cristal5_brillo.glb` | Olivino (mineral expuesto) |
| `cristal.glb`, `cristal2.glb`, `cristal3_rojo.glb`, `mineral_2.glb` | Importados, aún sin usar (hielo en superficie, percloratos y roca con vetas) |
| `hangar_cuadrado.glb`, `hangar_roundA.glb` | Escenografía de la base, detrás de la estación |
| `foco.glb` | Escenografía: torre de luz de la base |
| `anthena_juego.glb` | Escenografía: antena parabólica auxiliar de la base |
| `taladro.glb` | Escenografía: torre de perforación junto a la base |
| `torreta_simple.glb`, `torreta_doble.glb` | Importadas pero sin usar: las reglas actuales no tienen torretas ni enemigos |

No integrados todavía: `25042_Perseverance.glb` (11 MB y unos 200 000 triángulos: hay que reducirlo a 15 000–25 000 para la web), `base.glb` (módulo lunar de unos 98 000 triángulos y 135 animaciones) y `panel_solar.glb` (1 MB, 26 materiales). Las texturas `foco_spacebits_texture.png` y `taladro_spacebits_texture.png` salen incrustadas en esos `.glb`; falta que el equipo confirme su origen y licencia.

## Escenas ilustradas de la historia (24 oct 2026)

Las 16 imágenes de `assets/historia/` (introducción, ocho escenas y cuatro finales) están generadas con IA (generador de imágenes de Canva) a partir de capturas del propio juego como referencia, para que el rover, Rocky, los edificios, el terreno y las criaturas se vean como en el juego. El guion y las decisiones son del equipo (`Historia_Juego_GAIA.docx`). Son material provisional del equipo: la declaración de uso de IA debe constar en la entrega. El storyboard completo (con las criaturas y los minerales en 3D) está en Canva.

No integrados todavía: `25042_Perseverance.glb` (11 MB y unos 200 000 triángulos: hay que reducirlo a 15 000–25 000 para la web), `base.glb` (módulo lunar de unos 98 000 triángulos y 135 animaciones) y `panel_solar.glb` (1 MB, 26 materiales). Las texturas `foco_spacebits_texture.png` y `taladro_spacebits_texture.png` salen incrustadas en esos `.glb`; falta que el equipo confirme su origen y licencia.

Ronda E (25 oct 2026): las escenas se exportaron de nuevo desde Canva a 1920 × 1080, porque las anteriores eran de 1280 × 720 con mucha compresión. Se importan como WebP con pérdida leve (calidad 0,9) para que la descarga web no crezca. `nave_fuga.jpg` no está en el storyboard: se reescaló con Lanczos. Las fotos de las fichas de edificios (`assets/edificios/*.png`) se renderizan con `tools/renderizar_fichas.gd` a partir de los mismos modelos del juego.

## Imágenes y modelos de la NASA (14 nov 2026)

| Carpeta | Contenido | Origen y condiciones |
| --- | --- | --- |
| `assets/nasa/*.jpg` | Fotos oficiales de Marte (lanzamiento, Jezero, aterrizaje, selfie, muestras) y de la Luna (lanzamiento Apolo, polo sur, Tierra desde Orión, huella lunar) | NASA Image and Video Library (images.nasa.gov); id y crédito de cada una en `content/nasa/*.json` y `docs/DATOS_NASA.md`. Uso educativo, con crédito, sin logo ni sugerencia de respaldo |
| `assets/nasa/modelos/*.glb` | Perseverance, Ingenuity, módulo lunar Apolo, Saturn V | NASA 3D Resources (github.com/nasa/NASA-3D-Resources, «free and without copyright»). Se descomprimieron (Draco) y simplificaron con gltf-transform; **no son obra del equipo** y no se incluyen en la versión web |

Estas fotos y modelos **no** llevan marca de agua de IA porque no son IA; las imágenes generadas con IA (logo, fondo del menú, carga e historia) sí la llevan. El código se desarrolló con asistencia de Claude (Anthropic) bajo la dirección del equipo; los créditos del menú lo declaran.

## Escala 1:1, rover real y lanzamiento con fotos (14 nov 2026)

- El rover de la partida (escritorio) es `assets/nasa/modelos/perseverance.glb` de NASA 3D Resources, simplificado con gltf-transform y animado por código (`scenes/b/rover_nasa.gd`). El modelo reproduce el rover real, **incluidas las insignias del vehículo**; se muestra como representación fiel de un recurso oficial, con crédito en el juego y en `docs/DATOS_NASA.md`. En la versión web se usa el rover propio del equipo.
- El helicóptero es `ingenuity.glb` (mismo origen) a 1,2 m de rotor a rotor.
- La escena de lanzamiento usa como fondo las fotos oficiales `lanzamiento.jpg` (Atlas V, Frank Michaux/NASA) y `luna_lanzamiento.jpg` (Saturn V, NASA), con un movimiento de cámara y texto de interfaz superpuestos; las fotos no se alteran más que el recorte y el zoom.
- Las medidas de todos los objetos están en `docs/ESCALAS.md`.

## Plataforma de lanzamiento de la Tierra (14 nov 2026)

Pantalla de elección de cohete (`scenes/b/launch_pad.gd`), rama `b/cohetes-telescopio`.

- **Fondo ilustrado `assets/menu/plataforma_tierra.jpg`: imagen generada con IA (Canva), con el mismo criterio que el fondo del menú, el logo y las escenas de la historia.** Lleva la marca visible «Imagen generada con IA · AI-generated» en pantalla (clave `AI_MARK`), abajo a la izquierda. Se pidió deliberadamente con el centro vacío para componer encima el cohete y el rover en 3D.
- Sobre la ilustración, **todo lo que se mueve es 3D del juego**: el rover es el Perseverance real de NASA 3D Resources (`RoverNasa.crear()`, el mismo de la partida), el cohete se monta por tramos y las dos torres de servicio con brazo articulado y las chispas de soldadura están hechas por código.
- Si el archivo del fondo no está, el panorama se dibuja con un cielo por código y la pantalla sigue siendo jugable: la ilustración es opcional, no un requisito para correr el juego.

## Modelos de los cuatro cohetes — entregados (14 nov 2026)

Rama `b/cohetes-telescopio`. Los datos de los cuatro cohetes ya están en `content/parts.json`; **los modelos los entrega Evelyn** y sustituirán al cohete dibujado por código de `scenes/b/launch_cruise.gd`.

Para que los archivos entren sin tocar código, el nombre del `.glb` debe ser el id de la pieza:

| Archivo | Pieza | Lanzador real | Altura real | Capacidad (juego) |
| --- | --- | --- | --- | --- |
| `assets/modelos/cohete_ligero.glb` | `cohete_ligero` | Delta II | 39,0 m | 600 kg |
| `assets/modelos/cohete_medio.glb` | `cohete_medio` | Titan IIIE-Centaur | 48,8 m | 900 kg |
| `assets/modelos/cohete_pesado.glb` | `cohete_pesado` | Atlas V 541 | 58,3 m | 1.200 kg |
| `assets/modelos/cohete_super.glb` | `cohete_super` | Saturno V | 110,6 m | 1.800 kg |

Reglas de entrega:

- `.glb` a escala real en metros (escala 1:1 del proyecto, ver `docs/ESCALAS.md`), base apoyada en `y = 0`.
- Subir también el `.import` y el `.uid`; los `.glb` van con Git LFS.
- Anotar en este documento la autoría y la licencia de cada modelo.
- Mientras un archivo no exista, `ModelosEquipo.existe()` devuelve `false` y el juego sigue usando el dibujo por código: **se puede entregar de uno en uno sin romper nada**.
- Para el superpesado ya existe `assets/nasa/modelos/saturn_v.glb` (NASA 3D Resources, «free and without copyright»). Si se usa ese, **no es obra del equipo** y va con su crédito, nunca como modelo propio.

### Entregados el 14 de noviembre (Evelyn)

- `cohete_medio.glb` — **Atlas V 541**. Llegó ya en metros y de pie, con la base en `y = 0`: 5,4 × 58,3 m, que es su tamaño real. Cumple el contrato tal cual.
- `cohete_super.glb` — **Saturn V**. Llegó **tumbado sobre Z y en otras unidades**. No se tocó el archivo: `launch_pad.gd` lo endereza, lo centra y lo apoya en `y = 0` al cargarlo.
- Ambos se escalan a la altura real del lanzador que representan, declarada en `content/parts.json` (`alto_real_m`: 58,3 y 110,6 m), para respetar la escala 1:1 de `docs/ESCALAS.md`. `tests/test_cohetes.gd` lo comprueba.
- Autoría y licencia de estos dos modelos: **pendiente de anotar por Evelyn**.

Qué es de cada quien: la **capacidad, el costo y el `ref_clave`** de cada cohete son datos del taller (`content/parts.json`); el **modelo y su aspecto** son del equipo de arte. Si al llegar los modelos cambian las capacidades o los costos, `tests/test_cohetes.gd` avisa en el momento si el balance se rompe.

### Entregados el 14 de noviembre · segunda tanda (Evelyn)

Llegaron el **Delta II** y el **Titan IIIE-Centaur**. Con ellos están los cuatro, así que se revisó a qué
pieza corresponde cada uno en vez de dejarlos en el hueco que quedaba libre: el orden del manifiesto
(ligero → superpesado) ahora coincide con el orden real de los cuatro lanzadores, tanto en altura como en
lo que cada uno podía mandar a Marte.

| Antes | Ahora | Por qué |
| --- | --- | --- |
| `cohete_medio` = Atlas V 541 | `cohete_pesado` = Atlas V 541 | Es el más capaz de los tres primeros: llevó Curiosity y Perseverance. |
| `cohete_medio` sin modelo | `cohete_medio` = Titan IIIE-Centaur | 48,8 m: queda entre el Delta II y el Atlas V, igual que de verdad (Viking y Voyager). |
| `cohete_ligero` sin modelo | `cohete_ligero` = Delta II | El más pequeño de los cuatro (39 m) y el que llevó Spirit y Opportunity. |

Cómo llegaron, y qué hace `scenes/b/launch_pad.gd` con cada uno al cargarlo (**no se tocó ningún archivo
de arte**):

- `cohete_ligero.glb` — un solo nodo `Delta_II`, de pie y en metros, pero con **escala no uniforme**
  (0,6 × 0,5 × 0,6) y desplazado del origen. Se iguala la escala a su componente mayor, se centra y se
  apoya en `y = 0`.
- `cohete_medio.glb` — con **esqueleto y animación propia, «Armado»** (8,3 s): la cofia, el Centaur, el
  núcleo y los dos aceleradores laterales entran volando hasta su sitio. Su «rig» viene con una
  escala rara (0,6 × 0,4 × 0,6), pero al tener esqueleto esa escala **se cancela sola** en la pose
  de reposo y el cohete se ve a su tamaño de malla. Lo que hubo que arreglar fue *medirlo*: la
  medida corriente arrastraba esa escala y lo dejaba a la mitad, así que al estirarlo a 48,8 m se
  salía por arriba de la pantalla. Si entregas un modelo con esqueleto no hace falta que quites esa
  escala: `scenes/b/launch_pad.gd` ya lo tiene en cuenta.
- `cohete_pesado.glb` — Atlas V 541, de pie y a escala uniforme; solo se centra y se apoya.
- `cohete_super.glb` — Saturno V, llegó en otras unidades y descentrado; se normaliza igual.

Los cuatro se escalan a la **altura real** del lanzador que representan, declarada en
`content/parts.json` (`alto_real_m`), para respetar la escala 1:1 de `docs/ESCALAS.md`.
`tests/test_cohetes.gd` lo comprueba uno por uno.

**Animaciones de armado.** Si el `.glb` trae una animación, la plataforma la reproduce en lugar
del montaje por grúas que dibuja el juego, y la lleva al ritmo del propio archivo (con un tope de
9 s). Si no la trae, el cohete se monta por tramos como antes. Dicho de otro modo: **una animación
nueva entra sin tocar código**, igual que el modelo.

**Los cuatro llegaron ya con la suya** (14 nov): 8,3 s cada una, con las etapas, la cofia y los
aceleradores entrando volando hasta su sitio. Todas se llaman `Armado`; Blender exporta además
copias numeradas (`Armado.001`…) que son la misma, y el juego se queda con la del nombre limpio.
Si al reexportar se renombra, el cohete vuelve a montarse por grúas sin avisar: hay una prueba que
lo fija cohete por cohete (`tests/test_cohetes.gd`).

Autoría y licencia de los cuatro modelos: **pendiente de anotar por Evelyn**.

## Edificio de montaje — entregado el 14 de noviembre

`assets/modelos/hangar_gaia.glb` (9,2 MB). Es el escenario de la plataforma: el rover espera dentro
y el cohete elegido se monta en su bancada. Al importarlo, Godot saca las 15 texturas incrustadas a
`assets/modelos/hangar_gaia_*.png`; **van al repositorio con el modelo**, o el edificio se ve gris.

El modelo trae de serie más de lo que aquí se usa, y `scenes/b/launch_pad.gd` lo esconde al
cargarlo (constante `HANGAR_FUERA`), sin tocar el archivo de arte:

- **su cohete** (y sus propulsores, motores, toberas, anclajes y brazos): el cohete es el que elige
  el jugador, de los cuatro del manifiesto;
- **sus dos rovers y su personal**: el rover es el Perseverance del juego;
- **su base de lanzamiento**: la pone el juego a la medida del cohete y con la escotilla por la que
  entra el rover;
- **su cielo exterior**: se ve el del panorama cuando el techo se abre.

Dos cosas que conviene saber si se vuelve a exportar:

- El edificio mide 28 m de alto y los lanzadores, de 39 a 110,6 m: **no caben**. Se escala al cohete
  elegido, como se haría de verdad. La cámara ya encuadra cada lanzador igual, así que el edificio
  se ve siempre del mismo tamaño en pantalla; la comparación entre cohetes la da la silueta del
  manifiesto, no el edificio.
- **El techo se abre en dos hojas para el despegue.** El modelo lo trae como una sola malla por
  material, así que el juego lo parte por triángulos al cargarlo. Los grupos que se parten son
  `Cerchas del techo`, `Ventanales techo` y `Reflectores techo`: si se renombran, el techo deja de
  abrirse (y no lo nota ninguna prueba, solo se ve en una captura).

Autoría y licencia del edificio: **pendiente de anotar**.
