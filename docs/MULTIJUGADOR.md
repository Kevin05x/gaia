# Multijugador en red (hasta 4 personas, cada una en su dispositivo)

Rama `b/multijugador`. Todos juegan **la misma misión a la vez**: un solo rover y una sola simulación. Cada persona lleva un rol
(Dirección, Ingeniería, Ciencia, Comunicaciones) y solo puede dar las órdenes de su rol. El reparto de roles es el mismo del equipo
de una sola pantalla (`content/rules.json › roles_equipo`): con 4 personas, uno por rol; con 2, dos roles cada uno; con 1, todos.

## Cómo se juega

1. **Quien crea la sala** (versión de escritorio): *Menú › MULTIJUGADOR › Crear sala*. Le aparecen sus direcciones IP.
2. **Los demás**: *MULTIJUGADOR*, escriben la IP (o la dirección `wss://…` del servidor) y pulsan *Entrar*.
3. El **jefe de sala** (el primero en entrar) elige destino y dificultad y pulsa *Empezar misión*. Quien llegue después **también puede entrar con la misión en marcha**: pasa directo a la partida y los roles se reparten de nuevo entre todos (máximo 4).
4. En el taller todos ven el diseño en vivo. **Presupuesto y masa son uno solo para todo el equipo**, pero cada rol elige las piezas de su área: Dirección = cohete y trayectoria; Ingeniería = chasis y energía; Comunicaciones = antena; Ciencia = instrumentos. Con 1, 2, 3 o 4 personas siempre queda alguien a cargo de cada área. Al entrar sale una guía (reabrible con «¿Cómo funciona?») y un panel con tu rol, tus áreas y lo que gastó cada área; las áreas ajenas se ven apagadas y el anfitrión rechaza esas piezas. Cualquiera pulsa *Validar* y se abre el
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
