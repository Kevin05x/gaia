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
