FROM php:8.3-apache
LABEL maintainer="David Goodwin <david@codepoets.co.uk> (@DavidGoodwin)"

ENV TZ=America/Guayaquil

# Configura la zona horaria
RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    apt-get update && \
    apt-get install -y tzdata && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

# docker-entrypoint.sh dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        gosu \
    ; \
    rm -rf /var/lib/apt/lists/*

RUN set -ex; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libc-client2007e-dev \
        libkrb5-dev \
        libpq-dev \
        libsqlite3-dev \
    ; \
    docker-php-ext-configure imap --with-imap-ssl --with-kerberos; \
    docker-php-ext-install -j "$(nproc)" \
        imap \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        pgsql; \
    \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    \
    # Detectar librerías utilizadas por extensiones PHP y evitar purgar sus dependencias
    find "$(php -r 'echo ini_get("extension_dir");')" -name '*.so' | while read -r so; do \
        ldd "$so" | awk '/=>/ { print $(NF-1) }'; \
    done | \
        grep -v '^/usr/local/' | \
        xargs -r -n1 dpkg-query -S 2>/dev/null | \
        cut -d: -f1 | \
        sort -u | \
        xargs -r -n1 apt-mark manual 2>/dev/null || true; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*



# Variables para PostfixAdmin
ARG POSTFIXADMIN_VERSION=3.3.15
ARG POSTFIXADMIN_SHA512=02c4a7fb0d5b148a2f9e73e0278a47d1ee63b29a0019cf510f04d33386fc50727c0dae728eafee688a136159ba462af1931fe0658daa06671459c43668867865

ENV POSTFIXADMIN_VERSION $POSTFIXADMIN_VERSION
ENV POSTFIXADMIN_SHA512 $POSTFIXADMIN_SHA512
ENV APACHE_DOCUMENT_ROOT /var/www/html/public

# Cambiar el DocumentRoot de Apache
RUN set -eu; \
    sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf; \
    sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Descarga y prepara PostfixAdmin
RUN set -eu; \
    curl -fsSL -o postfixadmin.tar.gz "https://github.com/postfixadmin/postfixadmin/archive/postfixadmin-${POSTFIXADMIN_VERSION}.tar.gz"; \
    echo "$POSTFIXADMIN_SHA512 *postfixadmin.tar.gz" | sha512sum -c -; \
    mkdir /usr/src/postfixadmin; \
    tar -xf postfixadmin.tar.gz -C /usr/src/postfixadmin --strip-components=1; \
    rm postfixadmin.tar.gz; \
    mkdir -p /usr/src/postfixadmin/templates_c; \
    chown -R www-data:www-data /usr/src/postfixadmin

# Copiar scripts de configuración
COPY docker-entrypoint.sh /usr/local/bin/
COPY config.local.php /var/www/html/config.local.php

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
