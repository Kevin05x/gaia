# Multijugador en red (hasta 4 personas, cada una en su dispositivo)

Rama `b/multijugador`; reformado el 15 nov en `c/mejoras-15nov`. Todos juegan **la misma misión a la vez**, en el mismo mapa y con una sola simulación, y **cada jugador conduce su propio rover** (todos con el mismo diseño; el taller es de todo el equipo, con una parte del presupuesto para cada rol). Cada persona lleva un rol
(Dirección, Ingeniería, Ciencia, Comunicaciones) y solo puede dar las órdenes de su rol. El reparto de roles es el mismo del equipo
de una sola pantalla (`content/rules.json › roles_equipo`): con 4 personas, uno por rol; con 2, dos roles cada uno; con 1, todos.

## Un rover por jugador (15 nov)

- La simulación (`sim/`) lleva varios rovers: cada uno tiene su **posición, su acción y su bodega**; la **batería, la memoria de datos, el enlace y la base son del equipo**.
  Los sistemas siguen leyendo `casilla_rover`, `ocupado`…: lo que cambia es qué rover está cargado en esos campos (`MissionState.usar_rover`). Con un solo rover todo es igual que antes.
- El anfitrión ejecuta cada orden con el rover de quien la da (la orden lleva `_rover`, que el anfitrión pone y no el cliente), manda a cada jugador su snapshot con su rover y la lista de los demás (`Simulation.snapshot_de`), y la animación de cada rover solo a su dueño.
- Todos pueden mover su rover. Cada rol conserva lo suyo: Dirección decide la historia y los imprevistos, pausa y lanza; Ingeniería construye (su rover va a la obra); Ciencia analiza, perfora y descarga; Comunicaciones transmite los datos de todos.
- Entrar con la misión en marcha da un rover nuevo junto a la estación; si alguien se va, su rover se va con él. Si se va el líder, manda el siguiente.
- **Límites conocidos:** el combate, la sombra y la historia cuentan con el rover del **líder** (el primero en entrar); los demás rovers no reciben daño ni chocan entre sí; en red no hay tutorial (bloquearía a todo el equipo).
- **Pantalla dividida (varios jugadores en un mismo PC, cada uno con su rover en un cuarto de pantalla): no está hecha.** Cuatro mundos 3D a la vez no caben en una GPU integrada (la misión sola va a ≈29 FPS en una Intel UHD). En un mismo PC se juega por red: el anfitrión abre la sala y los demás se unen a `127.0.0.1` desde otras ventanas.
- La red local usa exactamente el mismo código que internet (el anfitrión de escritorio o el servidor sin pantalla).

### Pruebas

- `tests/test_varios_rovers.gd` y `tests/test_red_rovers.gd` (suite normal, sin sockets).
- **Extremo a extremo, con sockets de verdad:** `GODOT=/ruta/godot bash tools/e2e_red.sh [2|4|tarde] [puerto]` lanza un servidor sin pantalla y clientes sin pantalla.
  Comprueba entrar en la sala, el reparto de roles, que las piezas de otro rol y lo que excede el presupuesto del rol se rechazan, diseño y lanzamiento, un rover por jugador, que cada uno ve a los demás donde están, y que las órdenes de otro rol se rechazan.
  Resultados del 15 nov en el PC de Kevin: **2 jugadores, 4 jugadores y «uno entra tarde»: los tres pasan.** No se probó con personas reales ni en redes distintas.
- **Prueba a mano en un solo PC: con dos ventanas basta.** El PC de Kevin (GPU integrada) no aguanta cuatro mundos 3D abiertos a la vez, así que la comprobación manual se hace con dos ventanas del juego contra la misma sala (una crea la sala y la otra se une). Los casos de tres y cuatro jugadores los cubre `tools/e2e_red.sh 4` con clientes sin pantalla, no a mano.

## Salas del servidor

Un proceso de servidor lleva **una** sala. Para tener varias se levantan varios procesos y Caddy los reparte por la ruta: `wss://sala.gaianasa.tech/1` a `/4` (puertos 9080 a 9083; sin número, la sala 1).
En el lobby de «Unirse» hay cuatro botones «Sala 1» a «Sala 4». Instalación en el servidor: `docs/SERVIDOR.md`, sección «Cuatro salas».
Memoria: reposo medido en 58 MB por sala; con partida en marcha, sin medir.

## Cómo se juega

1. **Quien crea la sala** (versión de escritorio): *Menú › MULTIJUGADOR › Crear sala*. Le aparecen sus direcciones IP.
2. **Los demás**: *MULTIJUGADOR*, escriben la IP (o la dirección `wss://…` del servidor) y pulsan *Entrar*.
3. El **jefe de sala** (el primero en entrar) elige destino y dificultad y pulsa *Empezar misión*. Quien llegue después **también puede entrar con la misión en marcha**: pasa directo a la partida y los roles se reparten de nuevo entre todos (máximo 4).
4. En el taller todos ven el diseño en vivo. **Cada rol tiene su parte del presupuesto** (`content/rules*.json › presupuesto_por_rol`, 15 nov; el rover y la masa siguen siendo uno solo) y solo gasta de la suya; con un solo jugador no hay reparto. Cada rol elige las piezas de su área, y las demás se ven **bloqueadas** con «Le toca a Ingeniería · nombre»: Dirección = cohete y trayectoria; Ingeniería = chasis y energía; Comunicaciones = antena; Ciencia = instrumentos. Con 1, 2, 3 o 4 personas siempre queda alguien a cargo de cada área. Al entrar sale una guía (reabrible con «¿Cómo funciona?») y un panel con tu rol, tus áreas y lo que gastó cada área; las áreas ajenas se ven apagadas y el anfitrión rechaza esas piezas. Cualquiera pulsa *Validar* y se abre el
   **Go / No-Go en todos los dispositivos**: cada persona vota los roles que le tocan; Dirección lanza cuando todos dicen GO.
5. En operaciones cada rol hace lo suyo a la vez:

| Rol | Órdenes |
| --- | --- |
| Dirección | mover el rover, descargar, pausar, decisiones de historia e imprevistos, rediseñar, **lanzar** |
| Ingeniería | construir, módulos, encender/apagar edificios |
| Ciencia | acercarse a un objetivo, perforar/analizar, descargar |
| Comunicaciones | transmitir, mejorar la antena |
| Todos | seleccionar, detener, terminar el aterrizaje, saltar el tutorial, validar el diseño |
| Dueño de cada área | elegir y quitar las piezas de su área del taller (`Permisos.AREAS`) |

Si alguien da una orden que no es de su rol, ve el aviso «Esa orden le toca a otro rol del equipo». Si alguien se desconecta con la
misión en marcha, sus roles pasan al jefe de sala.

## Tres formas de conectarse

| Forma | Quién puede unirse | Qué hace falta |
| --- | --- | --- |
| **Misma red Wi-Fi** (anfitrión de escritorio que también juega) | Escritorio | Nada más. El anfitrión abre el puerto 9080 (Windows pregunta por el cortafuegos la primera vez: *Permitir*). |
| **Por internet con un túnel** | Escritorio y navegador | El anfitrión de escritorio publica su sala con `cloudflared` (ver la sección de abajo). |
| **Servidor dedicado** | Escritorio y navegador | Un servicio que ejecute `Dockerfile.servidor` (Render, Fly…) y dé una URL `wss://`. Nadie tiene que dejar su PC encendida. Para un servidor propio con dominio (web + sala con HTTPS): `docs/SERVIDOR.md` y `deploy/servidor/` (preparado el 15 nov, sin probar en un servidor real). |

## Jugar entre redes distintas con Cloudflare (túnel)

El anfitrión de escritorio abre la sala en su PC (puerto 9080) y un túnel de Cloudflare la publica en internet con `wss://` (el
navegador exige TLS; Cloudflare lo pone). Nadie abre puertos en su router.

**Rápido, sin dominio (sirve ya mismo):**

1. Instalar `cloudflared` en la PC del anfitrión: `winget install --id Cloudflare.cloudflared` (PowerShell).
2. Abrir el juego › *MULTIJUGADOR* › *Crear sala*.
3. En PowerShell: `cloudflared tunnel --url http://localhost:9080`. Muestra una dirección como `https://nombre-al-azar.trycloudflare.com`.
   (En Windows basta con ejecutar `tools/paquete_windows/Publicar_sala_en_internet.bat`: instala `cloudflared` si falta y abre el túnel.)
4. Los demás (escritorio o navegador) abren *MULTIJUGADOR*, escriben `nombre-al-azar.trycloudflare.com` en *Dirección de la sala* y pulsan *Entrar*
   (el juego completa `wss://` solo). La dirección cambia cada vez que se reinicia el túnel.

**Con tu cuenta de Cloudflare y una dirección fija** (hace falta un dominio añadido a esa cuenta):

1. `cloudflared tunnel login` (se abre el navegador y eliges el dominio).
2. `cloudflared tunnel create gaia`, y `cloudflared tunnel route dns gaia gaia.tudominio.com`.
3. Un `config.yml` con `tunnel: gaia`, `credentials-file: <la ruta que mostró el paso 2>` y, en `ingress`, `hostname: gaia.tudominio.com` con
   `service: http://localhost:9080` (más la regla final `service: http_status:404`).
4. `cloudflared tunnel run gaia`. Todos escriben `gaia.tudominio.com`.
   (También se puede crear desde el panel Zero Trust › Networks › Tunnels, con *Public hostname* apuntando a `http://localhost:9080`.)

Sin dominio, lo normal es el modo rápido. El juego manda un latido cada 20 s para que Cloudflare no cierre una sala en espera por inactividad.

> **Estado de la prueba.** Probado: servidor dedicado y anfitrión-jugador con 4 procesos distintos conectados por WebSocket en una
> misma máquina (`tools/probar_red.sh`), y la pantalla real (menú, sala, carga, taller y revisión) con dos copias del juego.
> **No probado:** otra computadora de verdad en la misma Wi-Fi, el túnel de Cloudflare, `Dockerfile.servidor` en un servicio real
> ni la versión web conectada a un servidor. Un navegador **no puede crear** una sala (no puede escuchar conexiones); solo unirse,
> y desde una página `https://` (GitHub Pages) el navegador solo acepta direcciones `wss://`, no `ws://192.168…`.

## Cómo está hecho (para quien toque el código)

- `scenes/net/red.gd` (autoload `Red`): conexión WebSocket, sala, y todos los RPC. **El anfitrión manda**: lleva el `MissionRunner`
  sin vista (`modo_red`), comprueba los permisos y reparte snapshots (máximo 10 por segundo), rutas, avisos y votos.
- `scenes/net/red_port.gd`: hace de «Port» del anfitrión (misma interfaz que `scenes/b/port.gd`), así `MissionRunner` no sabe que hay red.
- `scenes/net/cliente_juego.gd`: la vista de cada jugador; sus órdenes salen por `Red.enviar_orden` y lo que llega se entrega a su Port.
- `scenes/net/sala.gd` y `permisos.gd`: lógica pura de sala (orden de llegada, roles, jefe) y de permisos por rol; con pruebas GUT.
- `scenes/net/lobby_panel.gd`: la pantalla de sala. Textos en `scenes/net/net_text.gd` (español e inglés).
- `sim/` **no se tocó**: la simulación sigue sin saber nada de la red. `EventBus` tampoco.
- El anfitrión no se fía del cliente: solo acepta órdenes con datos simples (`Red.sanear`) y de un rol que las tenga.
- Pruebas: `tools/probar_red.sh [godot] [puerto] [servidor|lan]` (servidor dedicado o anfitrión + 3 jugadores automáticos, con
  `tools/bot_red.gd`) y `tests/test_red_sala.gd`.

## Límites conocidos

- Sin reconexión: si alguien se cae, no puede volver a la misma misión (sus roles pasan al jefe).
- Sin guardado en red: la partida en red no se guarda ni se continúa.
- No hay salas con código ni búsqueda automática de partidas en la red local: se escribe la IP.
- Todos ven el mismo rover pero cada dispositivo anima por su cuenta: el movimiento puede diferir una fracción de segundo.
- El aterrizaje lo termina el primer dispositivo que acaba su animación; el resto lo ve ya en operaciones.
- El rendimiento de varios jugadores en un servidor real y la latencia por internet no se midieron.
