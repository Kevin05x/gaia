---
name: gaia-godot
description: "Cómo trabajar en GAIA, el juego de Godot del equipo Full Galácticos para el NASA Space Apps Challenge. Úsala siempre que toques este repositorio, ya sea el taller de diseño de misión, la plataforma de lanzamiento, los cohetes, los instrumentos, los textos ES/EN, los modelos .glb, los datos de la NASA o las pruebas con GUT. Contiene trampas del proyecto que destruyen trabajo si no se conocen (el script de traducciones borra cientos de claves; importar reescribe 37 texturas de otra rama) y los comandos exactos para compilar, probar y ver la interfaz. Léela antes de editar nada, aunque el cambio parezca de una línea."
---

# GAIA · trabajar en este repositorio

Juego 3D de diseño y operación de misiones espaciales (Godot 4.7.2, GDScript, sin .NET). Dos destinos: Marte (cráter Jezero) y la Luna (polo sur).

## Antes de tocar nada

1. **Lee `CLAUDE.md`** en la raíz. Manda sobre esta skill: tiene las decisiones vigentes del equipo y cambia a menudo.
2. **Comprueba en qué rama estás.** El trabajo se reparte por ramas y pisar la de otro equipo genera conflictos en archivos grandes.
3. **Actualiza**: `git fetch origin && git merge origin/develop`. El repo se mueve rápido durante el hackathon; trabajar sobre una copia vieja ha causado ya una reescritura de datos que casi borra trabajo bueno.

## Arquitectura: tres capas que no se mezclan

```
content/*.json   →   sim/*.gd        →   scenes/
(datos)              (simulación)        (lo que se ve)
```

- **`content/`**: reglas, balance, mapa, piezas, historia, hitos. *Cambiar un número no debe requerir tocar código.*
- **`sim/`**: simulación pura, **sin nodos y sin dibujar**. Es lo que prueba GUT.
- **`scenes/`**: la vista. Pide cosas a la simulación con **órdenes** (`design_add`, `design_remove`, `design_validate`, `design_start`…) y muestra lo que llega en el **snapshot**. **Nunca** modifica el estado de la simulación ni calcula costos, masas o validez.

Si te descubres sumando masas o comparando presupuestos dentro de `scenes/`, estás rompiendo la arquitectura: ese número ya viene en `snapshot["workshop"]["totals"]`.

El contrato completo vive en `scenes/b/docs/INTEGRACION_A.md`.

## Trampas que cuestan horas

Estas no se deducen leyendo el código. Cada una ya mordió una vez.

### `scenes/b/tools/sync_i18n.py` destruye traducciones

El script regenera `catalog.gd` desde `strings_ui.csv`, pero **el CSV tiene bastantes menos claves que el catálogo** (el 14 nov: 381 frente a 605). Correrlo borra los **224** textos que solo viven en `catalog.gd` y medio juego se queda sin palabras.

**No lo ejecutes.** Para añadir texto, inserta a mano en los dos sitios (ver abajo).

Si dudas de la diferencia hoy, cuéntala antes de hacer nada:

```python
import csv, json
rows = list(csv.DictReader(open("scenes/b/i18n/strings_ui.csv", encoding="utf-8", newline="")))
t = open("scenes/b/i18n/catalog.gd", encoding="utf-8").read()
d = json.loads(t.split("const TABLES = ", 1)[1].rsplit("\n", 1)[0].strip())
print(len(rows), "en el CSV |", len(d["es"]), "en catalog.gd")
```

Mientras el segundo número sea mayor, el script sigue siendo destructivo.

### `--import` reescribe 37 texturas que no son tuyas

Al importar, Godot convierte las texturas de los modelos NASA a compresión VRAM (`compress/mode` 0 → 2). Son archivos de otra rama y ensucian el PR, además de falsear las mediciones de rendimiento de quien esté midiendo.

Después de importar, revísalo y devuélvelo:

```bash
git status --short            # ¿aparecen assets/nasa/modelos/*.import?
git checkout -- assets/nasa/modelos/
```

### `MissionDesign` ya trae una trayectoria puesta

`_init()` llama a `elegir_trayectoria_por_defecto()` y deja la de Hohmann elegida. Si en una prueba añades otra trayectoria sin quitar la anterior, salta `ABOVE_MAX:trayectoria` y el fallo parece de balance cuando es de montaje.

La trayectoria **se cambia, no se añade**: quita la que hay antes de poner la nueva.

### Las pruebas de vista necesitan las traducciones registradas

Las tarjetas formatean con `tr("CLAVE") % valor`. Sin catálogo cargado, `tr()` devuelve la clave, no hay `%d` y el motor lanza *"not all arguments converted"*. El fallo se ve como "Unexpected Errors", no como una aserción rota.

Copia el `before_all()` de `tests/test_ui_rediseno.gd` en cualquier prueba que instancie una vista.

### `rm` con variable de shell

`rm -f "$DIR"/*.png` se bloquea por seguridad (si `$DIR` está vacía apunta a la raíz). Escribe `rm -f "${DIR:?}"/*.png`.

## Comandos

Godot no suele estar en el PATH. En las máquinas del equipo está en el Escritorio:

```bash
GODOT="/c/Users/<usuario>/Desktop/Godot_v4.7.2-stable_win64.exe"
```

```bash
# Importar (tras añadir class_name o assets nuevos). Revisa después el git status.
"$GODOT" --headless --path . --import

# Todas las pruebas. Deben pasar TODAS antes de abrir un PR.
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests,res://scenes/b/tests -ginclude_subdirs -gexit

# Una sola prueba
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -gtest=res://tests/test_cohetes.gd -gexit
```

Para leer el resultado sin ahogarte en salida: `| sed -n "/Run Summary/,\$p"`.

## Ver la interfaz sin abrir el juego

`--headless` no dibuja, así que no sirve para revisar pantallas. Hay una herramienta que las fotografía:

```bash
"$GODOT" --rendering-driver opengl3 --path . -s tools/capturar_taller.gd -- <carpeta-de-salida>
```

Guarda PNG de la plataforma de lanzamiento y del hangar. **Úsala siempre que muevas algo de la interfaz**: mover un panel ha dejado texto solapado por detrás de otro y etiquetas recortadas, y eso no lo detecta ninguna prueba. Mira la imagen antes de dar un cambio visual por bueno.

Para probar otro caso, añade un bloque a esa herramienta; es un `SceneTree` corriente.

Ojo con las esperas: ahí los cuadros vuelan y el reloj de la pantalla va en segundos de verdad, así
que «esperar 500 cuadros» fotografiaba el cohete a medio montar y la captura de «listo» mentía. La
herramienta adelanta el reloj de la pantalla (`_avanzar`) en vez de contar cuadros.

## Añadir o cambiar un texto

Todo texto va en **español e inglés**, en **dos archivos**:

1. `scenes/b/i18n/strings_ui.csv` — añade la fila `CLAVE,español,English`. Entrecomilla el campo si lleva comas.
2. `scenes/b/i18n/catalog.gd` — inserta la clave **a mano** en el bloque `"es"` y en el `"en"`.

Recuerda: **no corras `sync_i18n.py`**. Al editar `catalog.gd` con un script, conserva los finales de línea del archivo o el diff se vuelve de miles de líneas.

Comprueba que quedó bien:

```python
import json
t = open("scenes/b/i18n/catalog.gd", encoding="utf-8").read()
d = json.loads(t.split("const TABLES = ", 1)[1].rsplit("\n", 1)[0].strip())
print(len(d["es"]), len(d["en"]))   # deben coincidir y no bajar
```

Hay una prueba que exige que cada `nombre_clave` de `content/parts.json` tenga texto en `catalog.gd`, así que una pieza nueva sin traducir rompe la suite.

## Datos: nada inventado

Regla del equipo, y pesa en la evaluación del reto:

- Toda cifra o imagen de la NASA va con su fuente en **`docs/DATOS_NASA.md`** (dato, fuente, URL).
- Lo que sea valor de juego se marca como tal. En `content/parts.json` el campo `_fuentes` explica qué es real y qué está a escala.
- Cada pieza lleva `ref_clave` → un texto `REF_*` que el jugador ve, con el patrón: *qué hace en el juego* + *«Dato real: …(NASA/JPL)»*.
- Las imágenes generadas con IA llevan la marca visible **«Imagen generada con IA · AI-generated»** (clave `AI_MARK`) y se anotan en `scenes/b/docs/ARTE_Y_LICENCIAS.md`.
- No usar marcas ni logos de la NASA como identidad del proyecto.

No afirmes que algo se midió o se probó si no se hizo.

## Modelos .glb del equipo de arte

El nombre del archivo **es el id de la pieza**: `assets/modelos/<id>.glb`. Así entra sin tocar código.

Contrato (`scenes/b/docs/ARTE_Y_LICENCIAS.md`): escala real en metros, base apoyada en `y = 0`, subir también `.import` y `.uid`, los `.glb` van por **Git LFS**, y anotar autoría y licencia.

**Los modelos no siempre llegan así.** Del Atlas V 541 y el Saturno V, uno vino de pie y en metros y el otro tumbado sobre Z y en otras unidades. La norma del equipo es **no tocar el archivo de arte**: `scenes/b/launch_pad.gd` lo normaliza al cargarlo (lo endereza si viene tumbado, lo centra, lo apoya en el suelo).

Cuando el modelo representa un lanzador real, su altura real va en `content/parts.json` como `alto_real_m` y el modelo se escala a ella. Así se respeta la escala **1:1** del proyecto (1 unidad = 1 m, casilla = 4 m, `docs/ESCALAS.md`), en vez de adivinar las unidades del `.glb`.

Si falta el modelo, el juego lo dibuja por código y sigue funcionando: **se puede entregar de uno en uno sin romper nada**. Mantén esa propiedad.

### Un modelo con esqueleto no se mide ni se corrige como los demás

Los `.glb` del equipo llegan con escalas raras en sus nodos (0,6 × 0,4 × 0,6 y parecidas).
`launch_pad.gd` las iguala para que el cohete no salga rechoncho al estirarlo a su altura real.

**Con una malla con piel (esqueleto) hay que hacer justo lo contrario: no tocar esa escala.** En
glTF, la escala de los nodos de encima se cancela contra las poses de enlace, así que el modelo ya
se dibuja sin deformar; cambiarla no lo endereza, lo rompe. Y por lo mismo, medirlo con la cuenta
de siempre (ir multiplicando las transformaciones de padre a hijo) da casi la mitad de alto: hay
que medirlo con la transformación de la raíz del modelo.

Al Titan IIIE le pasaron las dos cosas: medido mal salía a la mitad, y «arreglado» a mano crecía un
50 % y se salía por arriba de la pantalla. Ninguna prueba de las de antes lo habría contado: se ve
mirando una captura. `tests/test_cohetes.gd` lo fija ahora cohete por cohete.

Si el `.glb` trae una animación (el equipo las llama «Armado»), la plataforma la reproduce en vez
del montaje por grúas y la lleva al ritmo del propio archivo. **Una animación nueva entra sin tocar
código**, igual que el modelo.

Para inspeccionar un `.glb` sin abrir Godot, su cabecera es JSON: lee los 12 bytes de cabecera, luego el trozo JSON, y mira `accessors[].min/max` de los `POSITION`. Ojo: eso da unidades del modelo, **sin** la escala de los nodos, así que no coincide con lo que mide Godot.

## Git

- Ramas de trabajo salen de `develop`. **Nunca subir directo a `main` ni a `develop`**: todo por Pull Request, y el PR a `main` lo abre quien coordina, al final.
- Unir con **merge commit**, no squash.
- Prefijos de commit: `feat`, `fix`, `test`, `data`, `art`, `docs`, `perf`, `chore`.
- Usar la identidad Git de cada persona. **No reescribir la autoría de commits ya publicados.**
- No editar `docs/REPARTO_FINAL.md` desde una rama de trabajo: lo tocan las tres y choca.
- Si vas a tocar un archivo que trabaja otra rama (`historia.json`, por ejemplo), avisa antes.

## Cómo se mueve el taller

Útil para orientarse:

- La **elección del cohete** no está en el hangar: ocurre antes, en la plataforma de lanzamiento de la Tierra (`scenes/b/launch_pad.gd`). El hangar (`scenes/b/workshop.gd`) monta lo que va dentro del cohete ya elegido.
- Se reparten la fase `workshop` mirando el snapshot: **sin cohete elegido manda la plataforma; con cohete, el hangar.** No hay fase nueva ni cambio en la simulación.
- Desde el hangar se vuelve con el botón «‹ Cambiar de cohete», que emite `design_remove` del cohete.
- El catálogo de piezas es una **barra lateral** a la izquierda, una fila por pieza.

## Antes de abrir el PR

1. Todas las pruebas pasan.
2. `git status` limpio de ruido: sin `.import` de texturas ajenas, sin archivos de depuración.
3. Texto nuevo en ES **y** EN, en los dos archivos.
4. Cifra nueva con fuente en `DATOS_NASA.md`, o marcada como valor de juego.
5. Si cambiaste algo visual, miraste una captura.
6. PR contra `develop`, nunca contra `main`.
