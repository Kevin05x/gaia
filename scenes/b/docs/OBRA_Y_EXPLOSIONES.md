# Obra animada, explosiones y daño a la nave (24 oct 2026)

Pedido de Kevin: que se note cómo se construye, que al destruirse algo explote con restos y que la nave pierda la parte que le golpean.

## Construcción (solo presentación)
- El edificio se «imprime» de abajo hacia arriba: `scenes/b/build_fx.gd` pasa cada malla a un material que recorta lo que está por encima de la altura construida y deja un borde ámbar brillante en el corte (conserva color y textura del modelo).
- Alrededor aparece un andamio de hilos ámbar y encima un cartel con el tiempo que falta («12 s», «1:05») y una barra de avance.
- El snapshot de cada edificio trae `remaining_s` (segundos que faltan; 0 si no está en obra). La nave sigue creciendo módulo a módulo.
- `buildings.gd` emite `building_started`, `building_done` (polvo y campanilla), `building_lost` y `module_lost`.

## Explosiones
- `scenes/b/explosion_fx.gd`: destello, bola de fuego, humo, anillo de choque y restos (10–18 piezas) que caen con gravedad, rebotan y se encogen. Todo reutiliza piezas ya creadas (sin partículas).
- Sonidos nuevos: `explosion`, `obra_inicio`, `obra_fin` (`tools/sintetizar_sonidos.py`).

## Daño a la nave (simulación)
- La vida de la nave es la del módulo que recibe los golpes (`hp_modulo`, 100 en `economia.json`). Al llegar a 0 se destruye el módulo más alto (o el que estaba en obra, y se pierde lo gastado en él) y el módulo que queda recupera su vida.
- Si desaparece el último módulo, la nave se destruye entera (`BUILDING_DESTROYED`). Evento nuevo: `MODULE_LOST:<tipo>:<módulos que quedan>`; aviso `NOTICE_MODULE_LOST`.
- Con la nave a medias o dañada no se gana: la victoria exige los 4 módulos.
- Medido con 2 torretas Nv1 y la nave completa a 5 casillas de la estación: sobrevive a todas las oleadas; con defensa más débil puede perder módulos.

## El rover va a la obra (14 nov 2026 · rama `b/dias-y-realismo`, pedido de Arturo)

Antes, la obra empezaba sola, «a distancia». Ahora es tu rover el que construye. **Es un cambio de reglas:** está en la simulación, no solo en la vista.

- **Simulación** (`content/economia*.json › "obra_con_rover": true`):
  - Al ordenar una obra (`build`, `build_module` o `upgrade`), el rover sale hacia una casilla contigua y la obra espera (`espera_rover`). No avanza hasta que el rover llega; entonces emite `BUILD_STARTED:<tipo>:<id>`.
  - Al terminar, el rover vuelve a donde estaba, o sigue hacia donde iba si estaba en marcha (`ROVER_AUTO_MOVE:vuelta`).
  - Si el jugador le da otra orden (mover, acercarse, parar, descargar o una acción), ya no vuelve solo. La obra ya empezada sigue aunque el rover se vaya.
  - Si el rover está ocupado (por ejemplo, taladrando), va a la obra en cuanto termina (`ROVER_AUTO_MOVE:a_obra`).
  - Si no puede llegar (sin ruta, poca energía o modo seguro), el jugador recibe el aviso `BUILD_ROVER_BLOCKED` y tiene que llevarlo él.
  - Los muros y las compuertas se siguen imprimiendo solos y en paralelo.
  - Pruebas: `tests/test_obra_con_rover.gd`. Las pruebas antiguas de costos y tiempos usan `Economy.para_pruebas()`, que apaga esta regla.
- **Vista:**
  - La obra muestra «Esperando al rover» hasta que el rover llega.
  - Junto a la obra, el rover se gira, extiende el brazo y suelda, con chispas y un destello azulado que parpadea (`actors.gd`, `_soldar`).
  - El runner presenta los caminos de ida y vuelta (`Simulation.ruta_en_curso()`).

### TEMPORAL: recursos ilimitados para probar la construcción

`"pruebas_recursos_ilimitados": 1` en `content/economia.json` y `content/economia_luna.json`: el almacén empieza lleno (300 de cada recurso) y las obras no cobran. **Hay que ponerlo en 0 en los dos archivos antes del PR a `develop`.** Las pruebas no dependen de este valor: usan `Economy.para_pruebas()`.
