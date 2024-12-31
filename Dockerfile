FROM composer:2.5.8 AS composer
ARG CHECKOUT=1.7.0

RUN git clone https://github.com/sbpp/sourcebans-pp.git && \
    git -C sourcebans-pp checkout ${CHECKOUT} && \
    composer install --no-dev --no-interaction --no-progress --optimize-autoloader --ignore-platform-reqs --working-dir=sourcebans-pp/web/

# Build the actual image
FROM php:8.1-fpm

ENV INSTALL=false \
    SET_OWNER_UID=33 \
    SET_OWNER_GID=33 \
    SET_OWNER=true

RUN savedAptMark="$(apt-mark showmanual)" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libgmp-dev \
        nginx \
    && \
    rm -rf /var/lib/apt/lists/* && \
    docker-php-ext-configure gmp && \
    docker-php-ext-install gmp mysqli pdo_mysql bcmath && \
    apt-mark auto '.*' > /dev/null && \
    apt-mark manual $savedAptMark && \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

RUN mkdir /docker/ && \
    mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini && \
    sed -i 's/listen = 127.0.0.1:9000/listen = 9000/g' /usr/local/etc/php-fpm.d/www.conf

COPY --from=composer /app/sourcebans-pp/web /usr/src/sourcebans
COPY docker-sourcebans-entrypoint.sh /docker/docker-sourcebans-entrypoint.sh
COPY sourcebans.ini /usr/local/etc/php/conf.d/sourcebans.ini
COPY nginx.conf /etc/nginx/nginx.conf
COPY sourcebans-site.conf /etc/nginx/conf.d/default.conf

RUN chmod +x /docker/docker-sourcebans-entrypoint.sh

ENTRYPOINT ["/docker/docker-sourcebans-entrypoint.sh"]
CMD ["php-fpm"]
