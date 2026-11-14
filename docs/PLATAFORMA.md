# Escritorio o navegador: decisión y mediciones

**Decisión:** la versión principal de GAIA es la **de escritorio (Windows)**; la web (GitHub Pages) queda como versión de prueba rápida para quien solo quiere abrir un enlace.

## Por qué escritorio

| Motivo | Detalle | Cómo se comprobó |
|--------|---------|------------------|
| Gráficos | El navegador solo permite el renderer *Compatibility* (WebGL 2). El escritorio usa *Forward+*: sombras suaves, oclusión ambiental (SSAO), iluminación indirecta (SSIL) y niebla volumétrica en Alta/Ultra | `project.godot`, `scenes/b/sky_light.gd`; capturas en el PDF |
| CPU | La misma simulación corre más lenta en WebAssembly que en código nativo | Banco de simulación (tabla de abajo) |
| Peso y modelos | La web excluye los modelos 3D oficiales de la NASA (18 MB) para no engordar la descarga | `export_presets.cfg` |
| Estabilidad | En el navegador el tiempo de cuadro varía más (recolección de basura, pestañas, extensiones) | Sin medición propia; es una razón de diseño, no un dato |

## Mediciones hechas (contenedor sin GPU)

Misma partida (diseño inicial en Marte, 12 s de calentamiento y 45 s medidos, 1280×720, calidad automática desactivada, reloj real). Equipo: Intel Xeon 2,1 GHz, 2 hilos, **render por software** (llvmpipe/SwiftShader), sin GPU.

| Plataforma | Ajuste | FPS medio | Cuadro medio | Simulación pura (CPU) |
|------------|--------|-----------|--------------|-----------------------|
| Escritorio, Compatibility (OpenGL) | Media | 4,5 | 224 ms | **0,672 ms/paso** |
| Escritorio, Forward+ (Vulkan) | Alta | 2,2 | 461 ms | **0,705 ms/paso** |
| Web (Chromium sin GPU) | Media | 1,2 | 819 ms | **0,903 ms/paso** |

Archivos originales en `docs/mediciones/`.

### Antes y después del rover real y la escala 1:1 (14 nov 2026, mismo equipo y misma partida)

La v2 reemplazó el rover de bloques por el Perseverance de la NASA (≈ 100 superficies y 42 000 triángulos) y el mundo pasó de 24 a 71 casillas de lado (cada una de 4 m).

| Ajuste | Llamadas de dibujo | VRAM | Cuadro medio (software) | Simulación pura |
|--------|-------------------|------|-------------------------|-----------------|
| Alta, **antes** (rover de bloques) | 299 | 228 MB | 461 ms | 0,705 ms/paso |
| Alta, rover real con texturas de 1024 px | 455 | 320 MB | 455 ms | 0,498 ms/paso |
| Alta, rover real con texturas de 512 px (**versión final**) | 453 | 274 MB | 459 ms | 0,655 ms/paso |
| Baja, rover real en detalle reducido | 324 | 228 MB | 142 ms (7,0 FPS) | 0,619 ms/paso |
| Media (Compatibility), rover real | 501 | 163 MB | 215 ms (antes 224 ms) | 0,519 ms/paso |

Lo que se hizo para contener el costo: texturas del Perseverance a 512 px (−46 MB de VRAM frente a 1024 px, sin diferencia visible a la distancia de juego), detalle reducido del rover en el ajuste Baja (de 99 a 52 superficies; no carga las texturas), y el rover se funde por tipo de acabado en una malla por pieza móvil. Archivos en `docs/mediciones/v2_*`.

**Lectura honesta:** con render por software el cuadro medio no empeoró (la CPU simulando la GPU ya estaba saturada), pero las llamadas de dibujo subieron un 50 % y la VRAM 46 MB en Alta. En una tarjeta gráfica real 450 llamadas de dibujo son pocas, pero **no se midió**: en una GPU integrada Intel UHD el costo extra puede notarse. Por eso el detalle reducido existe y queda documentado, y `Medir_rendimiento.bat` es la forma de comprobarlo en la PC del equipo. El peor cuadro de la medición (≈ 11 s) ocurre al compilar sombreadores en software y no es representativo de una GPU real, pero tampoco se verificó allí.

### Qué sí y qué no dicen estas cifras

- **Sí:** el banco de simulación pura no depende de la GPU. En este equipo, la web tarda **≈1,3 veces más** (0,903 frente a 0,67–0,71 ms por paso) que el código nativo. Es una diferencia real y repetible de CPU.
- **No:** los FPS de arriba **no representan una PC con tarjeta gráfica**. Con render por software todo está limitado por el procesador, y un cuadro de Forward+ en alta calidad cuesta mucho más que uno en Compatibility. En una GPU real se espera lo contrario a ese orden de magnitud, pero **no está medido**.
- **No medido todavía:** el rendimiento en la PC del equipo (Intel UHD). Para medirlo: abrir la carpeta del juego y ejecutar `Medir_rendimiento.bat` (≈2 minutos, deja `medicion_forward_plus.txt` y `medicion_compatible.txt`). Si Forward+ va lento, `GAIA (modo compatible).bat` abre el juego con OpenGL.

## Cómo se mide

`GAIA.exe --medir [--preset=media|alta|ultra]` (o `?medir=1` en la web) entra directo a la misión, usa un ajuste gráfico fijo sin calidad automática y escribe un informe con FPS, percentil 95, peor cuadro, VRAM, llamadas de dibujo, banco de CPU y datos del equipo. Código: `scenes/a/medidor.gd`.
