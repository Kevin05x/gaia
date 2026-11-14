@echo off
REM GAIA en modo compatible (OpenGL): para PCs con graficos integrados antiguos o si GAIA.exe no abre.
cd /d "%~dp0"
start "" "GAIA.exe" --rendering-method gl_compatibility
