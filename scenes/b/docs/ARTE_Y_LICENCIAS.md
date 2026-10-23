# Arte y licencias de la parte B

Todos los modelos, materiales, geometría del terreno, ilustración `jezero.svg` y audios WAV de esta carpeta se crearon originalmente para esta entrega con asistencia de IA. No contienen mallas, fotos, logotipos o audios descargados de terceros. Su autoría no debe atribuirse a NASA. El titular del repositorio puede incorporarlos al proyecto y decidir la licencia final de la obra; aquí no se cambia la licencia del repositorio ni se promete revisión jurídica.

## Pipeline con Blender

1. Importar `assets/models/rover.glb` (o dron/compañero/estación) con File > Import > glTF 2.0.
2. Conservar 1 unidad = 1 metro, frente -Z, pivotes de ruedas y brazo. Mantener nombres `RoverVisual`, `Wheel0` a `Wheel5`, `arm`, `solar`, `rtg`, `drill`, `radar`, `spectrometer`, `meteo`, `head`.
3. Hacer ajustes originales del grupo, aplicar escala/rotación antes de animar y exportar GLB sin Draco. Para mantener los scripts, introducir la malla en la TSCN preservando sus nodos pivote/nombres.
4. Usar colores planos; si añaden texturas, <=1024 px rover y <=512 secundarios. Comprobar LODs y triángulos en el importador de Godot.
5. Una persona (B) exporta; fuentes .blend se guardan en assets_src si se crean. Esta entrega incluye fuentes generativas y GLB; no se inventan archivos .blend no trabajados.

## Audio

`wind.wav`: ambiente filtrado; `motor.wav`: motor suave; `radio.wav`: pulso de enlace; `confirm.wav`: confirmación de operación; `drill.wav`: perforación; `landing.wav`: descenso. Ambiente/motor/radio son bucles configurados por importador. Audio se desbloquea tras interacción. Hay volumen y silencio persistentes. No se usan sonidos extraídos de películas u otros juegos.

## Fotos y modelos NASA posteriores

Si el equipo decide sustituir el rover original por el modelo NASA específico del plan, registre URL y condiciones de ese asset; no asuma licencia idéntica para todos los recursos. A entrega fotos/creditos mediante el informe; B ya admite Texture2D y metadatos. En ausencia de foto se muestra la ilustración original identificada.
