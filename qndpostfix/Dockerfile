FROM alpine:3.16

LABEL maintainer="your-email@example.com"

ENV container=docker \
    LC_ALL=C \
    TZ=America/Guayaquil



# 1. Instala dependencias
RUN apk update && apk add --no-cache \
    postfix \
    postfix-pcre \
    postfix-pgsql \
    cyrus-sasl \
    bash \
    curl \
    openssl \
    iproute2 \
    postfix-ldap \
    postgresql-client \
    pcre \
    db \
    gdbm \
    opendkim \
    opendkim-utils \ 
    tzdata \
    shadow

# 2. Configura zona horaria
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 3. Crea usuarios y grupos si no existen
RUN addgroup -g 1001 postfix || true \
    && adduser -D -u 1001 -G postfix -s /sbin/nologin postfix || true \
    && addgroup -g 1002 vmail || true \
    && adduser -D -u 1002 -G vmail -s /sbin/nologin vmail || true \
    && addgroup -g 1003 opendkim || true \
    && adduser -D -u 1003 -G opendkim -s /sbin/nologin opendkim || true

# Crear directorio para socket de OpenDKIM y asignar permisos
RUN mkdir -p /var/spool/postfix/opendkim \
    && chown opendkim:postfix /var/spool/postfix/opendkim \
    && chmod 770 /var/spool/postfix/opendkim

# Crear directorio para socket de OpenDKIM y asignar permisos
RUN mkdir -p /var/spool/postfix/opendkim \
    && chown opendkim:postfix /var/spool/postfix/opendkim \
    && chmod 770 /var/spool/postfix/opendkim \
    # Crear directorio para PID de OpenDKIM
    && mkdir -p /var/run/opendkim \
    && chown opendkim:opendkim /var/run/opendkim \
    && chmod 750 /var/run/opendkim



# 4. Copia primero los archivos de configuración
COPY postfix/ /etc/postfix/
COPY postfix/start.sh /usr/local/bin/start.sh
COPY postfix/sql/ /etc/postfix/sql/
COPY opendkim/ /etc/opendkim/

# 5. Asegura permisos correctos
RUN chmod +x /usr/local/bin/start.sh \
    && mkdir -p /var/spool/postfix/private \
    && mkdir -p /var/mail/vhosts \
    && chown -R postfix:postfix /var/spool/postfix /etc/postfix \
    && chmod -R 750 /var/spool/postfix \
    && chown -R vmail:vmail /var/mail \
    && chmod -R 700 /var/mail \
    && chown -R opendkim:opendkim /etc/opendkim \
    && chmod 700 /etc/ssl/private \
    && chown root:root /etc/ssl/certs /etc/ssl/private \
    && chmod 640 /etc/postfix/*.cf

# 6. Expone puertos necesarios
EXPOSE 25 465 587 8891

# 7. Montaje opcional de volumen
VOLUME ["/var/mail"]

# 8. Entrypoint
ENTRYPOINT ["/usr/local/bin/start.sh"]
