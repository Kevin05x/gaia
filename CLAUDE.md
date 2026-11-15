# GAIA · contexto del proyecto para Claude

Lee este archivo antes de tocar nada. Resume qué es el proyecto, qué se decidió y las reglas de trabajo. Está en español porque el equipo trabaja en español; la entrega del reto va en inglés.
Última actualización: sábado 14 de noviembre de 2026, noche (Cajamarca), con el trabajo de `b/dias-y-realismo`.

## Qué es

- **GAIA** (nombre provisional): juego 3D de diseño y operación de misiones espaciales para el **NASA Space Apps Challenge 2026**, reto *Space Mission Design Game*. Equipo **Full Galácticos** (sede Cajamarca).
- Bucle: briefing → taller (masa, presupuesto 700 M$, energía, comunicaciones, instrumentos) → revisión Go/No-Go por roles → lanzamiento (foto real) → crucero (203 días a Marte, 3 a la Luna) → aterrizaje con grúa aérea → operaciones sol a sol → informe con causas y comparación con la misión real.
- Dos destinos: **Marte** (cráter Jezero, con historia y combate) y **Luna** (polo sur, sin historia ni combate).
- Meta de la partida: enviar 100 unidades de datos antes de que termine el sol 6. Un sol dura 300 s reales; el día va de 6:00 a 18:00; de noche no hay sol.
- **Entrega: domingo 15 de noviembre, 23:59 (hora local). Meta interna: 2 horas de margen.**

## Equipo y ramas (acordado el 14 de nov)

| Rama | Equipo | Trabajo |
| --- | --- | --- |
| `a/historia-sin-monstruos` | Scarlett y Tony | Historia nueva y bionutrientes: los monstruos se quedan y al matarlos dan bionutrientes (el nombre de la rama quedó viejo) |
| `b/cohetes-telescopio` | Amner y Evelyn | Más cohetes y el telescopio (Evelyn, modelos 3D) |
| `b/dias-y-realismo` | Kevin y Arturo | Energía de la Luna, paso de los días y realismo gráfico (Arturo, arte) |

Kevin (Kevin05x) abre el PR final a `main`. Arturo Valdivieso y Evelyn hicieron los modelos 3D del equipo. El detalle de tareas está en `docs/REPARTO_FINAL.md` y `docs/GAIA_Reparto_de_ramas.pdf`.

## Decisiones tomadas

- Motor: **Godot 4.7.2 Standard, GDScript** (sin .NET). Escritorio con Forward+ como versión principal; web (Compatibility, un hilo) como prueba rápida. Ver `docs/PLATAFORMA.md`.
- **Escala única 1:1**: 1 unidad = 1 m, casilla = 4 m. El rover es el Perseverance real (3 m). Ver `docs/ESCALAS.md`; la protege `tests/test_escala.gd`.
- Reales (NASA): rover Perseverance, helicóptero Ingenuity, módulo lunar Apolo, Saturn V, fotos de lanzamiento, cifras y los 9 imprevistos basados en hechos. **Estilizados** (decisión de diseño): terreno, edificios de la base, monstruos, cielo y polvo. No afirmar lo contrario.
- Tipografía mínima de 13 px en toda la interfaz (`UI.FONT_MIN`).
- El rover de la versión web usa bloques (los modelos 3D no van en web). El ajuste Baja usa el rover de detalle reducido.
- Las imágenes hechas con IA llevan la marca visible «Imagen generada con IA · AI-generated».
- Marte y Luna comparten el mismo taller; cada destino tiene sus propios JSON (`*_luna.json`).
- **Los monstruos NO se quitan** (decisión del 14 nov): al matarlos dan **bionutrientes**, un recurso nuevo que lo implementa el equipo de historia (`a/historia-sin-monstruos`). No borrar el combate. La Luna sigue sin fauna ni combate.
- **Energía de la Luna** (hecho en `b/dias-y-realismo`, commit 064a693; falta llegar a `develop`): en la Luna el panel solar rinde el 70 % (`balance_luna.json`), porque en el polo sur el Sol se queda bajo. Además, `mapa_luna.json` tiene dos zonas de sombra permanente con hielo enterrado, donde el panel y los edificios no generan nada.
- **Estación de 3 × 3 casillas** (cambio de reglas, 14 nov): `estacion_radio: 1` en `content/mapa*.json`; se descarga a 2 casillas. Ver `docs/ESCALAS.md` y `tests/test_estacion_grande.gd`.
- **El rover construye** (cambio de reglas, 14 nov, pedido de Arturo): `"obra_con_rover": true` en `content/economia*.json`.
  - Al ordenar una obra (salvo muros y compuertas), el rover va hasta ella. La obra no avanza hasta que llega; mientras, el rover suelda. Al terminar, el rover vuelve a donde estaba.
  - Detalle en `scenes/b/docs/OBRA_Y_EXPLOSIONES.md`; pruebas en `tests/test_obra_con_rover.gd`.
  - Las pruebas viejas de costos usan `Economy.para_pruebas()`, que apaga esta regla.
- **Arte realista** (`b/dias-y-realismo`, cuatro rondas del 14 nov):
  - Texturas PBR de Marte y la Luna, y cráteres lunares hundidos.
  - Rocas esculpidas, minerales y nido nuevos.
  - Chapa con polvo en todos los edificios (`scenes/b/shaders/edificio.gdshader`).
  - Filtrado anisótropo 16×.
  - Uso de IA y orígenes en `scenes/b/docs/ARTE_Y_LICENCIAS.md`. Los scripts de las texturas están en `assets/texturas/_fuentes/`.

- **Multijugador en red** (rama `b/multijugador`, 15 nov): hasta 4 personas, cada una en su dispositivo y todas a la vez en la misma misión, cada una con su rol. El anfitrión lleva la simulación y valida las órdenes por rol; todo por WebSocket (sala en la misma Wi-Fi, o servidor dedicado / túnel para internet y navegador). Ver `docs/MULTIJUGADOR.md`. `sim/` y `EventBus` no cambiaron.

## Lo que sigue abierto

- Qué es el **telescopio** (instrumento del rover, telescopio espacial como misión, o referencia del reto). Sin decidir.
- Dónde está la **historia nueva** (aún no está en el repositorio).
- Qué hacen los **bionutrientes** (para qué sirven) y cuántos da cada monstruo. Lo decide el equipo de historia.
- `content/rules.json` pone la tormenta de polvo en el sol 3, pero el plan y la historia dicen sol 4–5. Unificar.
- Comentario viejo en `scenes/b/sky_light.gd` ("casillas de 2 m"; ahora 4 m).
- Hay que volver a renderizar las fichas `assets/edificios/*.png` con `tools/renderizar_fichas.gd`: aún muestran los edificios sin la chapa nueva.
- El ancho de la antena no coincide: 3,4 m en `scenes/b/buildings.gd` y 3,8 m en `scenes/b/actors.gd`. Unificar.
- Los minerales se ven como cobre, oro o plata (solo es aspecto visual), pero el recurso se sigue llamando «olivino» en los textos.
- **Aviso de reglas:** Space Apps dice que no se puede empezar a trabajar en el reto antes del hackathon, y este repositorio tiene commits desde el 22 de octubre. El equipo debe consultarlo con el organizador local y la Guía de entrega. No ocultar ni reescribir el historial.
- Entrega pendiente (equipo): video de máximo 30 s con subtítulos en inglés o máximo 7 diapositivas; texto en inglés; declaración de IA; menores de 18 no deben salir con cara ni voz.
- Mediciones en GPU real: solo hay una, en una Intel UHD (`docs/mediciones/v4_arte_intel_uhd_antes_despues.txt`): Alta da unos 20 FPS y Baja 60. La chapa de los edificios y el filtrado anisótropo 16× aún no se han medido. El equipo corre `Medir_rendimiento.bat` en Windows.

## Arquitectura (no romperla)

Tres capas, que se conectan solo por órdenes y snapshots:

1. `content/`: datos en JSON (reglas, balance, mapa, historia, combate, imprevistos, piezas, hitos, tutorial, `nasa/`). Cambiar un número no debe requerir tocar código.
2. `sim/`: simulación pura en código, **sin dibujar nada** (`simulation.gd`, `systems/*`: reloj, energía, comunicaciones, movimiento, resultado, combate, imprevistos...). Es lo que se prueba con GUT.
3. `scenes/`: lo que se ve (`scenes/b/` es el mundo 3D e interfaz; `scenes/a/mission_runner.gd` conecta vista y simulación; `scenes/menu/` el menú). La vista le pide cosas a la simulación y muestra el resultado; **nunca modifica el estado de la simulación directamente**.

- El autoload de red es `scenes/net/red.gd` (`Red`): solo conecta la vista con el anfitrión; la simulación no sabe que existe.
- `autoload/event_bus.gd` es el contrato de señales: cambiarlo solo con PR aprobado por dos personas.
- Cada destino declara en `content/destinos.json` qué datos usa; `historia` y `combate` son opcionales.
- Escribir una cadena de texto nueva implica español **e** inglés (`scenes/b/i18n/`, `i18n/`).

## Comandos

```
godot --headless --path . --import          # tras añadir una class_name o assets nuevos
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests,res://scenes/b/tests -ginclude_subdirs -gexit
godot --path . -- --medir --preset=alta     # medición de rendimiento (alta|media|baja)
```

Las pruebas deben pasar todas (587 en la rama `integracion`, 14 nov) antes de abrir un PR.

## Flujo de Git (reglas)

- `main` = publicado: cada cambio que llega a `main` publica la web en GitHub Pages. `develop` = integración.
- **Nunca subir directo a `main` ni a `develop`.** Todo entra con Pull Request. El PR a `main` lo abre Kevin al final, con `develop` estable.
- Las ramas de trabajo salen de `develop`. Cada día: `git fetch origin && git merge origin/develop`.
- Unir con **Create a merge commit** (no squash), para conservar quién hizo qué.
- Commits con prefijo: `feat`, `fix`, `test`, `data`, `art`, `docs`, `perf`, `chore`.
- Git LFS para `.blend`, `.glb`, `.png`, `.jpg`, `.wav`, `.ogg`. Subir también los `.import` y `.uid`.
- Usar la identidad de Git de la persona (`git config user.name` / `user.email`). **No reescribir la autoría de commits ya publicados ni cambiarlos a nombre de otra persona o de Claude**, aunque GitHub los marque como «Unverified».
- No editar `docs/REPARTO_FINAL.md` dentro de las ramas de trabajo.

## Reglas sobre IA y honestidad (importante para la evaluación)

- El equipo **declara** el uso de IA: la idea, el diseño del juego, las reglas, la seguridad y la supervisión son del equipo; la IA (Claude) escribió gran parte del código, con la arquitectura y las clases base que el equipo creó primero siguiendo un libro de Godot. La declaración está en `docs/CUMPLIMIENTO.md` y `scenes/b/docs/ARTE_Y_LICENCIAS.md`.
- **No ocultar ni borrar el rastro del uso de IA.** Si algo de IA se añade (código, imagen, audio), anotarlo en esos documentos.
- No inventar datos: cada cifra o imagen de la NASA con su fuente en `docs/DATOS_NASA.md`; lo que sea de juego, marcado como tal.
- No usar marcas ni logos de la NASA como identidad del proyecto. El modelo oficial del Perseverance lleva sus insignias; está documentado.
- No afirmar que algo se midió o probó si no se hizo.

## Dónde mirar

- `docs/CUMPLIMIENTO.md`: requisitos del reto, con estado y evidencia.
- `docs/DATOS_NASA.md`, `docs/ESCALAS.md`, `docs/PLATAFORMA.md`, `docs/mediciones/`.
- `scenes/b/docs/`: balance, combate, tutorial, rendimiento, arte y licencias.
- `docs/REPARTO_FINAL.md`: tareas por rama.
