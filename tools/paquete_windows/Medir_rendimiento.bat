@echo off
REM Mide el rendimiento de GAIA en esta PC (unos 5 minutos) y guarda los resultados en esta carpeta:
REM la mision en Alta y en Baja, la plataforma de lanzamiento (Saturno V) en Alta y en Baja, y el modo compatible.
cd /d "%~dp0"
echo Midiendo la mision en Alta (Forward+). No toques nada; cada prueba se cierra sola en un minuto...
GAIA.exe --medir --preset=alta
ren medicion_rendimiento.txt medicion_forward_plus.txt 2>nul
echo Midiendo la mision en Baja...
GAIA.exe --medir --preset=baja
ren medicion_rendimiento.txt medicion_baja.txt 2>nul
echo Midiendo la plataforma de lanzamiento en Alta...
GAIA.exe --medir --escena=plataforma --preset=alta
ren medicion_rendimiento.txt medicion_plataforma_alta.txt 2>nul
echo Midiendo la plataforma de lanzamiento en Baja...
GAIA.exe --medir --escena=plataforma --preset=baja
ren medicion_rendimiento.txt medicion_plataforma_baja.txt 2>nul
echo Midiendo la mision en modo compatible (OpenGL)...
GAIA.exe --rendering-method gl_compatibility --medir
ren medicion_rendimiento.txt medicion_compatible.txt 2>nul
echo.
echo Listo. Resultados:
for %%f in (medicion_forward_plus.txt medicion_baja.txt medicion_plataforma_alta.txt medicion_plataforma_baja.txt medicion_compatible.txt) do (
  echo.
  type %%f
)
pause
