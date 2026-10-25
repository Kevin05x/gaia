# Combate de defensa ligera (bloque C, 24 oct 2026)

El jugador no controla unidades: construye, reparte la energía y decide. Los monstruos salen de los **nidos**, caminan hacia la estación y las **torretas** disparan solas gastando batería. Rocky repara. Todo el balance está en `content/combate.json` y `content/economia.json`.

## Piezas
- `content/combate.json`: enemigos (`arana`, `void_biter`, `coloso`), oleadas, amenaza, reparación, lluvia de meteoritos y `max_activos` (20).
- `sim/combat_data.gd`: carga y validación (`INVALID_JSON`, `MISSING_FIELD:*`, `INVALID_FIELD:*`, `DUPLICATE_WAVE`, `UNKNOWN_ENEMY`...).
- `sim/systems/combat_system.gd`: oleadas, movimiento, ataques, torretas, reparación, amenaza y meteoritos. Determinista (los impactos usan semilla).
- `sim/map_data.gd`: nidos (`mapa.json` → `nidos`, generados por `tools/generar_mapa.py`), campo de flujo (BFS de 8 vecinos, sin cortar esquinas) desde la estación.
- Vista: `scenes/b/combat_view.gd` (monstruos low-poly de una sola malla, nidos, rayos, fogonazos, meteoritos), `scenes/b/hp_bar.gd` (barra de vida en un solo billboard).
- Pruebas: `tests/test_combate.gd` (54).

## Reglas
- **Oleadas** (`oleadas`): `sol` + `hora` de inicio, grupos `{enemigo, cantidad, nido|zona}`. Las oleadas pendientes se lanzan una sola vez (`oleadas_hechas`). Límite de 20 enemigos activos.
- **Enemigos** siguen el campo de flujo; se detienen a atacar el objetivo más cercano a su alcance (edificio, rover o estación). La estación golpeada gasta batería y daña a Rocky; el Void Biter drena batería; el Coloso pega ×1,5 a edificios.
- **Torretas** (`torreta` Nv1, `torreta_2` Nv2 que pide hangar): son edificios con `combate {alcance, dano, cadencia_s, disparo_wh}`. Disparan solas y gastan batería por tiro; no disparan apagadas, en construcción ni en modo seguro.
- **Rocky** repara el edificio más dañado y el rover en la base (`reparacion`): cuesta batería y se esconde si hay un enemigo a menos de `rango_seguro` casillas de la estación.
- **Antena:** al llegar a 0 de vida pierde un nivel en vez de desaparecer. Los demás edificios destruidos se quitan (`EVENTO_EDIFICIO_DESTRUIDO`).
- **Rover:** `rover_hp` baja con ataques y meteoritos; a 0 la misión termina (`CAUSE_ROVER_DESTROYED`).
- **Amenaza** (0–100): el taladro la sube de golpe y transmitir la sube por hora y nivel de antena; decae sola. Cada `por_extra` puntos añade una araña a la próxima oleada (máx. `extra_max`).
- **Meteoritos** (`meteoritos_1`): aviso con aros rojos en el suelo (`aviso_s`), impactos en casillas aleatorias con semilla, daño en radio a edificios y al rover.

## Eventos nuevos de `Simulation.avanzar`
`WAVE_STARTED:<id>`, `WAVE_CLEARED:<id>`, `ENEMY_KILLED:<tipo>`, `ROVER_HIT`, `METEOR_SHOWER:<id>`, `METEOR_IMPACT`, y de edificios `BUILDING_DESTROYED`, `ANTENNA_DAMAGED`.

## Sonido y ayudas de pulido
- Sonidos de una sola vez (`tools/sintetizar_sonidos.py` → `scenes/b/assets/audio/`): `turret`, `bite`, `growl`, `alarm`, `meteor_fall`, `meteor_hit`. `Audio._sonidos_de_combate` los dispara mirando el snapshot (cada efecto de `combat.shots` trae un número de serie `n`, así suena una sola vez; hay 6 voces y, si están ocupadas, se omite el sonido). No suenan en pausa ni al cargar una partida.
- El meteorito baja en diagonal durante el último 40 % de su aviso (`t` cuenta hacia atrás desde `total`).
- Al colocar una torreta, un anillo muestra su alcance (`build_options[*].range`, en casillas).

## Rendimiento (medido, mapa grande con `ola_final` en curso)
~505 llamadas de dibujo y ~87 k triángulos (mapa grande sin combate: ~470 / ~111 k en el informe de B). Reglas que se mantuvieron: un monstruo = una malla unida; rayos, fogonazos y meteoritos en piscina; barra de vida = un `Sprite3D` con texturas en caché; el runner publica el snapshot cada cuadro solo mientras hay combate.

## Ajustar sin tocar código
Cambiar vida, daño, velocidad, tamaño, horarios de oleadas, cantidad de monstruos, alcance y costo de torretas, reparación y meteoritos desde los JSON. Tras el enunciado del 28 oct, el reajuste es sobre todo de datos.
