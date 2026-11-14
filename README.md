# GAIA

Juego 3D de diseño de misiones espaciales para el **NASA Space Apps Challenge 2026**, reto *Space Mission Design Game*.

> **GAIA** es un nombre provisional y puede cambiar.

## Jugar

- **Escritorio (recomendada):** paquete de Windows con `GAIA.exe` (gráficos Forward+). Si no abre o va lento, usa `GAIA (modo compatible).bat`. Ver `docs/PLATAFORMA.md`.
- **Navegador (prueba rápida):** <https://kevin05x.github.io/gaia/>

Dos destinos: **Marte (cráter Jezero)**, con historia, y **la Luna (polo sur)**. Tres dificultades y de 1 a 4 personas por equipo (Go/No-Go por roles).

## Documentación

- `docs/CUMPLIMIENTO.md`: requisitos del reto, recomendaciones de la NASA y propuestas propias, con evidencia y límites.
- `docs/DATOS_NASA.md`: cada dato, imagen y modelo de la NASA con su fuente.
- `docs/PLATAFORMA.md`: decisión escritorio/web y mediciones.
- `scenes/b/docs/ARTE_Y_LICENCIAS.md`: arte, audio, modelos, licencias y uso de IA.

## Bucle del juego

1. **Briefing**: se presenta la misión y sus objetivos.
2. **Taller**: se diseña la misión equilibrando masa, presupuesto, energía y comunicaciones.
3. **Lanzamiento**: el cohete despega con la carga elegida.
4. **Aterrizaje**: entrada, descenso y aterrizaje.
5. **Operaciones**: la misión avanza por soles (días marcianos).
6. **Informe**: resultado de la misión y causas de lo que ocurrió.

## Tecnología

- Godot 4.7.2 Standard, GDScript (sin .NET).
- Escritorio: renderer Forward+ (sombras suaves, SSAO, SSIL y niebla volumétrica según el ajuste gráfico). Web: Compatibility, un solo hilo.
- Simulación en código puro (`sim/`), contenido en JSON (`content/`), 466 pruebas GUT (`tests/`).
- Datos de la NASA: press kits de NASA/JPL, NASA Science, NASA Image and Video Library y NASA 3D Resources (ver `docs/DATOS_NASA.md`).

## Cómo correrlo

Requisitos: [Godot 4.7.2 Standard](https://godotengine.org/) y [Git LFS](https://git-lfs.com/).

```
git clone https://github.com/Kevin05x/gaia.git
cd gaia
git lfs pull
```

Abre la carpeta como proyecto en Godot y pulsa **F5**. Para probar la versión web, usa **Remote Debug → Run in Browser** en el editor.

## Publicación

Cada cambio que llega a `main` ejecuta la acción **Publicar web** (`.github/workflows/publicar-web.yml`), que exporta el proyecto a web y lo publica en GitHub Pages.

## Flujo de trabajo

- Ramas: `main` (publicado), `develop` (integración) y ramas de trabajo `a/<tarea>` y `b/<tarea>`.
- Nadie sube directo a `main` ni a `develop`: todo entra con Pull Request. Los PR a `main` necesitan la aprobación de la otra persona.
- Commits con prefijo: `feat`, `fix`, `test`, `data`, `art`.
- Git LFS para `.blend`, `.glb`, `.png`, `.jpg`, `.wav` y `.ogg`.

## Equipo

- **Kevin** (Programador A): simulación, datos, taller, repositorio, CI y publicación. Ramas `a/...`.
- **Amner** (Programador B): mundo 3D, interfaz, HUD, informe, Blender y sonido. Ramas `b/...`.
