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
| `assets/audio/gaia_juego.ogg` | Ambiente dentro de la misión (94 s, en bucle) | Música original sintetizada por código |

Se generan con `tools/sintetizar_musica.py` (numpy y scipy: pads, bajo, pulso, campanas FM y reverberación; do# menor, 92 BPM). No usan muestras, grabaciones ni fragmentos de terceros. El vídeo de referencia solo sirvió para fijar la atmósfera (oscura, crecimiento lento); no se copió su música. `scenes/menu/musica.gd` las reproduce con fundido cruzado y respeta el volumen y el silencio guardados.

## Efectos de sonido de las acciones (23 oct 2026)

`motor.wav` (rover rodando), `drill.wav` (taladro), `laser.wav` (espectrómetro), `radar.wav` (radar de subsuelo), `panorama.wav` (cámara), `drone_start.wav` y `drone.wav` (dron), `companion.wav`, `meteo.wav`, `radio.wav` (chorro de datos al transmitir) y `uplink.wav` (subida del enlace) son originales, sintetizados con `tools/sintetizar_sonidos.py` (numpy y scipy). No usan muestras ni grabaciones de terceros. `wind.wav`, `confirm.wav` y `landing.wav` siguen siendo los de la entrega inicial.

La pista `assets/audio/gaia_juego.ogg` se regeneró con más pulso (bajo de corcheas, latido suave, arpegios de campanas y brillo rítmico) usando `tools/sintetizar_musica.py juego`.

## Modelos 3D del equipo de diseño (24 oct 2026)

Entregados por el equipo de diseño del proyecto (renders de Arturo Valdivieso y archivos `.glb`), guardados en `assets/modelos/`. Se cargan con `scenes/b/modelos_equipo.gd`, que los ajusta a la escala del juego y los apoya en el suelo.

| Archivo | Uso en el juego |
| --- | --- |
| `hielo_2.glb`, `hielo_3.glb` | Objetivos de tipo mineral (roca con cristales) |
| `hangar_cuadrado.glb`, `hangar_roundA.glb` | Escenografía de la base, detrás de la estación |
| `foco.glb` | Escenografía: torre de luz de la base |
| `anthena_juego.glb` | Escenografía: antena parabólica auxiliar de la base |
| `taladro.glb` | Escenografía: torre de perforación junto a la base |
| `torreta_simple.glb`, `torreta_doble.glb` | Importadas pero sin usar: las reglas actuales no tienen torretas ni enemigos |

No integrados todavía: `25042_Perseverance.glb` (11 MB y unos 200 000 triángulos: hay que reducirlo a 15 000–25 000 para la web), `base.glb` (módulo lunar de unos 98 000 triángulos y 135 animaciones) y `panel_solar.glb` (1 MB, 26 materiales). Las texturas `foco_spacebits_texture.png` y `taladro_spacebits_texture.png` salen incrustadas en esos `.glb`; falta que el equipo confirme su origen y licencia.
