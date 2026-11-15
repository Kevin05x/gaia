# GAIA · Plan de mejoras después de la integración (15 nov 2026)

Escrito el sábado 14 de noviembre, noche, a partir de la prueba de Kevin sobre la rama `integracion`.
**Entrega: domingo 15 de noviembre, 23:59 (Cajamarca). Meta interna: terminar a las 21:59.**
Quedan unas 26 horas: el plan está ordenado por prioridad. Lo que no quepa se queda en «Después del reto».

## Cómo usar este documento (prompt para Claude Code en VS Code)

Copia este bloque en Claude Code, con la carpeta `gaia` abierta:

> Lee `CLAUDE.md` y `docs/PLAN_MEJORAS.md`. Trabaja las tareas en el orden del plan, una rama por bloque, saliendo de `develop`
> (`git fetch origin && git checkout -b <rama> origin/develop`). Para cada tarea: lee los archivos que cita, haz el cambio
> más pequeño que la resuelva, añade o ajusta pruebas, corre las pruebas (deben pasar todas) y marca la tarea con `[x]` en este archivo.
> Si una tarea pide decidir algo de diseño que el plan no decide, pregúntame antes. No subas nada directo a `main` ni a `develop`:
> abre un Pull Request. Si usas Blender (por MCP), guarda el `.blend` en `assets/_blender/`, exporta `.glb` y anota el origen
> en `scenes/b/docs/ARTE_Y_LICENCIAS.md`. Todo texto nuevo va en español e inglés.

Reglas que no cambian: arquitectura de tres capas (`content/` → `sim/` → `scenes/`), `sim/` no dibuja, la vista no toca el estado,
`EventBus` solo con dos aprobaciones, declarar el uso de IA y no afirmar que algo se midió si no se midió.

---

## Bloque 0 · Estado de las ramas (revisado el 14 nov, 20:10; actualizado 20:15)

- [x] `integracion` contiene **todas** las ramas: `b/dias-y-realismo` (con `b/arte-realista` de Arturo), `b/cohetes-telescopio` (Amner),
  `a/historia-sin-monstruos` (Tony) y `b/multijugador`. Se comprobó commit por commit (`git rev-list origin/integracion..<rama>` = 0).
- [x] Tony: su commit `37abbb9` (170 archivos, +3 473 líneas) está entero. Los 144 archivos de `assets/historia/radio/` (72 voces
  con su `.import`) son **idénticos** a los de su rama, no le falta ninguna función a ninguno de sus `.gd`, y las líneas suyas
  que cambiaron fueron por los cambios de otra rama (obra con rover de Arturo, cohetes de Amner), sin borrar nada suyo.
- [ ] **Voces que no están en ninguna rama de GitHub.** Las voces subidas son las de la historia: `aterrizaje`, `alerta_sismica`,
  `noche_aranas`, `falla_*`, `estacion_*`, `nidos*`, `glaciar_*`, `climax_*`, `nave_fuga`. **No hay** voces de «mover el rover» ni de
  «Houston, despegando». Si Tony las grabó, siguen en su computador sin subir. Pedirle: `git status` en su carpeta y subirlas en
  una rama nueva desde `develop` (por ejemplo `a/voces-rover`).
- [ ] Las voces solo suenan en **Marte con historia** y en **partida nueva**. Con «Continuar» de una partida guardada antes de la
  integración no salen la introducción ni las escenas. Para probar: «Nueva partida» → Marte.
- [x] Unir: PR #56 `integracion` → `develop` y PR #57 `develop` → `main` (14 nov, 20:05). La web publicada ya es la integración.
- [ ] Las voces de mover el rover y del despegue las hacemos nosotros (Tony no las hizo): ver **Bloque 9**.
- [ ] Autoría y licencia de los modelos de Amner: ver **9.4**. Telescopio: ver **Bloque 10**.

---

## Bloque 1 · Errores que se ven en la primera partida (P0, 3–4 h)

| # | Problema que vio Kevin | Dónde mirar | Qué hacer | Cómo se comprueba |
|---|---|---|---|---|
| [x] 1.1 | La cuadrícula aparece sola cada vez que el rover se mueve | `scenes/b/mission_view.gd` (al recibir una ruta llama a `terrain.flash_grid()`), `scenes/b/terrain.gd` | Quitar el destello al moverse. La cuadrícula solo se ve con el botón (o con la tecla) y en el modo construir | Moverse con la cuadrícula apagada: no aparece |
| [x] 1.2 | Al abordar, el rover atraviesa la rampa | `scenes/b/launch_pad.gd` (`_build_mesa`, la rampa hacia `_puerta`, `DURACION_ABORDAJE`) | Que el recorrido siga la pendiente de la rampa (altura por tramo) y que la rampa llegue al suelo | Captura del abordaje desde el lateral |
| [x] 1.3 | «Opciones» y «Código» se montan en pantallas pequeñas | `scenes/b/workshop.gd`, bloque con `UI.place(opciones, "bl", ...)` y `codigo` | Colocarlos en una fila con anclaje y separación fija, o dentro del panel del catálogo | Ventana 1280×720 y 1024×600 |
| [x] 1.4 | Cambiar la resolución no se aplica o vuelve a la anterior; no pasa de 1080 | `scenes/menu/menu_text.gd` (`TAMANOS_VENTANA`, `DisplayServer.window_set_size`), `project.godot` (`display/window/...`) | Separar «tamaño de ventana» de «pantalla completa»; en pantalla completa usar la resolución nativa del monitor; guardar y leer la preferencia en un solo sitio; añadir 2560×1440 y «nativa» | Cambiar de 1280 a 1920 y a pantalla completa, cerrar y abrir |
| [x] 1.5 | Las escenas tardan 5 s en mostrar el texto | `scenes/b/story_panel.gd`, `const ESPERA_IMAGEN := 5.0` | Bajar a 1,2 s; el texto aparece con un fundido mientras la imagen sigue visible | `tests/test_vista_historia.gd` sigue en verde |
| [x] 1.6 | En el taller rumbo a la Luna se ve Marte al fondo | Fondo del hangar en `scenes/b/workshop.gd` / escena del hangar | Elegir el fondo según `Destino.id` (Luna: horizonte gris y la Tierra en el cielo) | Abrir el taller con Luna |
| [x] 1.7 | «Oportunidad científica → Desviarse» no hace nada visible | `content/imprevistos.json` (`oportunidad`), `sim/systems/imprevistos_system.gd` (`datos` va a la **memoria** del rover, no a «Ciencia 0/100», y se recorta si la memoria está llena) | Al elegir, mostrar el resultado: aviso «+10 datos en memoria: transmítelos en la próxima ventana», marcar un punto en el mapa y mover el rover hasta él. Revisar los 9 imprevistos con el mismo criterio | Elegir cada opción y ver un cambio en pantalla |

Decisiones de Kevin para 1.7 (15 nov): los +10 datos entran en memoria **al decidir**; el rover sale solo hacia una casilla
libre a unas 5 casillas, y los 90 Wh incluyen el viaje. Si la memoria está llena, lo que no cabe se pierde y el aviso lo dice.

### Decisiones de Kevin para el resto del plan (15 nov, mañana)

| Tarea | Decisión |
|---|---|
| 2.4 | La plataforma llega con el **cohete medio ya marcado**; el hangar llega con el resto del diseño recomendado y el botón «Diseño recomendado» lo restaura. En la **Luna**, el diseño recomendado lleva **MMRTG** en vez de panel solar (y la trayectoria directa lunar). |
| 2.5 | El aviso **no lleva cifra**: «Sin taladro no podrás tomar muestras». |
| 2.1 | La Luna **mantiene la meta** (100 datos antes del día 6) con textos lunares en su tarjeta. La 3.5 queda para después del reto. |
| 2.2 | Ventana **anclada abajo a la izquierda** (se puede arrastrar); la radio de Houston espera mientras está abierta. |
| 2.2 y 2.3 | Capturas en **español e inglés** (`assets/tutorial/es` y `/en`). |
| 2.6, 2.7, 2.8 | Se hacen las tres. En 2.7 no se inventan consecuencias: se muestra lo que hoy cambia cada decisión y se listan para Tony las que no cambian nada visible. |
| 3.4 | La tormenta pasa al **sol 4** en `content/rules.json`. |
| 3.1 | El selector va en la **pantalla de destino**; en red, en la sala (lo fija el anfitrión). |
| 3.2 | Más batería en **Marte y Luna**. |
| 4.1 | Estilo en **todo el juego**. Títulos con una **fuente OFL parecida al logo** (con su licencia, anotada en `ARTE_Y_LICENCIAS.md`). Con la 4.1 se arreglan también las etiquetas cortadas de la barra de pasos del hangar. |
| 1.6 (extra) | El consejo de trayectoria del hangar lunar deja de decir «Marte». **Revisado: no era un fallo del juego** (`content/destinos.json` ya trae el texto lunar); solo la herramienta de capturas no aplicaba los textos lunares. Corregida la herramienta. |
| 6 | Se mide en el **PC de Kevin**; la Intel UHD la mide el equipo. |
| 9 | Las voces las **genera Claude** (voces de Windows y Piper, efecto de walkie-talkie propio, anotado en `ARTE_Y_LICENCIAS.md`); si llega el script de Tony, se regraban. |
| 8 | Claude prepara las **7 diapositivas** (presentación web descargable como PPTX/PDF), el **texto del proyecto** en inglés y el **guion y subtítulos** del video. El montaje del video es del equipo. |
| 7 | Claude prepara los **archivos y la guía**; Kevin los corre en su servidor. |
| 10 | Solo **si sobra tiempo**. |

---

## Bloque 2 · Que se entienda el juego (P0, 4–5 h)

El problema principal: **un jugador nuevo no sabe cuál es el objetivo ni qué hacer**.

- [x] **2.1 Pantalla de objetivo** al empezar la misión (después del aterrizaje): una sola tarjeta con la meta («Envía 100 datos a la Tierra
  antes de que acabe el sol 6»), las 3 cosas que la hacen posible (energía → instrumentos → antena y ventana de enlace) y un botón «Entendido».
  Distinta para Marte y Luna (ver 3.5). Archivos: `content/tutorial.json`, `scenes/b/` (nuevo panel).
- [x] **2.2 Tutorial en ventana**, no a pantalla completa ni en el cuadro marrón de la derecha: una ventana mediana (~640×420),
  movible o anclada abajo a la izquierda, con **captura real** del paso, flecha a lo que hay que pulsar y «Siguiente / Saltar».
  Las capturas se generan con el propio juego (modo `--capturas` que recorra los pasos y guarde PNG en `assets/tutorial/`).
  Archivos: `sim/systems/tutorial_system.gd` (pasos), `content/tutorial.json`, panel del tutorial en `scenes/b/`.
- [x] **2.3 «Cómo jugar» del menú con imágenes reales** (las mismas capturas de 2.2) en cada una de sus 5 páginas. `scenes/menu/`.
- [x] **2.4 Configuración del rover por defecto** en el taller: entrar con un diseño válido ya armado (cohete medio, trayectoria rápida,
  chasis base, panel solar, antena relé, cámara, espectrómetro y taladro) y un botón «Diseño recomendado». El jugador puede cambiarlo.
  Archivos: `scenes/b/workshop.gd`, `content/parts.json` (marcar `"recomendada": true`), la simulación (`design_add`).
- [x] **2.5 Aviso si falta un instrumento clave** (taladro, espectrómetro, cámara o antena): en la validación de misión, una línea roja
  «Sin taladro no podrás tomar muestras: perderás X datos posibles» y una confirmación al pulsar DESPEGAR. No bloquea.
  Archivos: validación en `sim/simulation.gd` (`_taller()`), textos en `scenes/b/i18n/`.
- [x] **2.6 Imprevistos que explican qué implica cada opción**: debajo de cada opción, el efecto en lenguaje de juego
  («−90 Wh: unas 2 h menos de batería · +10 datos en memoria»). Rediseño visual en el bloque 4.
- [x] **2.7 Que las decisiones de la historia cambien algo que se vea**: cada opción de `content/historia.json` debe dejar una huella
  visible (un edificio, un recurso, un aviso de radio distinto, un final distinto). Revisar con Tony qué cambia hoy cada decisión y
  mostrarlo en la tarjeta («Esta decisión cambiará: …»). Archivos: `sim/systems/story_system.gd`, `scenes/b/story_panel.gd`.
  - Hecho (15 nov): la tarjeta dice lo que cambia de verdad cada opción (batería, datos, ética, Rocky, recursos, bodega, rama de
    la historia, final y si termina la misión), sacado de sus `efectos` y no escrito a mano.
  - **Para Tony**: estas dos opciones hoy no cambian nada visible al elegirlas (son «dejarlo para después»). Si deben dejar huella,
    añadirles `efectos` en `content/historia.json` y quitarlas de `SIN_HUELLA` en `tests/test_mejoras_bloque2.gd`:
    `falla_sismografo` · «Verificar en el segundo sensor» (el coste llega después, al medir) y
    `estacion_auxiliar` · «Volver más tarde» (deja la estación pendiente).
- [x] **2.8 Escenas que faltan**: confirmar con «Nueva partida» que salen la introducción («de qué trata el juego») y las escenas de Tony.
  Si alguna no sale, revisar `scenes/b/story_panel.gd` (`intro_pages`) y `content/historia.json`.
  - Comprobado (15 nov, pruebas en `tests/test_mejoras_bloque2.gd`): «Nueva partida» → Marte abre la introducción; la
    introducción, las escenas y los 4 finales tienen imagen; tras aterrizar llega la radio de Houston del aterrizaje; las 36 líneas
    de diálogo de la historia tienen voz en español e inglés. No faltaba nada. Con «Continuar» la introducción no se repite (a propósito).

---

## Bloque 3 · Lógica del juego (P1, 2–3 h, con decisión del equipo)

- [x] **3.1 Duración del sol a elección del jugador** (decidido por Kevin el 14 nov): antes de empezar la partida, un selector
  **«Duración de cada sol: 6 · 8 · 10 · 12 minutos»** (por defecto 12). La partida dura lo que tenga que durar (6 soles = 36 a 72 min).
  - Dónde se elige: pantalla previa a la misión (después de elegir destino y dificultad) y, en red, en la sala (lo fija el anfitrión
    y lo ven todos; `scenes/net/sala.gd` → `config`).
  - Cómo llega a la simulación: como dato de configuración al crear la `Simulation` (sustituye a `duracion_sol_s` de
    `content/balance.json`, hoy 300 s), sin que la vista toque el estado. Guardarlo en la partida guardada.
  - Todo lo que hoy depende de segundos reales (ventanas de relé, construcción, oleadas, carga de la batería, tutorial) debe seguir
    medido en **horas de juego**, para que cambiar la duración no cambie el balance. Revisarlo y probarlo con 6 y con 12 minutos.
  - Pruebas: una que cree la simulación con 360 s y otra con 720 s y compruebe que un sol dura eso y que el resultado de un día
    de juego es el mismo.
- [x] **3.2 Más batería**: `content/balance.json` → `capacidad_base_wh` (hoy 1000). Subir a ~2000 y la batería extra en proporción,
  y volver a correr el bot de balance (`tools/`) para que la partida siga siendo ganable pero no trivial.
  - Hecho (15 nov): 2000 Wh en Marte y Luna; la «Batería extra», que no sumaba nada, ahora suma +1000 Wh. **Pendiente**: no existe
    un bot de balance con estrategia (el de `tools/` es el de la red); hay que comprobar jugando que no quedó trivial
    (`scenes/b/docs/BALANCE.md`).
- [ ] **3.3 Coherencia de ritmos**: con sol más largo, revisar ventanas de relé, carga solar, construcción y oleadas.
- [x] **3.4 Tormenta de polvo**: `content/rules.json` la pone en el sol 3 y la historia dice 4–5. Unificar.
- [ ] **3.5 Marte y Luna con objetivos distintos** (hoy comparten meta). Propuesta:
  Marte = «100 datos de ciencia antes del sol 6» (historia y combate);
  Luna = «encontrar hielo en las zonas de sombra permanente y enviar 3 muestras» (sin combate; energía lunar del 70 % y crestas iluminadas).
  Archivos: `content/destinos.json`, `content/rules_luna.json` si existe, `sim/systems/outcome_system.gd`.

---

## Bloque 4 · Interfaz con identidad propia (P1, 4–6 h)

Kevin: «se ve genérica, como una web; botones muy redondeados; ocupa mucha pantalla; los botones estorban».
Referencia buena dentro del propio juego: la **consola de la plataforma** de Amner (`scenes/b/consola.gd`: chapa con esquinas cortadas, corchetes y reglillas).

- [x] **4.1 Un solo estilo** en `scenes/b/ui_style.gd`: esquinas cortadas (chaflán) en vez de redondeadas, borde fino ámbar, fondo oscuro
  translúcido, tipografía del logo GAIA en títulos. Aplicarlo a botones, tarjetas, avisos, tutorial e imprevistos.
- [x] **4.2 Menos ruido en pantalla**: barra inferior de acciones (Panorámica, Radar, Dron, Minerales, Antena) agrupada en un solo bloque
  con iconos y atajos; ocultar acciones que no se pueden usar en vez de mostrarlas apagadas; mover el contador de FPS fuera
  (solo con la opción «Mostrar FPS»).
- [ ] **4.3 Tutorial e imprevistos** como ventanas diseñadas (bloque 2), no el cuadro marrón.
- [ ] **4.4 HUD escalable**: comprobar 1280×720, 1600×900, 1920×1080 y 2560×1440 (`content_scale` y anclajes).
- [ ] **4.5 Logo hecho por el equipo**: modelar el logo GAIA en Blender (texto en 3D con el planeta) y renderizarlo; reemplazar el actual
  hecho con IA en el menú y declararlo en `ARTE_Y_LICENCIAS.md` («diseñado en Blender por el equipo con ayuda de Claude»).
  La imagen de fondo del menú hecha con IA conserva su marca «Imagen generada con IA».

---

## Bloque 5 · Arte con Blender (P2, según el tiempo)

- [ ] **5.1 Despegue**: llama, humo y vapor del cohete (partículas y malla de la columna), vibración de cámara.
- [ ] **5.2 Rampa y escotilla** de la mesa de lanzamiento (ver 1.2).
- [ ] **5.3 Hangar**: el `.glb` ya está aligerado (70 944 triángulos); con Blender se puede bajar más (remaches del suelo: 29 312 triángulos).
- [ ] **5.4 Fondo del taller por destino** (ver 1.6).
- [ ] **5.5 Re-renderizar las fichas** `assets/edificios/*.png` con `tools/renderizar_fichas.gd` (aún sin la chapa nueva).

---

## Bloque 6 · Rendimiento (P1, 1–2 h + medir)

Datos de Kevin en Ultra (14 nov): taller 35–37 FPS (436–575 llamadas de dibujo), Marte ~49 FPS (458 llamadas, 425k triángulos),
Luna 42–60 FPS (427–517 llamadas, 483k–567k triángulos). Arturo midió 20 FPS en Alta en una Intel UHD.

- [ ] **6.1 Llamadas de dibujo**: fundir mallas por material en el taller y en la base (`scenes/b/modelos_equipo.gd` ya lo hace para
  modelos del equipo), `MultiMesh` para rocas y cráteres, LOD (`meshes/generate_lods` ya está activo en el hangar).
  - **No hecho (15 nov), a propósito:** la medición v5 en la Intel UHD del PC de Kevin muestra que el límite no son las llamadas
    de dibujo sino el coste por píxel: con 6.2 la plataforma bajó de 746 a 577 llamadas y siguió a 20 FPS. Fundir mallas no
    movería los FPS en ese equipo; lo que ayudaría es 5.3 (hangar más ligero) o recortar efectos en Alta. Las rocas ya van en
    `MultiMesh` (`terrain.gd`).
- [x] **6.2 Sombras**: en Alta, distancia de sombras más corta y 2 cascadas; en Ultra, 4.
  - Hecho: misión 40 m y 2 cascadas en Media/Alta, 90 m y 4 en Ultra; la plataforma, que usaba siempre 4 cascadas hasta 420 m,
    usa 2 hasta 260 m en Media/Alta.
- [x] **6.3 Medir** con `Medir_rendimiento.bat` antes y después, y guardar los resultados en `docs/mediciones/`.
  - `docs/mediciones/v5_mision_y_plataforma_intel_uhd_antes_despues.txt` (PC de Kevin, que tiene una Intel UHD).
- [x] **6.4 Medir la pantalla de la plataforma en GPU real** (hangar de 70 944 triángulos y los 4 cohetes). Hoy `--medir`
  (`scenes/a/medidor.gd`) entra directo a la misión; añadir `--medir --escena=plataforma` que abra la plataforma con el Saturno V
  elegido, y añadir esa línea a `Medir_rendimiento.bat`. Medir en Alta y Baja en el PC de Kevin y en una Intel UHD, y guardar en
  `docs/mediciones/v5_plataforma_*.txt`. Si en la Intel UHD baja de 30 FPS en Alta, simplificar el hangar en Blender (5.3).
  - Hecho: `--medir --escena=plataforma` y el `.bat` mide misión y plataforma en Alta y Baja. Resultado en la Intel UHD:
    **plataforma en Alta ≈ 20 FPS** (Baja ≈ 55), misión en Alta ≈ 29 (Baja ≈ 59). Baja de 30 → toca **5.3**.

---

## Bloque 7 · Servidor propio para jugar por internet (P1, 2–3 h)

Servidor de Kevin: 2 CPU, 8 GB de RAM (otro sistema usa ~2 GB), 100 GB de disco (30 % usado), y un dominio gratis.
El servidor de GAIA es Godot sin pantalla: unos 100–200 MB de RAM y poca CPU por sala (estimado, **sin medir**). Cabe de sobra.

1. Comprar o activar el dominio y apuntar dos nombres al servidor: `gaia.<dominio>` (la web) y `sala.<dominio>` (el multijugador).
2. En el servidor: Docker y **Caddy** (pone el HTTPS solo, con Let's Encrypt).
3. Web: exportar la versión web de Godot y servirla con Caddy en `gaia.<dominio>`. Godot web necesita las cabeceras
   `Cross-Origin-Opener-Policy: same-origin` y `Cross-Origin-Embedder-Policy: require-corp` si se usan hilos (hoy la web va con un hilo).
4. Multijugador: `docker build -f Dockerfile.servidor -t gaia-servidor .` y `docker run -d --restart unless-stopped -p 127.0.0.1:9080:9080 gaia-servidor`;
   Caddy hace de proxy `sala.<dominio>` → `localhost:9080` con WebSocket (`wss://sala.<dominio>`).
5. En el juego, «Unirse» con `sala.<dominio>` (ya se convierte en `wss://`). Ver `docs/MULTIJUGADOR.md`.
6. Probar con 4 personas en redes distintas y anotar el resultado (hoy **no** se ha probado el servidor dedicado en un servicio real).

---

## Bloque 8 · Entrega del reto (P0 el domingo por la tarde, 3–4 h)

- [ ] Video de máximo 30 s con subtítulos en inglés (motion graphics: problema → taller → lanzamiento → Marte → resultado), o máximo 7 diapositivas.
- [ ] Diapositivas: cómo se juega, historia, datos reales de la NASA, uso de IA, equipo.
- [ ] Texto del proyecto en inglés, declaración de IA (`docs/CUMPLIMIENTO.md`), sin caras ni voces de menores de 18.
- [ ] Consultar con el organizador local el **aviso de reglas** (commits desde el 22 de octubre). No reescribir el historial.

---

## Bloque 9 · Voces nuevas y licencias (P1, 2–3 h)

Las voces de Tony solo existen para las escenas de la historia de Marte. Tony no hizo las de mover el rover ni las del despegue:
las hacemos nosotros, para **Marte y Luna**, en español e inglés.

- [ ] **9.1 Guion** (`content/voces.json`, nuevo): frases cortas de radio con 3 variantes cada una para no repetir.
  - Mover el rover: «Perseverance en marcha», «Ruta confirmada», «Llegando al objetivo», «Batería baja, vuelvo a la base».
  - Despegue (plataforma): cuenta atrás de Houston, «Ignición», «Despegue confirmado», «Separación de etapas».
  - Aterrizaje y primer enlace, para la Luna (Marte ya tiene el de Tony): «Contacto con la superficie», «Enlace con la Tierra abierto».
  - Avisos de juego: noche que llega, ventana de relé abierta, memoria llena, tormenta.
  - En la Luna, «Houston» habla con la referencia de Apolo; en Marte, igual que en la historia de Tony.
- [ ] **9.2 Grabación con el mismo método que Tony** (documentado en `scenes/b/docs/ARTE_Y_LICENCIAS.md`): español con las voces de
  Windows Microsoft Raúl (Houston) y Microsoft Pablo (Perseverance); inglés con Piper, voces John (Houston) y Joe (Perseverance);
  el mismo efecto de walkie-talkie. Nombres de archivo con el mismo esquema (nodo, línea y 12 caracteres del SHA-256 del hablante y
  el texto) en `assets/voces/` (por destino: `marte/`, `luna/`). Pedirle a Tony su script de mezcla para que suenen igual.
- [ ] **9.3 Reproducirlas sin cansar**: un reproductor de voces en la vista (no en `sim/`) que escuche eventos ya existentes
  (ruta recibida, despegue, aterrizaje, avisos), con una pausa mínima entre voces (~20 s), sin pisar las voces de la historia, y
  con opción «Voces de radio: sí/no» en Configuración. Pruebas: que cada frase tenga archivo en los dos idiomas.
- [ ] **9.4 Autoría y licencia de los 5 modelos de Amner** (P0, antes de entregar): `cohete_ligero/medio/pesado/super.glb` y
  `hangar_gaia.glb`. Preguntar a Amner y Evelyn de dónde salen (hechos por el equipo en Blender, descargados de Sketchfab u otro
  sitio, o generados con IA). Anotar en `ARTE_Y_LICENCIAS.md`: autor, herramienta, licencia y enlace. Si alguno no tiene licencia
  que permita usarlo, sustituirlo antes de entregar. Corregir también la frase «Arturo y Evelyn hicieron los modelos 3D» en
  `CLAUDE.md` y `docs/CUMPLIMIENTO.md` si no es exacta.

---

## Bloque 10 · Telescopio (P2; propuesta para decidir)

Propuesta: el telescopio sirve para **ver el cielo real desde donde está el rover**, con imágenes reales de la NASA.

- [ ] **10.1 Qué es en el juego**: un edificio de la base («Telescopio», Marte y Luna) que solo funciona **de noche**, cuando los
  paneles no dan energía y hoy no hay mucho que hacer. Cada noche se puede observar un objetivo.
- [ ] **10.2 Qué se ve** (una tarjeta con la foto real, el dato y la fuente):
  - Desde Marte: la Tierra y la Luna vistas desde Marte (foto real de Curiosity), Fobos y Deimos, el Sol (más pequeño que desde la Tierra).
  - Desde la Luna: la Tierra en el cielo (salida de la Tierra del Apolo 8), el Sol rasante del polo sur, Marte.
  - Cada foto, con su fuente en `docs/DATOS_NASA.md`; sin logos de la NASA en la interfaz.
- [ ] **10.3 Qué da**: datos de ciencia (por ejemplo +5 por observación nueva) y un logro por completar el catálogo.
- [ ] **10.4 Modelo 3D**: telescopio de Evelyn si lo tiene; si no, uno sencillo en Blender (cúpula y tubo).
- [ ] Decidir con el equipo antes de empezar. Si no da tiempo el domingo, queda para después del reto.

---

## Orden sugerido para el domingo

| Hora | Trabajo |
|---|---|
| 08:00–12:00 | Bloque 1 completo + 2.4, 2.5, 1.5 + 9.4 (preguntar a Amner y Evelyn) |
| 12:00–15:00 | Bloque 2 (objetivo, tutorial en ventana con capturas, Cómo jugar) |
| 15:00–17:00 | Bloque 4.1–4.2 (estilo único y menos ruido) + 3.1 (duración del sol) y 3.2 (batería) |
| 17:00–18:00 | Bloque 6 (medir y ajustar, incluida la plataforma) + Bloque 9 (voces) si hay quien grabe en paralelo |
| 18:00–20:00 | Bloque 8 (video y diapositivas) en paralelo con Bloque 7 (servidor) |
| 20:00–21:59 | PR final a `main`, publicar, probar la web publicada y enviar |

## Después del reto

Logo en Blender si no dio tiempo, despegue con partículas, objetivos propios de la Luna, telescopio (Bloque 10), más voces.
