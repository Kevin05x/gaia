@echo off
REM Publica en internet la sala de GAIA de esta PC (para jugar con gente de otras redes).
REM 1) Abre GAIA, entra en MULTIJUGADOR y pulsa "Crear sala". 2) Ejecuta este archivo. 3) Pasa a los demas la direccion
REM que aparece como https://algo.trycloudflare.com (ellos escriben solo "algo.trycloudflare.com").
REM No hace falta iniciar sesion en Cloudflare. La direccion cambia cada vez que se vuelve a ejecutar.
where cloudflared >nul 2>nul
if errorlevel 1 (
  echo Instalando cloudflared...
  winget install --id Cloudflare.cloudflared -e --accept-package-agreements --accept-source-agreements
  echo Si acaba de instalarse, cierra esta ventana y ejecuta este archivo otra vez.
)
where cloudflared >nul 2>nul
if errorlevel 1 (
  echo No se encontro cloudflared. Instalalo desde https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
  pause
  exit /b 1
)
echo.
echo Busca abajo la linea https://....trycloudflare.com  y comparte esa direccion. Deja esta ventana abierta durante la partida.
echo.
cloudflared tunnel --url http://localhost:9080
pause
