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
sudo mkdir -p /var/www/gaia-sitio/descargas
sudo find /var/www/gaia-sitio -mindepth 1 -maxdepth 1 ! -name descargas -exec rm -rf {} +  # la carpeta descargas (el .zip de Windows) se conserva
sudo cp -a sitio/. /var/www/gaia-sitio/
sudo rm -f /var/www/gaia-sitio/.gdignore
echo "web del proyecto: $(ls /var/www/gaia-sitio | wc -l) elementos en /var/www/gaia-sitio"
if [ -f /tmp/gaia-juego/index.html ]; then
  sudo rm -rf /var/www/gaia-juego/*
  sudo cp -a /tmp/gaia-juego/. /var/www/gaia-juego/
  # la exportación trae archivos .import que el navegador no necesita
  sudo find /var/www/gaia-juego -name "*.import" -delete
  # robots.txt y sitemap.xml para los buscadores (el rm de arriba los borra en cada publicación)
  sudo cp deploy/servidor/nativo/juego_robots.txt /var/www/gaia-juego/robots.txt
  sudo cp deploy/servidor/nativo/juego_sitemap.xml /var/www/gaia-juego/sitemap.xml
  echo "juego: $(du -sh /var/www/gaia-juego | cut -f1) en /var/www/gaia-juego"
else
  echo "El juego todavía no está en /tmp/gaia-juego: súbelo desde el PC (docs/SERVIDOR.md) y vuelve a ejecutar este script."
fi
# El juego para Windows (unos 120 MB) se sube desde el PC con scp a /tmp/gaia-descargas y queda en https://info.gaianasa.tech/descargas/
if [ -f /tmp/gaia-descargas/GAIA_Windows.zip ]; then
  sudo cp /tmp/gaia-descargas/GAIA_Windows.zip /var/www/gaia-sitio/descargas/GAIA_Windows.zip
  echo "descarga de Windows: $(du -h /var/www/gaia-sitio/descargas/GAIA_Windows.zip | cut -f1)"
elif [ ! -f /var/www/gaia-sitio/descargas/GAIA_Windows.zip ]; then
  echo "Todavía no hay descarga de Windows: súbela desde el PC con scp (docs/SERVIDOR.md)."
fi
sudo chmod -R a+rX /var/www/gaia-sitio /var/www/gaia-juego
