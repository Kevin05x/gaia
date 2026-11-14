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

**Origen de los edificios (corregido el 14 nov 2026).** Los edificios **no se modelaron desde cero**: el equipo descargó dos kits gratuitos con licencia **CC0** (dominio público, sin obligación de atribución), los colocó y ajustó en Blender y los exportó a `.glb`. Los nombres internos de los archivos coinciden con los de esos kits.

| Archivo | Nombre interno | Kit de origen | Licencia |
| --- | --- | --- | --- |
| `hangar_cuadrado.glb` | `hangar_largeB` | Kenney, «Space Kit» (https://kenney.nl/assets/space-kit) | CC0 1.0 |
| `hangar_roundA.glb` | `hangar_roundA` | Kenney, «Space Kit» | CC0 1.0 |
| `torreta_simple.glb` | `turret_single` | Kenney, «Space Kit» | CC0 1.0 |
| `torreta_doble.glb` | `turret_double` | Kenney, «Space Kit» | CC0 1.0 |
| `anthena_juego.glb` | `satelliteDish_detailed` | Kenney, «Space Kit» | CC0 1.0 |
| `foco.glb` | `lights` | KayKit (Kay Lousberg), «Space Base Bits» (https://kaylousberg.itch.io/space-base-bits) | CC0 1.0 |
| `taladro.glb` | `drill_structure`, `drill_module` | KayKit, «Space Base Bits» | CC0 1.0 |

- Las licencias se comprobaron el 14 nov 2026 en las páginas oficiales. Kenney indica «Creative Commons CC0». KayKit indica «Creative Commons Zero v1.0 Universal» y «Free for personal and commercial use, no attribution required». Ninguna de las dos páginas lista los nombres de archivo; la correspondencia se basa en los nombres internos y en lo que confirmó el equipo.
- **`foco_spacebits_texture.png` y `taladro_spacebits_texture.png`** son el atlas de color del kit KayKit «Space Base Bits» (`spacebits_texture`, 1024 × 1024 según la página del kit), incrustado en `foco.glb` y `taladro.glb`. Godot los extrae al importar. Mismo origen y licencia CC0.
- Aunque CC0 no lo exige, conviene dar crédito a Kenney y a KayKit en los créditos del juego y en la entrega, para que nadie atribuya estos modelos al equipo ni a la NASA. *Pendiente: añadirlo a los créditos del menú (código: lo hace Kevin).*
- Trabajo del equipo: Arturo Valdivieso hizo la selección, la colocación en Blender, la exportación y los renders. *Pendiente: Arturo y Evelyn deben confirmar qué hizo cada uno en estos archivos; no se rellena sin su confirmación.*
- **Hielo** (`hielo_2.glb`, `hielo_3.glb`): sus nombres internos (`rock_crystalsLargeA`, `rock_crystalsLargeB`) son también del Kenney «Space Kit» (CC0). **Cristales y mineral** (`cristal*.glb`, `mineral_2.glb`): nombres genéricos de Blender (`Circle`, `Cube`, `Icosphere`); probablemente los hizo el equipo, pero su autoría queda **por confirmar**.

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

No integrados todavía: `25042_Perseverance.glb` (11 MB y unos 200 000 triángulos: hay que reducirlo a 15 000–25 000 para la web), `base.glb` (módulo lunar de unos 98 000 triángulos y 135 animaciones) y `panel_solar.glb` (1 MB, 26 materiales). (Este párrafo ya se corrigió: el origen de `foco_spacebits_texture.png` y `taladro_spacebits_texture.png` está explicado arriba.)

## Escenas ilustradas de la historia (24 oct 2026)

Las 16 imágenes de `assets/historia/` (introducción, ocho escenas y cuatro finales) están generadas con IA (generador de imágenes de Canva) a partir de capturas del propio juego como referencia, para que el rover, Rocky, los edificios, el terreno y las criaturas se vean como en el juego. El guion y las decisiones son del equipo (`Historia_Juego_GAIA.docx`). Son material provisional del equipo: la declaración de uso de IA debe constar en la entrega. El storyboard completo (con las criaturas y los minerales en 3D) está en Canva.

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

## Texturas de Marte, edificios mejorados y paleta revisada (14 nov 2026 · Arturo Valdivieso, rama `b/dias-y-realismo`)

Uso de IA: los scripts de Blender que generan las texturas y mejoran los modelos los escribió **Claude (Anthropic)** a petición de Arturo, que decidió qué se hacía, los ejecutó en su Blender 5.3 y revisó cada resultado con renders de día y de noche. No se usó ningún generador de imágenes con IA: las texturas salen de ruido procedural calculado por código, no de fotos ni de modelos de imagen. Los scripts están en `assets/texturas/_fuentes/` (con `.gdignore`, para que Godot no los importe).

### Texturas PBR (`assets/texturas/`)

| Archivo | Contenido | Tamaño |
| --- | --- | --- |
| `marte_regolito_color.jpg`, `_normal.jpg`, `_rugosidad.jpg` | Regolito pardo-rojizo con grano fino, gravilla oscura, cantos claros angulosos y ondulaciones suaves de arena | 1024 × 1024, repetible sin costuras |
| `marte_roca_estratos_color.jpg`, `_normal.jpg`, `_rugosidad.jpg` | Roca sedimentaria en estratos horizontales (como los afloramientos del delta de Jezero), con juntas y polvo en los huecos | 1024 × 1024, repetible sin costuras |

- Generadas con `_fuentes/texturas_marte.py` (numpy dentro de Blender: ruido periódico por FFT y Voronoi). Normales en convención OpenGL (Y+), la que usa Godot.
- **Referencia NASA:** los colores se midieron en la foto *Perseverance's Selfie with Ingenuity* (PIA24542, NASA/JPL-Caltech/MSSS, `assets/nasa/selfie.jpg`; crédito en `docs/DATOS_NASA.md`). Solo se tomaron valores medios de color (suelo, sombras, rocas claras, colinas y cielo); **no se copió ni se reutilizó ningún píxel de la foto**.
- **Conectadas en el juego** (`scenes/b/world_art.gd`, con autorización de Kevin): el suelo, las rocas y las lomas lejanas de Marte usan la versión «detalle» (`*_detalle.jpg`: el color dividido por su media, generado con `_fuentes/texturas_detalle.py`), más la normal y la rugosidad. El color de vértice sigue dando el tono de cada zona. Solo con «texturas» activado (Media, Alta y Ultra); Baja sigue lisa y la Luna conserva sus texturas generadas por código. Color medio original: regolito #78634D y roca #90755C.
- Importación fijada en cada `.import`: VRAM comprimida (s3tc/bptc) con mipmaps, mapa de normales marcado y detección 3D desactivada, para que el editor no cambie los ajustes al abrirse.

### Edificios mejorados (`assets/modelos/`, mismos nombres de archivo)

Se generaron con `_fuentes/mejorar_edificios.py`. El script solo exporta si se cumplen estas condiciones: misma caja (±1 %), mismo nodo raíz y origen, y ≤ 2 500 triángulos por modelo. Se comprobó también por separado leyendo los `.glb`.

| Archivo | Medida en el juego (ancho × alto) | Triángulos | Cambios |
| --- | --- | --- | --- |
| `hangar_cuadrado.glb` | 3,9 × 2,7 m | 360 → 600 | 8 ventanas emisivas, barra de luz sobre cada portón, luces laterales, paneles solares y rejilla en el techo |
| `hangar_roundA.glb` | 3,9 × 2,9 m | 166 → 322 | Anillo de 8 ventanas emisivas, 4 luces en la base, luz en la cúpula |
| `foco.glb` | 3,2 × 4,7 m | 356 → 644 | Lámparas emisivas bajo los brazos |
| `taladro.glb` | 3,6 × 4,1 m | 1 198 → 1 294 | Luces de estado (blancas y rojas) alrededor de la cabeza |
| `anthena_juego.glb` | 3,4 × 4,1 m (base: 3,8 × 4,5 m) | 390 → 438 | 4 luces en la base; la punta del alimentador (antes `_defaultMat`) pasa a luz |
| `torreta_simple.glb` | 3,4 × 4,2 m | 576 → 636 | 4 luces en la base y baliza roja arriba (no se usan en el juego actual) |
| `torreta_doble.glb` | 3,8 × 3,6 m | 876 → 936 | 4 luces en la base y baliza roja arriba (no se usan en el juego actual) |

- Materiales PBR: rugosidad y metal coherentes, y un tinte de polvo marciano en los paneles blancos y grises de Kenney. La textura KayKit se deja tal cual.
- Materiales emisivos con nombre fijo: `emisivo_ventana` (cálido), `emisivo_luz` (blanco frío) y `emisivo_baliza` (rojo). Como máximo hay dos por modelo, porque cada material es una llamada de dibujo. `scenes/b/buildings.gd` (`_brillo_emisivo`) ya los atenúa de día y los aviva de noche, sin cambios de código.
- Sin logos ni marcas. Las piezas nuevas son geometría simple hecha por el script, sin recursos de terceros.

### Paleta frente a las fotos de la NASA (aplicada)

Medida en PIA24542. El suelo real de Jezero es más oscuro y pardo que el del juego, y el cielo es beige-caramelo pálido. La paleta nueva va a mitad de camino, para no oscurecer la escena de golpe. Aplicada en `scenes/b/terrain.gd`, `scenes/b/sky_light.gd` (cielo de 7:00, 12:00 y 17:00) y `scenes/b/horizonte.gd` (paisaje lejano).

| Constante | Actual | Medido NASA | Propuesta |
| --- | --- | --- | --- |
| `terrain.gd` `REGOLITH` | #B97E64 | #6E634D (regolito medio) | #947058 |
| `terrain.gd` `CLAY` | #C79170 | #7F7159 (regolito claro) | #A38164 |
| `terrain.gd` `SHADOW_ROCK` | #90614D | #58513D (regolito en sombra) | #745945 |
| `terrain.gd` `BASIN` | #C99C78 | #A18A6B (roca clara) | #B59372 |
| `terrain.gd` `MOUNTAIN` | #85655C | #8C7559 (roca oscura) | #886D5A |
| `terrain.gd` paleta de rocas | #B98160 #A56E52 #B07A5C #C69770 #96654C | #A18A6B #8C7559 #977F62 #C7A37F #7F6B53 | #AD8666 #987256 #A47C5F #C69D78 #8A6850 |
| `terrain.gd` paleta de mesas | #C58C66 #B67E5C #CE9A72 #AE7154 | #B39474 #A18A6B #C7A37F #977F62 | #BC906D #AC8464 #CA9E78 #A2785B |
| `sky_light.gd` 12:00 cielo arriba | #9E7A6E | #DABEA2 | #BC9C88 |
| `sky_light.gd` 12:00 horizonte | #DAAA88 | #DABFA2 | #DAB495 |
| `sky_light.gd` 12:00 niebla | #C99D7F | #C5AA8C (colinas con bruma) | #C7A486 |

El terreno, el cielo y el polvo siguen siendo **estilizados** (decisión de diseño). Esta paleta los acerca a la foto real, pero no los convierte en una reproducción fiel.

## Segunda ronda de arte (14 nov 2026, tarde · Arturo Valdivieso, con autorización de Kevin para el código)

Igual que en la ronda anterior, los scripts los escribió Claude (Anthropic) a petición de Arturo, que los ejecutó y revisó con capturas del juego. No se usó ningún generador de imágenes ni de modelos con IA.

- **Estación de 3 × 3 casillas.** Junto al Perseverance real (3 m), la base parecía de juguete (4,1 m de lado). Ahora mide 10,6 m y ocupa 3 × 3 casillas (`estacion_radio` en `content/mapa*.json`): el rover no la atraviesa, no se construye encima y la bodega se descarga a 2 casillas. Medidas en `docs/ESCALAS.md`; lo comprueba `tests/test_estacion_grande.gd`.
- **Materiales coherentes con el entorno.** La estación, el compañero, el dron y el rover de bloques (`scenes/b/assets/models/*.tscn`) tienen polvo en las piezas claras y PBR por tipo de pieza: paneles solares brillantes, metal gris, goma mate y pantallas con un brillo suave (`_fuentes/materiales_entorno.py`; solo cambia propiedades de los materiales). Los edificios llevan más polvo, y la textura KayKit del foco y del taladro está teñida y un 20 % menos saturada (`_fuentes/mejorar_edificios.py`); por eso cambian `foco_spacebits_texture.png` y `taladro_spacebits_texture.png`, que Godot extrae de los `.glb`.
- **Cristales, hielo y mineral reparados** (`_fuentes/reparar_minerales.py`). Tenían entre 56 y 350 caras con la normal al revés, que se veían negras: se recalcularon hacia fuera, con sombreado plano. El hielo pasa de roca naranja con cristales verdes a roca de la paleta del terreno con hielo blanco azulado. Los cristales conservan su color, que identifica cada mineral; ahora brillan más. Misma caja y mismos triángulos.
- **Paisaje lejano más realista** (`scenes/b/horizonte.gd`). Tiene la paleta y la bruma de la foto NASA: el borde del cráter se ve claro y desvaído. Las lomas llevan la roca en estratos en triplanar (`mountain_material()` en `world_art.gd`, solo en Marte y con texturas).
- **Pruebas de optimización** (`tests/test_optimizacion_arte.gd`): ≤ 2 500 triángulos y ≤ 8 materiales por modelo del equipo, 1 o 2 materiales emisivos por edificio, texturas de ≤ 1 024 px comprimidas en VRAM y con mipmaps, ≤ 6 MB de texturas, las de Marte solo en Marte y con texturas, Baja sin texturas, y el paisaje lejano con menos de 15 000 triángulos.
- **Rendimiento medido en una GPU real** (Intel UHD Graphics, `docs/mediciones/v4_arte_intel_uhd_antes_despues.txt`). Alta pasa de 19,3 a 20,1 FPS y Baja se queda en 60 FPS; las llamadas de dibujo bajan de 525 a 522 (Alta) y de 343 a 338 (Baja). Usa unos 32 MB más de VRAM en Alta.

## Tercera ronda de arte (14 nov 2026, tarde · Arturo Valdivieso)

Scripts de Blender escritos por Claude (Anthropic) a petición de Arturo, ejecutados y revisados por él con capturas del juego. No se usó ningún generador de imágenes ni de modelos con IA.

- **Luna con texturas propias** (`_fuentes/texturas_luna.py`): regolito gris con microcráteres de borde elevado, gravilla y polvo fino; roca lunar tipo brecha (fragmentos claros de anortosita y oscuros de basalto en una matriz gris) con vesículas. La paleta se midió en la foto NASA as11-40-5903 (Apolo 11), sin copiar píxeles. Se usan en el suelo, las rocas y las lomas del fondo de la Luna (`TEX_DESTINO` en `world_art.gd`). El color de referencia de cada textura está en `_fuentes/` y no se exporta con el juego.
- **La Tierra en el cielo lunar** es una foto real: «Earth (B)» de NASA 3D Resources (mismo repositorio que los modelos de la NASA), recortada al disco con el fondo transparente (`_fuentes/tierra_disco.py`, `assets/nasa/tierra_disco.webp`). Se dibuja como una lámina orientada a la cámara: desde la Luna, la Tierra está casi quieta en el cielo. No es obra del equipo; fuente en `docs/DATOS_NASA.md`.
- **Rocas esculpidas** (`_fuentes/rocas_esculpidas.py`, `assets/modelos/rocas_esculpidas.glb`): las rocas grandes de las dos misiones (bloques, cantos, afloramientos y acantilados; 4 variantes de cada uno) ahora son no convexas y erosionadas, con fracturas y estratos (unos 300 triángulos). Se ajustan a la caja de la roca anterior, así que ningún obstáculo cambia de tamaño. Las piedras pequeñas siguen siendo procedurales.
- **Minerales realistas**: los objetivos «mineral» muestran, al azar, cobre nativo (pepitas ramificadas metálicas con pátina verde de malaquita), oro (pepitas picadas en una veta de cuarzo con óxido de hierro) o plata nativa (hilos y pepitas con matiz celeste y deslustre negro de acantita). El hielo enterrado son prismas hexagonales de hielo azul con burbujas, grietas y escarcha sobre roca. Son materiales PBR físicos, con texturas de color, metal y rugosidad (así la pátina, el cuarzo o el deslustre no son metálicos) y normal (`_fuentes/minerales_reales.py`). **Es solo el aspecto**: el recurso que dan sigue siendo el de `content/economia.json` (olivino); el cobre, el oro y la plata no existen como recursos en las reglas. Su abundancia en el juego es ficticia.
- **Nido de los monstruos** como caverna que sale del suelo: montículo de roca oscura con una boca que se hunde, garras de roca, sacos de huevos con brillo violeta que late y telarañas con velo de seda (`_fuentes/nido_caverna.py`, `assets/modelos/nido_caverna.glb`; `combat_view.gd`). Solo se ve en destinos con combate.
- **Cristales** (`cristal*.glb`, ya no aparecen en la partida): estrías e inclusiones con brillo de gema (`_fuentes/cristales_textura.py`).
- **Cráteres de la Luna hundidos y naturales** (14 nov, noche). Arturo vio que los cráteres parecían sobresalir y repetirse como sellos. Había dos causas:
  - **Tangentes:** las mallas del suelo y de las colinas no tenían tangentes, y sin ellas Godot invierte el mapa de normales, así que todo hundimiento se veía como un bulto (comprobado con un cráter de prueba iluminado desde un lado). Ahora llevan la tangente que daría `generate_tangents` (`terrain.gd`, `tangente_suelo`). Esto también corrige el relieve de la gravilla de Marte.
  - **Textura:** el regolito (`texturas_luna.py`) ya no tiene 140 cráteres casi iguales y muy marcados. Ahora tiene unos 900 de todos los tamaños con una ley de potencias (muchos pequeños, pocos grandes), como en las fotos de Apolo y del LRO. Casi todos son viejos, con borde suave y poco hondos; unos pocos son jóvenes, con cuenco nítido, borde levantado y eyecta clara en rayos. Tienen formas algo irregulares y una ondulación suave entre ellos. La inclinación media del mapa de normales bajó de 17° a 5°.
  - **Repetición:** en la Luna el suelo repite cada 20 m en lugar de cada 12,5 m.
  - Lo cubren las pruebas de `tests/test_relieve_suelo.gd`.
- **Avisos técnicos para el equipo.** (1) Blender 5.3 guarda los JPEG **de color** con un marcador CICP que Godot 4.7 no lee (la textura se queda vacía, sin error visible); por eso las imágenes de los `.glb` van en WebP. (2) Godot no importa el barniz glTF (`KHR_materials_clearcoat`): el brillo del hielo y de los cristales viene de su rugosidad. (3) Al unir piezas en Blender, las que no tienen color por vértice heredan negro con alfa 0; hay que darles blanco antes.

## Cuarta ronda de arte: chapa realista en los edificios (14 nov 2026, noche · Arturo Valdivieso)

Igual que en las rondas anteriores, el script y el sombreador los escribió Claude (Anthropic) a petición de Arturo, que los revisó con capturas del juego. No se usó ningún generador de imágenes ni de modelos con IA: las texturas salen de ruido periódico y formas simples, sin píxeles de fotos.

- **Texturas de chapa** (`_fuentes/texturas_edificios.py`, uso: `blender -b --factory-startup -P texturas_edificios.py`): `assets/texturas/edificio_paneles_detalle.jpg`, `_normal.jpg` y `_mascaras.jpg` (1024 px, repetibles). Son paneles atornillados como los de un módulo espacial: juntas hundidas, remaches, tapas de registro, rayones, manchas y suciedad que escurre desde las juntas. Las máscaras guardan la rugosidad (R), dónde se pega el polvo (G) y la oclusión de las juntas (B).
- **Sombreador** `scenes/b/shaders/edificio.gdshader` (con `scenes/b/material_edificio.gd`). Conserva el color de cada pieza y le pone la chapa en proyección triplanar, en metros reales del objeto (una repetición cada 3 m, con paneles de 37 cm a 1,1 m). Como usa las coordenadas del objeto, la textura no resbala cuando la torreta gira o el dron vuela. Encima pone el polvo del destino: gris en la Luna y ocre en Marte, en las caras que miran hacia arriba y en la franja baja que toca el suelo. Los dos tonos de polvo se eligieron a ojo para que casen con la paleta del terreno, que es estilizada: no son una medición.
- **Dónde se usa:**
  - Los 7 modelos de edificios: foco, domo, extractor, hangar, antena y las dos torretas. Sus materiales emisivos (ventanas y luces) se quedan como estaban y siguen brillando de noche.
  - Las mallas de bloques fundidas: estación, paneles solares, grúa, compañero, dron y rover web. Al fundirlas, cada pieza guarda su rugosidad y su metal en UV2. Las celdas solares ahora son lisas y reflejan.
  - Los minerales, cristales, rocas y el nido conservan sus materiales.
- **Calidad baja:** sin texturas de chapa; queda solo el polvo.
- **Suelo de cerca.** Se probó una capa de microdetalle (gravilla de milímetros) sobre el regolito, pero el «detalle» de `StandardMaterial3D` **reemplaza** el mapa de normales de la textura grande, así que aplanaba los cráteres. Se quitó, y el suelo queda como en la ronda anterior. En su lugar, el filtrado anisótropo pasó a 16× (`project.godot`): el suelo ya no se emborrona cuando la cámara lo mira casi de lado.
- Lo cubren las pruebas de `tests/test_material_edificio.gd`. El presupuesto de texturas de `tests/test_optimizacion_arte.gd` pasa de 12 a 15 archivos.
