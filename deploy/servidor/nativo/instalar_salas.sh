#!/usr/bin/env bash
# Pasa de una sala (gaia-sala) a cuatro (gaia-sala@9080 a @9083). No toca nada más del servidor. Uso, con un usuario con sudo:
#   bash /opt/gaia/repo/deploy/servidor/nativo/instalar_salas.sh
set -euo pipefail
cd /opt/gaia/repo
git pull --ff-only
git lfs pull
sed "s/__USUARIO__/$USER/" deploy/servidor/nativo/gaia-sala@.service | sudo tee /etc/systemd/system/gaia-sala@.service > /dev/null
sudo systemctl daemon-reload
if systemctl list-unit-files | grep -q '^gaia-sala.service'; then
  sudo systemctl disable --now gaia-sala  # la sala única de antes: su puerto 9080 pasa a la instancia @9080
fi
for puerto in 9080 9081 9082 9083; do
  sudo systemctl enable --now "gaia-sala@$puerto"
done
sleep 4
for puerto in 9080 9081 9082 9083; do
  ss -tln | grep -q ":$puerto " && echo "sala en el puerto $puerto: OK" || echo "sala en el puerto $puerto: NO ESCUCHA"
done
