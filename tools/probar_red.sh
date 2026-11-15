#!/usr/bin/env bash
# Prueba de la red de punta a punta, sin pantallas: un servidor dedicado y cuatro jugadores automáticos (uno por rol)
# juegan una misión corta. Uso: tools/probar_red.sh [ruta-a-godot] [puerto] [servidor|lan]
#   servidor (por defecto): servidor dedicado + 4 jugadores. lan: uno de los jugadores es el anfitrión y juega.
set -u
GODOT="${1:-godot}"
PUERTO="${2:-9191}"
MODO="${3:-servidor}"
LOG="$(mktemp -d)"
SERV=""
if [ "$MODO" = "servidor" ]; then
	"$GODOT" --headless --path . scenes/net/servidor.tscn -- --servidor --puerto="$PUERTO" > "$LOG/servidor.log" 2>&1 &
	SERV=$!
	sleep 3
fi
BOTS=()
for n in Ana Beto Cleo Dani; do
	extra=""
	[ "$n" = "Ana" ] && extra="--jefe --esperar=4"
	[ "$n" = "Ana" ] && [ "$MODO" = "lan" ] && extra="$extra --anfitrion --puerto=$PUERTO --demora=10"
	"$GODOT" --headless --path . -s tools/bot_red.gd -- --dir=127.0.0.1:"$PUERTO" --nombre="$n" $extra > "$LOG/$n.log" 2>&1 &
	BOTS+=($!)
	sleep 1.2
done
for p in "${BOTS[@]}"; do wait "$p"; done
[ -n "$SERV" ] && kill "$SERV" 2>/dev/null
grep -h "^RES" "$LOG"/*.log | sort
echo "registros en $LOG"
