# Reparto final: qué falta para terminar GAIA

Equipo Full Galácticos · NASA Space Apps Challenge 2026 · Sábado 14 de noviembre
Entrega: domingo 15 de noviembre, 23:59 (Cajamarca). Meta interna: entregar con 2 h de margen.

Reparto acordado el 14 de noviembre. No edite nadie este archivo dentro de las ramas de trabajo (lo tocarían las tres y habría conflictos): los cambios al reparto se hacen en `develop`. La versión con requisitos del reto y guía de comandos está en `docs/GAIA_Reparto_de_ramas.pdf`.

## Estado de partida

- `develop` ya contiene todo lo de `a/sustentacion-nasa` (PR #50): escala 1:1, Perseverance e Ingenuity reales, lanzamiento con fotos de la NASA, tipografía mínima de 13 px, mediciones antes/después, documentación y PDF.
- 473 pruebas automáticas pasan.
- Pendiente: historia nueva y bionutrientes, telescopio, más cohetes, energía de la Luna, paso de los días.
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

## Rama 1 · `a/historia-sin-monstruos` (el nombre quedó viejo)

**Equipo:** Scarlett y Tony.
**Decisión del 14 de noviembre:** los monstruos **se quedan**. Al matarlos dan **bionutrientes**.

### Objetivo
Marte con la historia nueva y con el combate dando un recurso nuevo, los bionutrientes. La partida debe jugarse completa.

### Archivos principales
- `content/historia.json` (hoy 9 nodos, 4 finales; personajes Houston, Rocky, Perseverance).
- `content/combate.json` (3 enemigos: araña, mordedor, coloso; 5 oleadas).
- `content/economia.json` (recursos de Marte; los de la Luna están en `economia_luna.json` y no cambian).
- `sim/systems/combat_system.gd`, `sim/economy.gd`, `sim/systems/build_system.gd`.
- Textos en español e inglés y la barra de recursos del HUD.
- Pruebas en `tests/` y `scenes/b/tests/`.

### Tareas
- [ ] Entregar la historia nueva y fusionarla en `historia.json` con el mismo formato.
- [ ] Definir el recurso `bionutrientes` en `economia.json` (lista de recursos y valor inicial) con sus textos en español e inglés.
- [ ] Hacer que cada enemigo suelte bionutrientes al morir, con cantidad por tipo en `combate.json`.
- [ ] Decidir para qué sirven los bionutrientes y equilibrarlo (por ejemplo mejoras de la base o de la nave).
- [ ] Mostrarlos en el HUD de recursos y en el informe.
- [ ] Que la historia explique de dónde salen los bionutrientes.
- [ ] Revisar el equilibrio de las oleadas con las dificultades (`factor_enemigos`).
- [ ] Pruebas: matar un enemigo suma bionutrientes; la Luna no cambia.
- [ ] Jugar una partida completa de Marte con los 4 finales.

### Terminado cuando
- Matar monstruos da bionutrientes y se ven en pantalla.
- La historia nueva se juega completa.
- Las pruebas pasan.

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
Rehacer la energía de la Luna, hacer que el paso de los días se note y mejorar el realismo, sin perder rendimiento.

### Lo que ya existe (no rehacer)
El sol ya cambia de elevación y de azimut con la hora (las sombras se mueven), hay colores de amanecer y atardecer, estrellas de noche, luz de luna y un aviso de la noche. Lo que falta es que se note más y completar los avisos.

### A. Energía de la Luna (Kevin)
Hoy la Luna usa la misma curva solar que Marte (`sim/systems/energy_system.gd`, `content/balance_luna.json`). Según la NASA, en el polo sur el Sol se queda a pocos grados sobre el horizonte, las crestas reciben más del 50 % del tiempo luz y las zonas de sombra permanente, donde está el hielo, no reciben nada.
- [ ] Añadir un factor de irradiancia polar para la Luna (por ejemplo `energia.factor_solar_max` en `balance_luna.json`; en Marte vale 1.0 y no cambia nada).
- [ ] Marcar zonas de sombra permanente en `content/mapa_luna.json` (las zonas actuales son orilla, falla y núcleo) y que el panel solar rinda 0 mientras el rover o un edificio esté dentro.
- [ ] Poner el hielo y los objetivos enterrados en esas zonas, para que haya que elegir entre ir con RTG o volver a cargar.
- [ ] Que `EnergySystem` use la casilla del rover y las zonas de sombra para calcular la generación.
- [ ] Ajustar la calefacción de noche y comprobar que se puede ganar tanto con paneles como con RTG.
- [ ] Mostrar en el HUD y en el taller de la Luna un aviso claro: "en sombra", "sol bajo", "el RTG no depende del sol".
- [ ] Añadir un dato real de la NASA con su fuente en `content/nasa/mision_real_luna.json` y en `docs/DATOS_NASA.md`.
- [ ] Pruebas nuevas en `tests/test_energy_system.gd` y `tests/test_imprevistos_y_luna.gd`, y comprobar que Marte sigue igual.

### B. Paso de los días (Kevin)
- [ ] Aviso de amanecer ("Amanece · Sol N"), como el de la noche (`hud.gd`, `hud_avisos.gd`).
- [ ] Reloj con "Sol N de 6", en español e inglés.
- [ ] Más contraste de amanecer y atardecer: horizonte más cálido y sol más visible (`sky_light.gd`, `cielo_marte.gd`).
- [ ] Luces nocturnas en la base: ventanas con brillo y pocas luces reales, limitadas en la web.
- [ ] Corregir el comentario viejo de 2 m en `sky_light.gd` y unificar la tormenta (`rules.json` dice sol 3; el plan, sol 4 a 5).

### C. Arte y realismo (Arturo, con Kevin)
- [ ] Texturas más realistas del suelo y las rocas, con fotos reales de Jezero como referencia (Kevin las conecta al terreno).
- [ ] Mejorar los modelos de los edificios sin cambiar su tamaño real.
- [ ] Ventanas y luces con material emisivo en los modelos, para la noche.
- [ ] Revisar la paleta contra fotos de la NASA.
- [ ] Confirmar el origen y la licencia de las texturas `foco_spacebits` y `taladro_spacebits`, y corregir `ARTE_Y_LICENCIAS.md` con lo que realmente hizo cada persona.

### D. Cierre (Kevin)
- [ ] Medir rendimiento antes y después en Alta, Media y Baja y guardarlo en `docs/mediciones/`.
- [ ] Comprobar que la versión web no se rompe.
- [ ] Todas las pruebas pasan.

### Terminado cuando
- En la Luna el panel solar rinde distinto según la sombra y el RTG tiene sentido.
- El paso del día y de la noche se nota a simple vista.
- El rendimiento no empeora de forma medible en Baja.

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
| Sáb 14, mañana | Decisiones: qué es el telescopio, dónde está la historia nueva |
| Sáb 14, tarde | Rama 1 (historia y bionutrientes) y arranque de rama 3 |
| Sáb 14, noche | PR de la rama 1 a `develop`; avance de la rama 2 |
| Dom 15, mañana | Ramas 2 y 3 a `develop`; pruebas completas |
| Dom 15, mediodía | Congelar el juego (solo errores graves) |
| Dom 15, tarde | Video, texto en inglés, ensayo, PR a `main` |
| Dom 15, 21:59 | Entrega lista (2 h de margen) |

Si falta tiempo, se recorta en este orden: primero la rama 2 (telescopio y cohetes extra), luego el realismo de la rama 3. La rama 1 y las tareas de entrega no se recortan.
