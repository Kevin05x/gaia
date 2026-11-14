@echo off
REM Mide el rendimiento de GAIA en esta PC (unos 60 s) y guarda medicion_rendimiento.txt en esta carpeta.
cd /d "%~dp0"
echo Midiendo GAIA en modo escritorio (Forward+). No toques nada; se cierra solo en un minuto...
GAIA.exe --medir
echo.
echo Midiendo GAIA en modo compatible (OpenGL)...
ren medicion_rendimiento.txt medicion_forward_plus.txt 2>nul
GAIA.exe --rendering-method gl_compatibility --medir
ren medicion_rendimiento.txt medicion_compatible.txt 2>nul
echo.
echo Listo. Resultados:
type medicion_forward_plus.txt
echo.
type medicion_compatible.txt
pause
