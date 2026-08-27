# Pagina web de TVP3D: MyAAC sobre PHP 8.3 + Apache.
#
# Ojo: el codigo de MyAAC NO va adentro de la imagen. Se monta desde
# web/myaac (ver docker-compose.yml) para que se pueda editar sin
# reconstruir nada. Lo que si vive aca son PHP, Apache, composer y node.

FROM php:8.3-apache

# Extensiones que pide el instalador de MyAAC:
#   obligatorias -> pdo, pdo_mysql, json, xml
#   opcionales   -> gd (firmas de personaje), zip (instalar plugins)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpng-dev libjpeg62-turbo-dev libfreetype6-dev libzip-dev \
        unzip git ca-certificates nodejs npm \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" pdo_mysql gd zip opcache \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# MyAAC manda todo por index.php con su .htaccess, asi que Apache tiene
# que hacerle caso (por defecto la imagen viene con AllowOverride None).
RUN printf '%s\n' \
    '<Directory /var/www/html>' \
    '    Options -Indexes +FollowSymLinks' \
    '    AllowOverride All' \
    '    Require all granted' \
    '</Directory>' \
    > /etc/apache2/conf-available/tvp3d.conf \
    && a2enconf tvp3d

RUN printf '%s\n' \
    'memory_limit = 512M' \
    'upload_max_filesize = 16M' \
    'post_max_size = 16M' \
    'max_execution_time = 300' \
    'date.timezone = America/Guatemala' \
    > /usr/local/etc/php/conf.d/tvp3d.ini

COPY arranque.sh /usr/local/bin/arranque.sh
RUN chmod +x /usr/local/bin/arranque.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/arranque.sh"]
CMD ["apache2-foreground"]
