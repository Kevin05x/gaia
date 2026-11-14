# Reparto final: qué falta para terminar GAIA

Equipo Full Galácticos · NASA Space Apps Challenge 2026 · Sábado 14 de noviembre
Entrega: domingo 15 de noviembre, 23:59 (Cajamarca). Meta interna: entregar con 2 h de margen.

Reparto acordado el 14 de noviembre. No edite nadie este archivo dentro de las ramas de trabajo (lo tocarían las tres y habría conflictos): los cambios al reparto se hacen en `develop`. La versión con requisitos del reto y guía de comandos está en `docs/GAIA_Reparto_de_ramas.pdf`.

## Estado de partida

- `develop` ya contiene todo lo de `a/sustentacion-nasa` (PR #50): escala 1:1, Perseverance e Ingenuity reales, lanzamiento con fotos de la NASA, tipografía mínima de 13 px, mediciones antes/después, documentación y PDF.
- 473 pruebas automáticas pasan.
- Pendiente: historia nueva, quitar monstruos, telescopio, más cohetes, paso de los días.
- Aviso: las reglas de Space Apps dicen que no se puede empezar a trabajar en el reto antes del hackathon, y este repositorio tiene commits desde el 22 de octubre. Consultar al organizador local y la Guía de entrega.

## Reglas de trabajo

1. Cada rama sale de `develop` y vuelve a `develop` con un pull request (nunca directo a `main`).
2. Antes de abrir el PR: ejecutar las pruebas y que pasen todas.
   ```powershell
   godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests,res://scenes/b/tests -ginclude_subdirs -gexit
   ```
3. Si añades una `class_name` nueva, ejecuta antes `godot --headless --path . --import`.
4. Merge con **Merge commit** (no squash), para conservar quién hizo qué.
5. El PR hacia `main` lo abre Kevin, al final y solo cuando `develop` esté estable.
6. Todo uso de IA se declara en `docs/CUMPLIMIENTO.md`; si una rama usó IA para escribir código, se anota ahí en una línea.

## Rama 1 · `a/historia-sin-monstruos`

**Equipo:** Scarlett y Tony.
**Por qué una sola rama:** la historia y los monstruos viven en los mismos archivos; separarlas causaría conflictos.

### Objetivo
Que Marte tenga la historia nueva de Amner y **sin monstruos**, con la partida jugable de principio a fin.

### Archivos principales
- `content/historia.json` (hoy 9 nodos, 4 finales y personajes: Houston, Rocky, Perseverance).
- `content/combate.json` (3 tipos de enemigos y 5 oleadas: ola_1, ola_2, ola_3, ola_coloso, ola_final).
- `content/destinos.json` (cada destino declara si usa `historia` y `combate`).
- `content/hitos.json`, `content/tutorial.json` (pueden mencionar defensa o enemigos).
- `sim/systems/combat_system.gd`, `scenes/b/combat_view.gd` (solo se desconectan; no hace falta borrar el código).
- Pruebas en `tests/` y `scenes/b/tests/` que dependan del combate.

### Tareas
- [ ] Se entrega la historia nueva (rama, archivo o documento) y se decide qué nodos reemplaza.
- [ ] Fusionar la historia nueva en `content/historia.json` manteniendo el formato (nodos, decisiones, finales, medidor ético).
- [ ] Quitar el combate de Marte en `content/destinos.json`. La Luna ya funciona sin combate, así que el camino existe.
- [ ] Revisar `historia.json`, `hitos.json` y `tutorial.json`: quitar o reescribir todo texto que hable de arañas, mordedores, coloso, oleadas, muros o defensa de la base.
- [ ] Revisar que la construcción (muros, torretas) no quede como un sistema sin sentido; si ya no aporta, ocultarla del menú de construcción de Marte.
- [ ] Dar un nuevo conflicto a la historia en lugar de los monstruos (por ejemplo, el imprevisto, la tormenta, la decisión ética), para que siga habiendo tensión.
- [ ] Actualizar o eliminar las pruebas que esperaban combate en Marte; añadir una prueba de que Marte corre sin combate.
- [ ] Jugar una partida completa de Marte: briefing, taller, lanzamiento, 6 soles y los 4 finales.
- [ ] Actualizar `docs/DATOS_NASA.md` o el doc de historia si cambian las afirmaciones.

### Terminado cuando
- No aparece ningún monstruo ni texto de combate en Marte.
- La historia nueva se juega completa y llega a los 4 finales.
- Las 473 pruebas (o las que queden) pasan.

## Rama 2 · `b/cohetes-telescopio`

**Equipo:** Amner y Evelyn (Evelyn, modelos 3D; Amner, datos y taller).

### Objetivo
Ampliar el taller con más cohetes y añadir el telescopio, según lo que el equipo decida que es.

### Decisión pendiente antes de empezar
¿Qué es el telescopio? Opciones:
1. **Instrumento del rover**: un instrumento más en el catálogo, con masa, costo, potencia y datos que aporta.
2. **Telescopio espacial como misión** (como destino o como parte de la misión).
3. **Referencia al "juego del telescopio" del reto**: solo se revisó y no se integró (ver `docs/CUMPLIMIENTO.md`, fila R7). Si se integra, hay que actualizar esa fila.

### Archivos principales
- `content/parts.json` (hoy solo `cohete_ligero` 600 kg / 150 M$ y `cohete_pesado` 1.200 kg / 300 M$).
- `content/rules.json` y `content/rules_luna.json` (qué piezas se permiten y su equilibrio).
- `scenes/b/workshop.gd` (tarjetas del catálogo, tamaño 150×160).
- `content/economia.json` y `content/balance.json` si el telescopio afecta energía o datos.
- Textos en `scenes/b/i18n/` o los CSV de cadenas del juego.
- `docs/DATOS_NASA.md` y `scenes/b/docs/ARTE_Y_LICENCIAS.md` para cualquier dato o modelo nuevo.

### Tareas
- [ ] Decidir qué es el telescopio (ver arriba) y qué datos reales de la NASA lo respaldan.
- [ ] Añadir cohetes (por ejemplo uno mediano, uno de lanzamiento comercial, o los de los datos reales de la NASA) con capacidad y costo coherentes con la realidad.
- [ ] Rebalancear: presupuesto de 700 M$ y masa; comprobar que existan al menos 2 o 3 diseños ganadores distintos.
- [ ] Añadir el telescopio al taller con ficha de masa, costo, potencia y qué aporta.
- [ ] Si hace falta modelo 3D, que lo entreguen Arturo y Evelyn (formato `.glb`, con escala real en metros) y registrar autoría y licencia.
- [ ] Mostrar los cohetes nuevos en el lanzamiento (foto real de la NASA o modelo, con crédito).
- [ ] Pruebas de datos nuevas (catálogo válido, presupuesto, masa) y que las existentes sigan pasando.
- [ ] Revisar que las tarjetas no se recorten con tipografía mínima de 13 px.

### Terminado cuando
- El catálogo del taller tiene los cohetes nuevos y el telescopio.
- Se puede ganar con distintos diseños y el equilibrio se ha probado.
- Todo lo nuevo tiene dato real o está marcado como de juego.

## Rama 3 · `b/dias-y-realismo`

**Equipo:** Kevin y Arturo (Arturo, arte y aspecto; Kevin, código y mediciones).

### Objetivo
Que el paso de los días se note más y que el juego se vea lo más realista posible sin perder rendimiento.

### Archivos principales
- `scenes/b/sky_light.gd` (luz y cielo según la hora).
- `scenes/b/cielo_marte.gd`, `scenes/b/horizonte.gd`.
- `scenes/b/hud.gd`, `scenes/b/hud_avisos.gd` (reloj "Sol N · hh:mm" y avisos).
- `scenes/b/graficos.gd`, `scenes/b/calidad_dinamica.gd` (ajustes de calidad).
- `content/balance.json` (sol = 300 s, inicio 8:00, amanecer 6:00, atardecer 18:00).

### Tareas
- [ ] Sol y sombras que se mueven según la hora del juego.
- [ ] Colores de amanecer y atardecer.
- [ ] Estrellas de noche.
- [ ] Aviso en pantalla al cambiar de día ("Amanece · Sol 2").
- [ ] HUD con "Sol N de 6".
- [ ] Luces encendidas en la base de noche.
- [ ] Corregir el comentario viejo en `sky_light.gd` ("casillas de 2 m": ahora son de 4 m).
- [ ] Mejorar el realismo del terreno y los edificios donde el rendimiento lo permita; respetar los ajustes Alta, Media y Baja.
- [ ] Medir rendimiento antes y después con `-- --medir --preset=alta|baja|media` y guardar el resultado en `docs/mediciones/`.
- [ ] Revisar que la versión web (que usa el rover de bloques) no se rompa.

### Terminado cuando
- El paso del día y la noche se nota a simple vista.
- El rendimiento no empeora de forma medible en el ajuste Baja.
- Las pruebas pasan.

## Tareas que no son de código (todos)

- [ ] **Video de máximo 30 segundos en inglés, o máximo 7 diapositivas** (formato de entrega del reto).
- [ ] **Texto de la entrega en inglés**: descripción, cómo se usó la IA, datos de la NASA usados.
- [ ] **Declaración honesta de IA** en el texto y en `docs/CUMPLIMIENTO.md`: la idea y el diseño son del equipo, y la IA escribió gran parte del código bajo supervisión.
- [ ] Arturo y Evelyn: dos o tres frases cada uno sobre cómo hicieron los modelos 3D (herramientas, tiempo).
- [ ] Completar en el documento de guion los datos pendientes: títulos de los libros usados.
- [ ] Probar el paquete de Windows con `Medir_rendimiento.bat` en una máquina real y guardar los números.
- [ ] Ensayo completo de la presentación de 3 minutos.
- [ ] PR final de `develop` a `main` (lo abre Kevin) y publicación (itch.io o GitHub Pages si se usa).

## Orden y calendario sugerido

| Cuándo | Qué |
| --- | --- |
| Sáb 14, mañana | Decisiones: qué es el telescopio, dónde está la historia de Amner |
| Sáb 14, tarde | Rama 1 (historia sin monstruos) y arranque de rama 3 |
| Sáb 14, noche | PR de la rama 1 a `develop`; avance de la rama 2 |
| Dom 15, mañana | Ramas 2 y 3 a `develop`; pruebas completas |
| Dom 15, mediodía | Congelar el juego (solo errores graves) |
| Dom 15, tarde | Video, texto en inglés, ensayo, PR a `main` |
| Dom 15, 21:59 | Entrega lista (2 h de margen) |

Si falta tiempo, se recorta en este orden: primero la rama 2 (telescopio y cohetes extra), luego el realismo de la rama 3. La rama 1 y las tareas de entrega no se recortan.
