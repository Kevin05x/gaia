# Balance (provisional, 24 oct 2026)

Medido con partidas simuladas (`tests/test_partida_completa.gd`, `tests/test_balance_combate.gd`). Se reajusta tras el enunciado del 28 oct.

## Combate (torretas nivel 1 en una base típica)
| Torretas | Resultado |
|---|---|
| 0 | La primera oleada (sol 2, 20:00) hunde la base |
| 1 | Aguanta oleadas 1–3 y la final; el coloso (sol 5) destruye el rover |
| 2 | Aguanta todas las oleadas |

Una torreta cuesta 40 rocas + 15 olivino: hay que tener 2 antes del sol 5 y 1 antes del sol 2 a las 20:00.

## Economía
- El compañero (`balance.json › acciones.companion`) tiene tope de `usos_por_sol` (4): 40 rocas + 16 olivino por sol por 60 Wh. Mensaje `HELP_USED` al agotarlo.
- Con el envío de datos ya topado (85 % antes del clímax, 100 % después) la memoria llena **no** bloquea analizar para obtener recursos.
- Xenolito para la nave (antena 3 + cápsula + escape ≈ 70): hay 13 puntos enterrados (6 c/u = 78) y la historia regala 35–55; hielo sale de los extractores.
- El clímax puede dispararse por antena 3, 85 % enviado o sol 6 (se evalúan con «o»): ocurre antes de sol 3–4 si se envía rápido y deja más tiempo para construir la nave.

## Pendiente
- Un bot que juegue como una persona para medir la tasa de victoria; hoy solo se garantiza que ganar es posible y que el combate escala.
- Decidir si una nave destruida pierde un módulo.

## Ronda F (31 oct 2026): sin bloqueos de memoria y ciencia más lenta

- **La memoria llena ya no bloquea nada.** La ciencia que no cabe se pierde, pero los recursos se recogen igual. La memoria sube de 45 a 60.
- **Cada objetivo se puede taladrar 4 veces** (`ciencia.extracciones_por_objetivo`) para sacar recursos. La ciencia y los minerales solo cuentan la primera vez. El objetivo se agota tras el análisis y las 4 extracciones.
- **Ciencia más lenta**: espectrómetro 2, taladro 3, enterrado 5 y meteo 1 por sol (antes 5, 10, 14 y 2). Todo el mapa da unos 195 puntos de ciencia, así que la meta de 100 exige explorar casi la mitad. El 85 % antes del clímax llega hacia el sol 4–5 y no en 5 minutos.
- **Almacén**: 300 de cada recurso (antes 150), y cada domo suma 150 (antes 50).

## Ronda G (1 nov 2026): hitos, bodega y barrera

- **Ciencia por hitos** (`content/hitos.json`): 13 hitos que suman 88 datos. Espectrómetro 1, taladro 1, enterrado 2 y meteo 1 por sol. El 100 % llega cerca del final.
- **Bodega del rover**: 90 (`economia.json › bodega_rover`). Al llenarse, el taladro avisa `CARGO_FULL`.
- **Barrera**: un muro cuesta 4 rocas, tiene 320 PV y tarda 2 s (máx. 90). Una compuerta cuesta 12 rocas + 4 olivino y tiene 240 PV (máx. 6). Escudo de 3 PV/s tras 5 s sin golpes. Coste de muro para los monstruos (`MapData.COSTO_MURO`): 12. Con un hueco a menos de unas 12 casillas, los monstruos lo rodean.
- Rocky también repara muros, igual que los demás edificios, si no hay monstruos a menos de 4 casillas de la estación.
