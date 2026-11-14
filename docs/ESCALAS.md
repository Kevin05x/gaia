# Escala del mundo 3D de GAIA

**Contrato:** 1 unidad del motor = 1 metro real. Una casilla del mapa mide 4 m × 4 m (`scenes/b/escala.gd`). Todo lo que se dibuja se mide contra estas cifras; `tests/test_escala.gd` falla si alguien vuelve a desproporcionar algo (por ejemplo, un rover más alto que una torre).

## Por qué se cambió

En la primera versión cada objeto tenía su propia escala «a ojo»: el rover quedaba más alto que los hangares y que la antena. Ahora el rover es el **Perseverance de la NASA a 1:1** y los edificios se ajustaron a su alrededor.

## Medidas (m) — medidas sobre los modelos ya colocados en el juego

| Objeto | Largo × ancho × alto | Referencia real |
|--------|----------------------|-----------------|
| Rover (Perseverance, mástil levantado, sin panel de relleno) | 3,1 × 2,7 × 2,2 | NASA/JPL: ≈ 3 m de largo, 2,7 m de ancho, 2,2 m de alto |
| Ruedas (6) | Ø 0,52 | NASA/JPL: 52,5 cm |
| Helicóptero Ingenuity (rotor a rotor) | 1,2 × 0,5 alto | NASA/JPL: 1,2 m de rotor, 0,49 m de alto |
| Persona (referencia) | 1,8 de alto | — |
| Domo | 3,9 × 3,4 × 2,9 | módulo habitable pequeño |
| Hangar | 2,9 × 3,9 × 2,7 | cabe el rover (2,2 m) con holgura |
| Extractor de hielo | 3,6 × 3,6 × 4,1 | torre de perforación |
| Antena | 3,0 × 3,0 × 4,1 | antena de relé |
| Torreta | 3,4 × 2,8 × 4,2 | — |
| Foco de luz | 3,2 × 3,2 × 4,7 | poste |
| Muros / compuerta | paso libre > 3,2 m de ancho y > 2,6 m de alto; muro más bajo que el rover | el rover pasa por la compuerta |
| Arañas / biters / coloso (modelo × factor de la ficha) | ≈ 2,2 m / 2,5 m / 5 m de envergadura | fauna ficticia: más grande que una persona, el coloso del tamaño de un edificio |

## Reglas que verifican las pruebas

- La casilla mide 4 m y la conversión casilla ↔ mundo es reversible.
- El rover mide 2,7–3,4 m de largo, 2,4–3,0 m de ancho y 1,9–2,5 m de alto, y está apoyado en el suelo.
- Las seis ruedas miden ≈ 52 cm y giran sobre su eje.
- Ningún edificio es más bajo que el rover ni desborda su casilla.
- La compuerta deja pasar al rover y el muro no lo tapa.
- Ingenuity mide ≈ 1,2 m de rotor a rotor.

## Límites (a propósito)

- Las **distancias** del mapa son de juego: 71 × 71 casillas ≈ 284 m de lado, no kilómetros. Es la escala que hace que una partida dure minutos.
- Los costos, masas y días del taller van a escala reducida y el juego lo avisa en pantalla; las proporciones y compromisos son los reales.
- Las enemigos son ficticios y no se miden contra nada real.
