#!/usr/bin/env bash
# Publica en el VPS la web del proyecto (sitio/) y, si ya se subió, el juego exportado para web.
# Uso, con un usuario con sudo:   bash /opt/gaia/repo/deploy/servidor/nativo/publicar_sitios.sh
#   La web sale del repositorio (se actualiza con git pull). El juego sale de /tmp/gaia-juego, que se sube desde el PC con scp
#   (ver docs/SERVIDOR.md). No toca nada que no sea de GAIA.
set -euo pipefail
cd /opt/gaia/repo
git pull --ff-only
git lfs pull
sudo mkdir -p /var/www/gaia-sitio /var/www/gaia-juego
sudo rm -rf /var/www/gaia-sitio/*
sudo cp -a sitio/. /var/www/gaia-sitio/
echo "web del proyecto: $(ls /var/www/gaia-sitio | wc -l) elementos en /var/www/gaia-sitio"
if [ -f /tmp/gaia-juego/index.html ]; then
  sudo rm -rf /var/www/gaia-juego/*
  sudo cp -a /tmp/gaia-juego/. /var/www/gaia-juego/
  echo "juego: $(du -sh /var/www/gaia-juego | cut -f1) en /var/www/gaia-juego"
else
  echo "El juego todavía no está en /tmp/gaia-juego: súbelo desde el PC (docs/SERVIDOR.md) y vuelve a ejecutar este script."
fi
sudo chmod -R a+rX /var/www/gaia-sitio /var/www/gaia-juego
