# Mapa grande y zonas (24 oct 2026)

El mapa pasó de 23×23 a **71×71 casillas** (de −35 a 35, 2 m por casilla, 142 m de lado) para que la historia tenga adónde ir. Sigue siendo un solo `content/mapa.json`; la estación (−9, −9), el inicio del rover (0, 0), los 9 objetivos `JZ-01..09` y sus 10 obstáculos se conservaron tal cual, así que lo que A ya probó sigue valiendo.

## Zonas

Cada casilla pertenece a la zona cuyo centro queda más cerca (`MapData.zona_de`). Las zonas viven en el JSON (`"zonas": [{"id", "centro"}]`, opcional: sin ellas no hay zonas):

| id | centro | ambiente |
|---|---|---|
| `orilla` | (−12, −12) | orilla pálida del lago; aquí están la estación y el inicio |
| `falla` | (18, 2) | glaciar partido: suelo gris azulado, hielo enterrado |
| `nucleo` | (10, 26) | núcleo del cráter: ceniza y basalto oscuros |

El snapshot publica `zones` (`[{"id", "center": Vector2i}]`) y `rover_zone` (id de la zona donde está el rover). A puede usar `rover_zone` para disparar escenas de historia al entrar a una zona. El minimapa pinta las zonas y muestra el nombre de la zona del rover (`ZONE_ORILLA`, `ZONE_FALLA`, `ZONE_NUCLEO` en `catalog.gd`).

## Cómo se genera

`python tools/generar_mapa.py > content/mapa.json` (semilla fija: siempre sale igual). Coloca 30 objetivos nuevos repartidos por zona (los enterrados lejos de la base) y unas 200 rocas en grupos de 2 a 6 casillas, y comprueba que todos los objetivos son alcanzables y que ninguna roca encierra zonas. `MapData` repite esa comprobación al cargar con **un solo relleno** desde el inicio del rover (antes era uno por objetivo).

## Cómo escala el terreno

`Terrain` conserva sus proporciones y aleja todo lo que rodea al área jugable `_s` metros (múltiplo de 8, calculado a partir de los límites del mapa: 48 m para 71×71). La malla detallada, las colinas, la cuenca, el lago y las lomas se desplazan juntos; con el mapa chico `_s = 0` y el aspecto es el de antes. `Terrain.lazy = true` (lo hace `mission_view`) retrasa la construcción hasta `configure()`, para construir el mundo una sola vez con el tamaño correcto.

## Rendimiento (lo que se midió)

- **Suelo**: malla indexada partida en trozos de 22 celdas (malla de ±88 m con celdas de 2 m), cada uno se descarta por su cuenta. Los vértices se calculan una vez en vez de seis.
- **Rocas decorativas y obstáculos**: un `MultiMesh` por familia y por trozo (48 m para guijarros y fragmentos; 128 m para las escasas), con distancia de visibilidad en lo numeroso. Las pruebas de distancia al colocar usan una rejilla de 4 m en vez de recorrer todas las rocas.
- **Obstáculos**: antes un nodo por roca; ahora instancias de `MultiMesh`.
- **Minimapa**: la capa fija (zonas, cuadrícula y rocas) es una imagen que solo se rehace al cambiar el mapa. Dibujar 200 rocas como círculos costaba ~450 llamadas de dibujo por cuadro (era lo que más pesaba en el mapa grande).
- `nearest_free_tile` y el cursor usan un diccionario de casillas bloqueadas (antes una búsqueda lineal por casilla).
- Medido en el entorno de pruebas (renderizado por software, sirve solo para comparar): mapa chico 391 llamadas / 96 k triángulos / 982 nodos; mapa grande 466 / 111 k / 1174. Construir el mundo: ~0,35 s en el editor sin ventana. Ruta de 60 casillas: ~5 ms.
