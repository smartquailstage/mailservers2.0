FROM alpine:3.16

LABEL maintainer="your-email@example.com"

ENV container=docker \
    LC_ALL=C \
    TZ=America/Guayaquil

# 1. Instala dependencias necesarias para Postfix
RUN apk update && apk add --no-cache \
    postfix \
    postfix-pcre \
    postfix-pgsql \
    postfix-ldap \
    cyrus-sasl \
    bash \
    curl \
    openssl \
    iproute2 \
    postgresql-client \
    pcre \
    db \
    gdbm \
    tzdata \
    shadow

# 2. Configura zona horaria
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone



# 4. Copia archivos de configuración de Postfix
COPY postfix/ /etc/postfix/
COPY postfix/start.sh /usr/local/bin/start.sh
COPY postfix/sql/ /etc/postfix/sql/

# 5. Asegura permisos correctos
RUN chmod +x /usr/local/bin/start.sh \
    && mkdir -p /var/spool/postfix/private \
    && mkdir -p /var/mail/vhosts \
    && chown -R postfix:postfix /var/spool/postfix /etc/postfix \
    && chmod -R 750 /var/spool/postfix \
    && chown -R 1000:1000 /var/mail \
    && chmod 755 /var/mail \
    && chmod 700 /etc/ssl/private \
    && chown root:root /etc/ssl/certs /etc/ssl/private \
    && chmod 640 /etc/postfix/*.cf

# 6. Expone puertos necesarios
EXPOSE 25 465 587

# 7. Montaje opcional de volumen
VOLUME ["/var/mail"]

# 8. Entrypoint
ENTRYPOINT ["/usr/local/bin/start.sh"]