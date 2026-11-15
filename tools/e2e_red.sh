#!/usr/bin/env bash
# Prueba de extremo a extremo del multijugador: un servidor sin pantalla y clientes sin pantalla, de verdad, por WebSocket.
# Comprueba: entrar en la sala, reparto de roles, piezas de otro rol rechazadas, tope de presupuesto por rol, diseño y lanzamiento,
# un rover por jugador, cada uno ve a los demás donde están, y órdenes de otro rol rechazadas.
# Uso:  GODOT=/ruta/a/godot bash tools/e2e_red.sh [2|4|tarde] [puerto]
#   2      dos jugadores (por defecto)       4      cuatro jugadores, un rol cada uno
#   tarde  dos empiezan y un tercero entra con la misión en marcha
set -u
GODOT="${GODOT:-godot}"
MODO="${1:-2}"
PUERTO="${2:-9099}"
SALIDA="$(mktemp -d)"
PORT="$PUERTO" "$GODOT" --headless --path . scenes/net/servidor.tscn -- --servidor > "$SALIDA/servidor.txt" 2>&1 &
SERVIDOR=$!
sleep 6
DIR="ws://127.0.0.1:$PUERTO"
lanzar() {  # nombre, argumentos...
  local nombre="$1"; shift
  "$GODOT" --headless --path . res://tools/e2e_red.tscn -- --dir=$DIR --nombre=$nombre "$@" > "$SALIDA/$nombre.txt" 2>&1 &
  PIDS+=($!); NOMBRES+=("$nombre")
}
PIDS=(); NOMBRES=()
case "$MODO" in
  4)
    lanzar Ana --jefe --n=4 --dx=3 --dy=0; sleep 2
    lanzar Beto --n=4 --dx=-3 --dy=0; sleep 2
    lanzar Cami --n=4 --dx=0 --dy=3; sleep 2
    lanzar Dani --n=4 --dx=0 --dy=-3 ;;
  tarde)
    lanzar Ana --jefe --n=2 --dx=3 --dy=0 --esperar=3 --final=8; sleep 2
    lanzar Beto --n=2 --dx=-3 --dy=0 --esperar=3 --final=8
    sleep 75
    lanzar Cami --tarde --n=2 --dx=0 --dy=3 --esperar=3 --final=8 ;;
  *)
    lanzar Ana --jefe --n=2 --dx=3 --dy=0; sleep 2
    lanzar Beto --n=2 --dx=-3 --dy=0 ;;
esac
FALLOS=0
for i in "${!PIDS[@]}"; do
  wait "${PIDS[$i]}" || { echo "(${NOMBRES[$i]} terminó con error)"; FALLOS=$((FALLOS+1)); }
done
kill $SERVIDOR 2>/dev/null
for n in "${NOMBRES[@]}"; do echo "--- $n"; grep -E "^E2E" "$SALIDA/$n.txt"; done
echo "--- Servidor"; grep -iE "error|GAIA servidor" "$SALIDA/servidor.txt" | grep -v "BUG: Unreferenced" | head -5
echo "(salida completa en $SALIDA)"
# Cada uno debe ver a los demás donde cada uno dice que está (en «tarde», Ana y Beto ven además al tercero).
declare -A MI
for n in "${NOMBRES[@]}"; do
  MI[$n]=$(grep "$n FINAL" "$SALIDA/$n.txt" | grep -oE "mi=[-0-9]+,[-0-9]+" | cut -d= -f2)
done
for n in "${NOMBRES[@]}"; do
  ESPERADO=""
  for o in "${NOMBRES[@]}"; do
    [ "$o" = "$n" ] && continue
    ESPERADO+="${MI[$o]}"$'\n'
  done
  ESPERADO=$(printf "%s" "$ESPERADO" | sed '/^$/d' | sort | paste -sd'|')
  VISTO=$(grep "$n FINAL" "$SALIDA/$n.txt" | grep -oE "vistos=.*" | cut -d= -f2)
  echo "$n en ${MI[$n]} ve a los demás en [$VISTO]; esperado [$ESPERADO]"
  [ -n "${MI[$n]}" ] && [ "$VISTO" = "$ESPERADO" ] || FALLOS=$((FALLOS+1))
done
if [ "$FALLOS" = 0 ]; then echo "E2E_RED_OK ($MODO)"; exit 0; else echo "E2E_RED_FALLO ($MODO): $FALLOS problema(s)"; exit 1; fi
