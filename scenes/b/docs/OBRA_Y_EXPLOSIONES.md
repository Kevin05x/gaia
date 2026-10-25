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
