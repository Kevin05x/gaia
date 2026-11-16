# GAIA

**ES.** Juego 3D de diseño y operación de misiones espaciales para el **NASA Space Apps Challenge 2026**, reto *Space Mission Design Game*. Equipo **Full Galácticos**, Cajamarca, Perú.
**EN.** A 3D game about designing and operating space missions, made for the **NASA Space Apps Challenge 2026** (*Space Mission Design Game*). Team **Full Galácticos**, Cajamarca, Peru.

> **GAIA** es un nombre provisional. GAIA is not affiliated with NASA.

## Jugar / Play

| Cómo | Dónde |
| --- | --- |
| **Windows (recomendado, gráficos completos)** | Descarga el `.zip` en <https://info.gaianasa.tech/juego.html#descargar>, descomprímelo y abre **`Jugar GAIA.bat`**. No necesita instalación. |
| **Navegador** | <https://gaianasa.tech> (la primera vez tarda en abrir: el navegador prepara los gráficos; en equipos con gráficos integrados puede ir a tirones) |
| **Web del proyecto** | <https://info.gaianasa.tech> (el reto, cómo nació, cómo se juega, el mundo y el equipo, en español e inglés) |

Windows puede avisar que el programa no está firmado: pulsa «Más información» y «Ejecutar de todas formas». La web del juego también se publica en <https://kevin05x.github.io/gaia/>.

**Medido en una Intel UHD (15 nov 2026):** escritorio con OpenGL, 59 FPS; escritorio con Vulkan, 26 FPS; navegador en Baja, unos 28 FPS a pantalla completa. Detalle en `docs/mediciones/`.

## Qué es

- Bucle: **briefing, taller** (masa, presupuesto de 700 M$, energía, comunicaciones, instrumentos), **revisión Go/No-Go por roles, lanzamiento, crucero, aterrizaje con grúa aérea, operaciones sol a sol e informe** con las causas y la comparación con la misión real.
- Dos destinos: **Marte** (cráter Jezero, con historia y combate) y la **Luna** (polo sur, solo exploración).
- Meta de la partida: enviar 100 unidades de datos a la Tierra antes de que termine el sol 6. Un dato solo cuenta cuando llega a la Tierra.
- Tres dificultades. La duración del sol la elige el jugador (6, 8, 10 o 12 minutos reales).
- **De 1 a 4 personas, cada una con su propio rover** en la misma misión y con su rol: Dirección, Ingeniería, Ciencia y Comunicaciones. En red cada jugador ve el nombre de los demás sobre su rover y un punto en el minimapa. El presupuesto es 700 M$ más 200 M$ por cada jugador de más, repartido por rol.
- Multijugador por la misma red Wi-Fi o por internet (salas en `sala.gaianasa.tech`). «Nueva partida → Equipo: N personas» es la misma pantalla con un solo rover; para un rover por persona se usa **Multijugador**.
- Base: paneles solares, luces, domos de almacén, extractor de hielo, hangar, torretas, muros con compuerta y una antena de tres niveles. El rover va hasta cada obra y la suelda.

**Teclas:** B construir · Tab acciones · G descargar la carga · T transmitir · U antena · C panorámica · V radar · Z dron · X minerales · Q y E giran la cámara · F centra la cámara en el rover · P contador de FPS · Esc pausa.

## Documentación

- `docs/PLAN_MEJORAS.md`: plan de trabajo del 15 nov. Empieza por aquí.
- `docs/CUMPLIMIENTO.md`: requisitos del reto, recomendaciones de la NASA y propuestas propias, con evidencia y límites.
- `docs/DATOS_NASA.md`: cada dato, imagen y modelo de la NASA con su fuente.
- `docs/PLATAFORMA.md`: decisión escritorio/web y mediciones; `docs/mediciones/` con los informes.
- `docs/ESCALAS.md`: escala 1:1 del mundo 3D (rover real de 3 m, casilla de 4 m) y las pruebas que la protegen.
- `docs/MULTIJUGADOR.md` y `docs/SERVIDOR.md`: juego en red y cómo está montado el servidor.
- `scenes/b/docs/ARTE_Y_LICENCIAS.md`: arte, audio, modelos, licencias y uso de IA.

## Tecnología

- **Godot 4.7.2** Standard, GDScript (sin .NET). Escritorio con Forward+ (Vulkan) u OpenGL (modo compatible, recomendado en gráficos integrados); web con Compatibility, un solo hilo.
- Tres capas que solo se hablan con órdenes y snapshots: datos en JSON (`content/`), simulación pura sin dibujar nada (`sim/`) y escenas (`scenes/`).
- **675 pruebas GUT** (`tests/`, `scenes/b/tests/`) y una prueba de red de extremo a extremo con sockets reales (`tools/e2e_red.sh`).
- Datos de la NASA: press kits de NASA/JPL, NASA Science, NASA Image and Video Library y NASA 3D Resources. Rover Perseverance, helicóptero Ingenuity y fotos oficiales, con su crédito. Lo que no es real (costos, masas, trayectorias simplificadas, terreno, monstruos) está marcado como valor de juego.

## Cómo correrlo desde el código

Requisitos: [Godot 4.7.2 Standard](https://godotengine.org/) y [Git LFS](https://git-lfs.com/).

```
git clone https://github.com/Kevin05x/gaia.git
cd gaia
git lfs pull
godot --headless --path . --import      # la primera vez
```

Abre la carpeta como proyecto en Godot y pulsa **F5**. Pruebas:

```
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests,res://scenes/b/tests -ginclude_subdirs -gexit
```

## Publicación

- Cada cambio que llega a `main` ejecuta **Publicar web** (`.github/workflows/publicar-web.yml`), que exporta a web y publica en GitHub Pages.
- El juego en `gaianasa.tech`, la web del proyecto y las salas multijugador corren en un servidor propio (`deploy/servidor/`, guía en `docs/SERVIDOR.md`).

## Flujo de trabajo

- Ramas: `main` (publicado), `develop` (integración) y ramas de trabajo.
- Nadie sube directo a `main` ni a `develop`: todo entra con Pull Request (unir con «Create a merge commit»).
- Commits con prefijo: `feat`, `fix`, `test`, `data`, `art`, `docs`, `perf`, `chore`.
- Git LFS para `.blend`, `.glb`, `.png`, `.jpg`, `.wav` y `.ogg`.

## Equipo y uso de IA

Full Galácticos: Kevin Jhoel Huamán Gonzales, Amner Jhonatan Marín Valdez, Evelin Yudith Vásquez Acosta, Jesus Arturo Valdiviezo Zavaleta, Scarlet Sahori Terrones Cerna y Dider Anthony Díaz Becerra.

La idea, el diseño del juego, las reglas y la supervisión son del equipo. **Se usó IA y lo declaramos:** el código se escribió en gran parte con Claude (Anthropic) bajo la dirección del equipo; el logo, el fondo del menú y las ilustraciones de la historia se generaron con IA (Canva, usado desde la app de escritorio de Claude) y llevan la marca visible «Imagen generada con IA · AI-generated»; las voces de radio son síntesis de voz y la música y los sonidos se generan con scripts. Detalle y licencias de modelos y fuentes en `scenes/b/docs/ARTE_Y_LICENCIAS.md` y `docs/CUMPLIMIENTO.md`.
