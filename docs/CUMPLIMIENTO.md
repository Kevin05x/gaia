# Cumplimiento del reto — NASA Space Apps 2026, «Space Mission Design Game»

Equipo **Full Galácticos** (sede Cajamarca). Estado real al 14 de noviembre de 2026. Tres columnas distintas, para no mezclar:
**Obligatorio** (lo exige el reto o las reglas oficiales), **Recomendado** (lo sugiere la NASA en sus recursos) y **Propuesta nuestra** (decisión del equipo).
Cada fila dice dónde está la evidencia en el repositorio y si **falta algo**. Nada aquí está marcado como cumplido sin que se haya comprobado.

## 1. Obligatorio

| # | Requisito | Estado | Evidencia | Pendiente / límite |
|---|-----------|--------|-----------|--------------------|
| O1 | Un juego que enseñe a diseñar una misión espacial | Cumple | Taller de diseño (cohete, trayectoria, chasis, energía, comunicaciones, instrumentos) → lanzamiento → crucero → aterrizaje → operaciones → informe. `scenes/b/workshop.gd`, `sim/mission_design.gd` | — |
| O2 | Usar al menos un dato o recurso de la NASA (premio global) | Cumple | Datos con fuente en `content/nasa/*.json` (se muestran en el juego en «Tu misión frente a la real»); fotos oficiales de images.nasa.gov; modelos 3D de NASA 3D Resources; método de los 4 segmentos del recurso «Design and Develop Science Missions». Ver `docs/DATOS_NASA.md` | — |
| O3 | Todo lo entregado en inglés | Parcial | El juego tiene español e inglés (`scenes/b/i18n/`, selector en Configuración); cada dato NASA tiene `es` y `en`. Borrador del texto del proyecto y de la declaración de IA en inglés: `docs/entrega/PROYECTO_EN.md` | El equipo debe leer y completar los puntos marcados **[TEAM: confirm]** y pegarlo en el formulario. La parte en inglés del juego no se revisó con un hablante nativo |
| O4 | Demo: video ≤30 s con subtítulos en inglés **o** ≤7 diapositivas | Borrador preparado (15 nov) | Guion plano a plano y subtítulos en inglés (`docs/entrega/VIDEO_30S_EN.md`, `subtitulos_en.srt`); 7 diapositivas en inglés en una presentación web descargable como PPTX/PDF (enlace en el informe del 15 nov) | El equipo debe montar el video (o descargar las diapositivas), completar en la diapositiva 7 los nombres y la frase de la idea marcados entre corchetes, y revisarlo todo |
| O5 | Imágenes hechas con IA con marca de agua visible | Cumple | Logo, fondo del menú, pantalla de carga e imágenes de historia llevan la franja «Imagen generada con IA · AI-generated» y el menú muestra la etiqueta. `assets/historia`, `assets/menu` | Las capturas del juego muestran esa marca |
| O6 | Declarar el uso de IA en código, datos y audio | Cumple | `scenes/b/docs/ARTE_Y_LICENCIAS.md` y créditos del menú: el código se escribió con asistencia de Claude (Anthropic); logo y fondos con el generador de imágenes de Canva; música y sonidos sintetizados por código (`tools/sintetizar_*.py`) | Debe repetirse en el formulario de entrega |
| O7 | No usar marcas ni logos de la NASA | Cumple, con una salvedad | El juego se llama GAIA y su logo, interfaz y créditos no usan el logo de la NASA ni el «meatball»; los créditos del menú aclaran que GAIA no está afiliado a la NASA ni cuenta con su respaldo. Las fotos y modelos oficiales se muestran con su crédito | **Salvedad:** el modelo 3D oficial del Perseverance (NASA 3D Resources) reproduce el rover tal como voló, con las insignias que lleva el vehículo real. Se muestra como representación fiel del rover de la NASA y con su crédito, no como marca del proyecto. Si el equipo prefiere cero insignias en pantalla, el modo de detalle reducido (ajuste Baja) las elimina porque pinta las piezas con color liso |
| O8 | La IA no puede haber «inventado la idea» | A confirmar por el equipo | La idea de partida (diseñar y operar una misión con masa, energía y enlace limitados) viene del documento de ideas del equipo (`IDEAS PARA JUEGO DE NASA SPACE.pdf`). La IA ayudó a desarrollar y documentar, no a elegir la idea | **El equipo debe poder afirmarlo con sus propias palabras en la entrega**; no lo puedo certificar yo |
| O9 | Código y contenido propio o con licencia compatible | Cumple | Modelos NASA 3D Resources («free and without copyright»); fuentes Inter, Space Grotesk y Oxanium (SIL OFL); resto original. Ver `scenes/b/docs/ARTE_Y_LICENCIAS.md` | Los modelos 3D del equipo de diseño (Arturo Valdivieso) están documentados allí |

La implementación de los depósitos ficticios de bionutrientes y sus pruebas se hizo con asistencia de Codex. La idea de que las criaturas dejen el recurso fue una decisión del equipo.

Codex asistió en la redacción bilingüe y la integración del guion del aterrizaje, el primer enlace y la primera noche, incluidas las dos respuestas de Houston. Tony revisó y autorizó la prueba local de este bloque.

Los diálogos de los nueve nodos de historia usan síntesis local de Microsoft Windows en español y de Piper en inglés. Codex asistió en la mezcla con efecto de walkie-talkie y en la sincronización con las tarjetas y las escenas de decisión.

Codex asistió en la integración de la expedición a la Falla, la estación opcional y sus pruebas. Los diálogos nuevos se sintetizaron en local con las mismas voces y el efecto de walkie-talkie.

## 2. Recomendado por la NASA (recursos oficiales)

| # | Recurso / sugerencia | Estado | Evidencia | Límite |
|---|----------------------|--------|-----------|--------|
| R1 | Los **cuatro segmentos** de una misión (lanzamiento, espacial, terrestre, usuarios) | Cumple | El informe y «Tu misión frente a la real» describen cada segmento con los datos de la partida | — |
| R2 | Trayectoria y tiempo de viaje como decisión de diseño | Cumple (simplificado) | 4 trayectorias con días de crucero y factor de carga (`content/parts.json`); animación orbital del crucero (`scenes/b/launch_cruise.gd`); depende del destino (Marte/Luna) | No se usó **GMAT** ni **Mission Viz**: las trayectorias son un modelo simple y se declara así |
| R3 | Restricciones reales: masa, presupuesto, energía, comunicaciones | Cumple | `sim/` (energía por día y noche, ventanas de relé, memoria, presupuesto) y pruebas GUT (530) | La escala de costos y masas es reducida para jugar en minutos; el juego lo avisa en pantalla |
| R4 | Roles de equipo (como en un diseño real) | Cumple | Go/No-Go con 4 roles y 1–4 jugadores (`scenes/b/go_no_go.gd`); partida en red de hasta 4 dispositivos, cada uno con su rol y a la vez (`scenes/net/`, `docs/MULTIJUGADOR.md`) | La red se probó con procesos en una misma máquina; **no** con otras computadoras, por internet ni desde el navegador (ver `docs/MULTIJUGADOR.md`) |
| R5 | Eventos inesperados como en misiones reales | Cumple | 9 imprevistos con hecho real y fuente (`content/imprevistos.json`), por destino | — |
| R6 | Concept Maturity Levels (CML) y Mission Design Laboratory | No usado | — | Mencionados en el PDF como inspiración; no hay un CML explícito en el juego |
| R7 | Juego de telescopio / CubeSat 101 / reto VR 2023 / juegos de la CSA | No usado | — | Se revisaron como referencia, no se incorporaron |

## 3. Propuesta nuestra

| # | Propuesta | Estado | Evidencia |
|---|-----------|--------|-----------|
| P1 | Dos destinos: Marte (Jezero, con historia) y la Luna (polo sur, sin historia ni combate) | Hecho | `content/destinos.json`, `content/*_luna.json` |
| P2 | Dificultades y récords locales con código de diseño para comparar | Hecho | `scenes/menu/registro.gd`, `scenes/menu/game_session.gd` |
| P3 | Visor 3D con modelos oficiales (Perseverance, Ingenuity, módulo lunar Apolo, Saturn V) | Hecho (solo escritorio) | `scenes/b/visor_3d.gd`; los modelos **no** van en la versión web para no engordarla |
| P4 | Versión de escritorio como versión principal (gráficos Forward+) y web como versión de prueba rápida | Hecho | `export_presets.cfg`, `project.godot`; ver `docs/PLATAFORMA.md` |
| P5 | Medidor de rendimiento reproducible | Hecho | `scenes/a/medidor.gd`, `docs/mediciones/` |
| P6 | Escala única 1:1 (1 unidad = 1 m, casilla de 4 m): el rover es el Perseverance real a 3 m y los edificios se ajustaron a su altura | Hecho | `scenes/b/escala.gd`, `tests/test_escala.gd`, `docs/ESCALAS.md` |
| P7 | Lanzamiento cinematográfico con la fotografía oficial del Atlas V (Marte) o del Saturn V (Luna), movimiento de cámara y contador T+ | Hecho | `scenes/b/launch_cruise.gd`, `assets/nasa/lanzamiento.jpg`, `assets/nasa/luna_lanzamiento.jpg` |
| P8 | Detalle reducido del rover para el ajuste Baja (≈ 52 superficies en lugar de 99) | Hecho; ganancia en GPU real sin medir | `scenes/b/rover_nasa.gd`, `tests/test_escala.gd` |
| P9 | Tipografía mínima de 13 px en toda la interfaz | Hecho | `scenes/b/ui_style.gd` (`FONT_MIN`) |

## 4. Criterios de jurado (referencia propia)

| Criterio | Cómo lo atendemos | Honestidad |
|----------|-------------------|------------|
| Impacto | Enseña que diseñar una misión es negociar masa, energía, enlace y tiempo | Sin pruebas con usuarios reales todavía |
| Creatividad | Mismo diseño en dos mundos; imprevistos con decisión; comparación con la misión real | — |
| Validez | Cifras con fuente; escala reducida declarada; pruebas automáticas | Las trayectorias no vienen de GMAT |
| Relevancia | Datos, fotos y modelos de la NASA son parte central de la comparación | — |
| Presentación | PDF de sustentación y guion | Falta el video/diapositivas finales |

## 5. Lo que NO está verificado

- Rendimiento en una GPU real: todas las mediciones del repositorio se hicieron en un contenedor **sin GPU** (software); ver `docs/PLATAFORMA.md`. El `.bat` de medición existe para que el equipo lo corra en su PC.
- El costo del Perseverance 1:1 en una GPU real: en el contenedor (software) las llamadas de dibujo por cuadro pasaron de 299 a ≈ 520 en Alta; con una tarjeta gráfica ese número es bajo, pero **no se midió**. Ver `docs/PLATAFORMA.md`.
- Forward+ no se probó en una GPU real: en el contenedor se ejecutó con Vulkan por software.
- El inglés del juego no pasó por revisión de un hablante nativo.


## Modelos 3D y voces: lo que hay que declarar (15 nov 2026)

- **Modelo con licencia que exige crédito:** el Saturn V (`cohete_super.glb`) es «Cohete» de albertomarun (Sketchfab, CC BY 4.0). Va en los créditos del juego y debe ir en la entrega.
- **Modelos hechos con IA:** los cohetes ligero, medio y pesado los generó Evelyn con un script de Python proporcionado por Claude. Declararlo con el resto del uso de IA.
- **Modelos de terceros con CC0:** Kenney «Space Kit» y Kay Lousberg «Space Base Bits» (no exigen crédito, pero se acreditan).
- **Voces en español:** síntesis de voz de Windows (Microsoft Raúl y Pablo) y Piper; no tienen una página pública que enlazar, así que se mencionan **en la declaración de uso de IA**, no como fuente.
- Origen de `hangar_gaia.glb` y de los cohetes: generados por script (ver `scenes/b/docs/ARTE_Y_LICENCIAS.md`, final). Los cristales son diseños hechos por el equipo (confirmado por Kevin el 15 nov); sin licencias de terceros.
