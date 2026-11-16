@echo off
REM GAIA con OpenGL (modo compatible): es la forma recomendada de jugar. Va fluido tambien en PCs con graficos integrados (Intel UHD, etc.).
REM Medido el 15 nov en una Intel UHD: 59 FPS con OpenGL frente a 26 FPS con Vulkan (GAIA.exe directo).
cd /d "%~dp0"
start "" "GAIA.exe" --rendering-method gl_compatibility --rendering-driver opengl3
