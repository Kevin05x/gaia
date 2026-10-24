# Parte B: superficie e interfaz de GAIA

Abrir el `project.godot` del repositorio y pulsar F5. Está configurado para revisar B hasta que A conecte el flujo definitivo. No es necesario copiar archivos ni importar traducciones a mano.

## Contenido

- Cráter low-poly original, afloramientos, minerales, capas ocultas, cuadrícula, rutas y selección.
- Rover detallado con seis ruedas, brazo animado y piezas visibles según diseño solar/RTG e instrumentos.
- Estación con tres niveles de antena; dron con rotores/despegue/aterrizaje; compañero original con seguimiento/búsqueda.
- Cámara isométrica, clic y minimapa, paneo, zoom, giro y centrado.
- EDL con grúa/cables; polvo de tormenta, noche/día, taladro, radar y señal de transmisión.
- HUD de batería/capacidad/generación/consumo, memoria/capacidad, ciencia enviada, minerales, polvo, antena, objetivos y ventanas sobre la línea del sol.
- Estado confirmado, botones deshabilitados con motivo, pausa, modo seguro, progreso, avisos y ayuda.
- Informe con estrellas y causas recibidas, foto/crédito/enlace o respaldo, rediseño.
- Interfaz español/inglés, tema propio, sonido/volumen y calidad persistentes.
- Modelos editables TSCN y GLB, fuentes de arte, contrato de integración y pruebas automáticas.

## Controles

Clic en objetivo = seleccionar; Acercar rover = pedir ruta; clic en suelo/minimapa = pedir movimiento. Derecho+arrastrar = cámara; rueda = zoom; Q/E = giro; F = centrar rover. C = panorámica; V = radar; X = compañero; T = transmitir. Escape = pausa o cerrar opciones. F2 abre estados de revisión solo en el proveedor de B.

## Qué revisa A

`INTEGRACION_A.md` contiene el contrato completo y ejemplos. Instanciar `mission.tscn` y conectar su hijo Port. A conserva energía/clima/rutas/ciencia/victoria/guardado/API/taller. Las mismas escenas de producción se usan en revisión; solo se reemplaza el proveedor de estados.

## Archivos para subir

`scenes/b/` y la reparación revisada de `project.godot`. No subir `.godot/`, logs, builds o backups. Conservar `.uid` y `.import` junto a recursos. Respetar `.gitattributes`/LFS del repo. `scenes/surfaces/` es trabajo previo del usuario y no forma parte de este paquete.

## Verificación

Consultar `VALIDACION.md`. La integración definitiva con la simulación de A debe comprobarse en pareja; no puede darse por probada antes de que A exista. La publicación al concurso, el video final y la aprobación artística del equipo son entregas compartidas.
