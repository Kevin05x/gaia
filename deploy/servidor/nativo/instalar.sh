#!/usr/bin/env bash
# Instala el servidor de la sala de GAIA en un VPS que YA tiene su propio Caddy (sin Docker). No toca nada que ya exista:
# todo va en /opt/gaia y en un servicio nuevo llamado gaia-sala. Uso (con un usuario con sudo):
#   bash instalar.sh [rama]        # por defecto c/mejoras-15nov
# Después hay que añadir el bloque de Caddy (ver docs/SERVIDOR.md, «Servidor con Caddy propio»).
set -euo pipefail
RAMA="${1:-c/mejoras-15nov}"
GODOT=4.7.2
sudo apt-get install -y git git-lfs unzip curl
sudo mkdir -p /opt/gaia
sudo chown "$USER":"$USER" /opt/gaia
cd /opt/gaia
if [ ! -d repo ]; then
  git clone -b "$RAMA" https://github.com/Kevin05x/gaia.git repo
fi
cd repo
git lfs install --local
git fetch origin "$RAMA"
git checkout "$RAMA"
git pull --ff-only origin "$RAMA"
git lfs pull
cd ..
if [ ! -x godot ]; then
  curl -fsSL -o godot.zip "https://github.com/godotengine/godot-builds/releases/download/${GODOT}-stable/Godot_v${GODOT}-stable_linux.x86_64.zip"
  unzip -q -o godot.zip
  mv "Godot_v${GODOT}-stable_linux.x86_64" godot
  rm godot.zip
  chmod +x godot
fi
./godot --headless --path repo --import || true
sed "s/__USUARIO__/$USER/" repo/deploy/servidor/nativo/gaia-sala.service | sudo tee /etc/systemd/system/gaia-sala.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now gaia-sala
sleep 4
systemctl --no-pager --lines=15 status gaia-sala || true
echo "Listo. Comprueba que el servicio escucha:  ss -tln | grep 9080"
