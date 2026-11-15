# GAIA en un servidor propio (web + multijugador por internet)

Guía del bloque 7 del plan de mejoras. Deja la web en `https://gaia.<dominio>` y la sala multijugador en `wss://sala.<dominio>`,
con HTTPS automático. Los archivos están en `deploy/servidor/`.

> **Estado: preparado, sin probar en un servidor real.** Lo único comprobado es que `docker-compose.yml` es válido
> (`docker compose config`). No se construyeron las imágenes, no se validó el `Caddyfile` (Docker Desktop no estaba arrancado) ni se
> probó nada contra un dominio. Los pasos de abajo son lo esperable, no un resultado medido. La cifra de memoria del servidor de
> juego (100–200 MB por sala) es una estimación sin medir.

## Qué hace cada pieza

| Archivo | Qué es |
| --- | --- |
| `deploy/servidor/docker-compose.yml` | Dos contenedores: `caddy` (web + HTTPS) y `sala` (servidor multijugador de Godot, sin pantalla). |
| `deploy/servidor/Dockerfile.web` | Exporta la web con Godot y la mete en una imagen de Caddy. |
| `Dockerfile.servidor` (raíz) | El servidor de la sala (ya existía): Godot sin pantalla con `scenes/net/servidor.tscn`. |
| `deploy/servidor/Caddyfile` | `gaia.<dominio>` sirve la web; `sala.<dominio>` hace de proxy WebSocket a `sala:9080`. |
| `deploy/servidor/.env.ejemplo` | Plantilla del único dato que hay que poner: `DOMINIO`. |

El puerto 9080 de la sala **no** se publica a internet: solo lo ve Caddy dentro de la red de Docker.

## Si el servidor ya tiene otro proyecto

GAIA no necesita tocar nada de lo que ya corre. Antes de instalar, mira sin cambiar nada: `docker ps`, `ss -tlnp | grep -E ':80|:443'` y `ls /opt`.
Clona en su propia carpeta (`/opt/gaia`), no instales Docker de nuevo si ya está, y usa siempre este mismo archivo de compose (el proyecto se llama `gaia`).
**Los puertos 80 y 443 solo pueden usarlos un programa a la vez**: si ya los usa otro proxy (nginx, Caddy, Traefik), GAIA debe ir detrás de ese proxy en vez de arrancar el suyo.
Nunca ejecutes `docker system prune`, `docker compose down -v` ni borres volúmenes de otros proyectos.

## Pasos

1. **Dominio.** Con el dominio gratis, crea dos registros DNS de tipo A que apunten a la IP pública del servidor: `gaia` y `sala`
   (por ejemplo `gaia.midominio.xyz` y `sala.midominio.xyz`). Hasta que propaguen, Let's Encrypt no podrá dar el certificado.
2. **Puertos.** En el cortafuegos del servidor (o del proveedor), abre 80 y 443 (TCP y UDP). Nada más.
3. **Docker.** Comprueba que el servidor tiene Docker y Docker Compose (`docker --version`, `docker compose version`).
4. **Código.** Clona el repositorio **con Git LFS** (`git lfs install` y luego `git clone …` o `git lfs pull`): los modelos y las
   texturas son archivos LFS, y sin ellos la imagen de la web sale sin arte. Usa la rama que quieras publicar (`main` cuando llegue).
5. **Dominio en `.env`.** `cp deploy/servidor/.env.ejemplo deploy/servidor/.env` y cambia `DOMINIO=` por tu dominio (solo el
   dominio, sin `gaia.` delante).
6. **Levantar.** Desde la raíz del repositorio:
   ```
   docker compose -f deploy/servidor/docker-compose.yml --env-file deploy/servidor/.env up -d --build
   ```
   La primera construcción baja ~1 GB de plantillas de Godot y tarda unos minutos; el servidor tiene 100 GB de disco, de sobra.
7. **Comprobar.**
   - `docker compose -f deploy/servidor/docker-compose.yml ps`: los dos servicios en `running`.
   - `docker compose -f deploy/servidor/docker-compose.yml logs sala`: debe decir `GAIA servidor: puerto 9080 -> OK`.
   - `docker compose -f deploy/servidor/docker-compose.yml logs caddy`: debe decir que obtuvo el certificado de ambos nombres.
   - Abre `https://gaia.<dominio>` en un navegador: carga el juego.
8. **Jugar en red.** En el juego, *MULTIJUGADOR* › *Unirse* y escribe `sala.<dominio>` (el juego lo completa como `wss://`).
   El primero en entrar es el jefe de la sala: elige destino, dificultad y duración del sol, y empieza la partida.
9. **Probar con 4 personas en redes distintas** y anotar el resultado en `docs/MULTIJUGADOR.md`. Hoy no se ha hecho.

## Actualizar y apagar

- Actualizar a una versión nueva: `git pull` y repetir el paso 6 (reconstruye; los certificados se conservan en el volumen `caddy_datos`).
- Apagar: `docker compose -f deploy/servidor/docker-compose.yml down`.
- Ver cuánta memoria usa la sala de verdad: `docker stats`. Así se sustituye la estimación por una cifra medida.

## Si algo falla

- **Caddy no consigue el certificado**: casi siempre es DNS (los nombres aún no apuntan al servidor) o los puertos 80/443 cerrados.
  `docker compose … logs caddy` lo dice.
- **La web carga pero «Unirse» no conecta**: comprueba que escribes `sala.<dominio>` y no `gaia.<dominio>`, y mira
  `docker compose … logs sala`.
- **La web sale sin modelos ni texturas**: se construyó sin los archivos LFS (paso 4). `git lfs pull` y reconstruye con `--build`.
- **Un navegador no puede crear una sala**, solo unirse: la crea siempre el servidor (o un anfitrión de escritorio).
- **Hilos en la web**: la web de hoy va con un hilo y no necesita cabeceras especiales. Si algún día se activan hilos, hay que
  descomentar las dos cabeceras `Cross-Origin-…` del `Caddyfile`.

## Alternativa sin servidor propio

Un túnel de Cloudflare desde el PC de quien crea la sala: ver `docs/MULTIJUGADOR.md`.

## Servidor con Caddy propio (sin Docker) — el caso del VPS de Kevin, 15 nov

El VPS ya tenía otro proyecto con **Caddy como servicio del sistema** en los puertos 80 y 443, y sin Docker. Por eso no se usa el
compose de arriba: se instala solo la sala como servicio `gaia-sala` y se añade un bloque al Caddy existente.

1. **Sala** (con un usuario con sudo): `bash instalar.sh` desde `deploy/servidor/nativo/` (clona en `/opt/gaia`, baja Godot 4.7.2 sin pantalla,
   importa el proyecto y arranca `gaia-sala` en el puerto 9080). Nada se instala fuera de `/opt/gaia` y del servicio nuevo.
2. **Caddy**: copia de seguridad, un bloque nuevo, validar y recargar (la recarga no corta lo que ya sirve):
   ```
   sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak-gaia
   printf '\nsala.TU_DOMINIO {\n\treverse_proxy localhost:9080\n}\n' | sudo tee -a /etc/caddy/Caddyfile
   sudo caddy validate --config /etc/caddy/Caddyfile
   sudo systemctl reload caddy
   ```
   Si `validate` falla, se restaura la copia y no se recarga nada.
3. **Web del juego**: la sirve GitHub Pages (https) y se conecta a `wss://sala.TU_DOMINIO`; no hace falta exportarla en el VPS.
4. El puerto 9080 queda abierto en el servidor (el cortafuegos de Hostinger no tenía reglas). Es solo el WebSocket del juego.

**Estado (15 nov, tarde): instalado y comprobado hasta el saludo WebSocket.** En el VPS de Kevin (Hostinger KVM 2, Ubuntu 26.04) están
`gaia-sala` activo, el certificado de `sala.gaianasa.tech` emitido por Let's Encrypt y el bloque en el Caddy existente; `gruasvp.com` no se tocó.
Desde el propio VPS, `curl --http1.1` con las cabeceras de WebSocket recibe `101 Switching Protocols` tanto directo (`127.0.0.1:9080`) como por
`https://sala.gaianasa.tech`. **Aún no se ha jugado una partida** (unirse desde el juego, 2 o más personas, redes distintas): eso sigue pendiente.
Las visitas de navegador a `https://sala.gaianasa.tech/` dan 502 en el registro de Caddy: es normal (la sala solo habla WebSocket).


## Cuatro salas (15 nov, tarde)

Un proceso lleva una sala. Para cuatro: `gaia-sala@9080` a `@9083` (plantilla `deploy/servidor/nativo/gaia-sala@.service`) y un bloque de Caddy que reparte por ruta (`deploy/servidor/nativo/Caddyfile.salas`).

1. En el VPS: `bash /opt/gaia/repo/deploy/servidor/nativo/instalar_salas.sh` (actualiza el repositorio, desactiva la sala única `gaia-sala` y enciende las cuatro instancias).
2. Caddy: volver a la copia anterior al bloque de GAIA y añadir el bloque nuevo:
   ```
   sudo cp /etc/caddy/Caddyfile.bak-gaia /etc/caddy/Caddyfile
   sudo tee -a /etc/caddy/Caddyfile < /opt/gaia/repo/deploy/servidor/nativo/Caddyfile.salas
   sudo caddy validate --config /etc/caddy/Caddyfile
   sudo systemctl reload caddy
   ```
3. Probar: `sala.gaianasa.tech/1` a `/4` desde el lobby, o `sala.gaianasa.tech` (= sala 1).
Si algo falla, la copia `Caddyfile.bak-gaia` deja el Caddy como estaba antes de GAIA.
