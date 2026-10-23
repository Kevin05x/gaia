# Validación de la entrega B — 23 de octubre de 2026

Motor: Godot 4.7.2 Standard, renderer Compatibility.

## Comprobado

- Importación completa de scripts, modelos TSCN/GLB, catálogo ES/EN y seis sonidos.
- Prueba automática de ciclo: aterrizaje, desbloqueo, diseño solar/RTG, instrumentos ausentes, ruta, acción, ciencia recibida, transmisión, antenas 2/3, pausa, modo seguro, cambio de idioma, informe, rediseño y cancelación.
- Carga de mission.tscn sin EventBus, GameState ni proveedor: no fabrica estado de producción.
- Prueba de adaptador: órdenes, snapshot, batería, hora, rechazo si falta señal y desconexión.
- Exportación Web release de un solo hilo exitosa. Se corrigió la selección inicial de plantilla multihilo.
- Ejecución WebGL2 desde servidor local sin cabeceras de aislamiento, escenario visible y HUD actualizado; selección de JZ-01 y orden Acercar rover verificadas en navegador.
- El contador de la presentación mostró 60 FPS en el navegador de este equipo durante operaciones normales. No equivale a un benchmark de todos los equipos ni de toda tormenta.
- Revisión nativa inicial de la superficie y corrección del sentido de las caras del terreno; modelos visibles, cámara y sombras.

## Repetir pruebas

Con el proyecto importado, usando el ejecutable de Godot 4.7.2:

```text
godot --headless --path . --script res://scenes/b/tests/integration.gd --time-scale 5
godot --headless --path . --script res://scenes/b/tests/adapter.gd
godot --headless --path . --export-release Web build/web/index.html
```

Resultados esperados: INTEGRATION PASS y ADAPTER PASS; sin SCRIPT ERROR. Las pruebas de B no sustituyen GUT de la simulación de A.

## Pendiente del equipo

Conectar la simulación real de A y revisar en pareja una misión de sus seis etapas; incluir datasets/fotos y sus créditos desde NasaApi; probar build integrado en la laptop más débil y otra red; validar dirección artística con el grupo; grabar el video final y publicar según las reglas vigentes. La parte B proporciona vistas, assets y frontera de integración para ese trabajo compartido.
