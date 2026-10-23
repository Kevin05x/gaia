# GAIA

Juego 3D de diseño de misiones espaciales para el **NASA Space Apps Challenge 2026**, reto *Space Mission Design Game*.

> **GAIA** es un nombre provisional y puede cambiar.

## Jugar

Versión publicada: <https://kevin05x.github.io/gaia/>

## Bucle del juego

1. **Briefing**: se presenta la misión y sus objetivos.
2. **Taller**: se diseña la misión equilibrando masa, presupuesto, energía y comunicaciones.
3. **Lanzamiento**: el cohete despega con la carga elegida.
4. **Aterrizaje**: entrada, descenso y aterrizaje.
5. **Operaciones**: la misión avanza por soles (días marcianos).
6. **Informe**: resultado de la misión y causas de lo que ocurrió.

## Tecnología

- Godot 4.7.2 Standard, GDScript (sin .NET).
- Renderer Compatibility, exportación web de un solo hilo.
- Datos de la NASA: `images-api.nasa.gov` y `api.nasa.gov`.

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
