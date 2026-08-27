#!/bin/sh
# Prepara MyAAC la primera vez y despues levanta Apache.
#
# Las dependencias (vendor/ de composer y tools/ext/ de npm) se bajan
# ADENTRO de la carpeta montada web/myaac, no de la imagen. Asi quedan
# guardadas en el disco de Windows y solo se bajan una vez, aunque
# despues se reconstruya el contenedor.
set -e

cd /var/www/html

echo "=========================================="
echo "  TVP3D - pagina web (MyAAC)"
echo "=========================================="

if [ ! -f .htaccess ]; then
	echo ">> Copiando .htaccess.dist a .htaccess"
	cp .htaccess.dist .htaccess
fi

if [ ! -f vendor/autoload.php ]; then
	echo ">> Bajando las librerias de PHP (composer). Tarda unos minutos, SOLO la primera vez..."
	composer install --no-interaction --no-progress --optimize-autoloader
	echo ">> Librerias de PHP listas."
fi

# El instalador de MyAAC exige que exista tools/ext (jquery, bootstrap,
# tinymce). Esa carpeta la llena npm, no composer.
if [ ! -d tools/ext/jquery ]; then
	echo ">> Bajando jquery/bootstrap/tinymce (npm). Tarda unos minutos, SOLO la primera vez..."
	npm install --omit=dev --no-audit --no-fund
	echo ">> Listo."
fi

# Apache corre como www-data: necesita poder escribir la configuracion,
# el cache, los logs y las imagenes que suben los jugadores.
mkdir -p system/cache system/logs images/guilds images/gallery
chown -R www-data:www-data system/cache system/logs images/guilds images/gallery install
chown www-data:www-data . 2>/dev/null || true
[ -f config.local.php ] && chown www-data:www-data config.local.php

echo ">> Web lista en http://localhost:8072"
exec "$@"
