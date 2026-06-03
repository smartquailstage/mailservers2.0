# ==========================================
# ETAPA 1: Compilar el DAEMON (Go) en un entorno moderno
# ==========================================
FROM golang:1.22-alpine AS go-builder
WORKDIR /tmp/dovecot-xaps-daemon
RUN apk add --no-cache git
RUN git clone --single-branch --depth=1 https://github.com/freswa/dovecot-xaps-daemon.git .
# Compilación ESTÁTICA (CGO_ENABLED=0) para que el binario funcione en cualquier Linux
RUN CGO_ENABLED=0 go build -v -o xapsd ./cmd/xapsd

# ==========================================
# ETAPA 2: Compilar el PLUGIN (C) en Debian 11
# ==========================================
FROM debian:11-slim AS c-builder
ARG DEBIAN_FRONTEND=noninteractive

ADD dovecot.gpg /etc/apt/keyrings/dovecot.gpg
ADD dovecot.list /etc/apt/sources.list.d

WORKDIR /tmp/dovecot-xaps-plugin
RUN apt-get update && apt-get -y --no-install-recommends install \
    git \
    cmake \
    make \
    build-essential \
    dovecot-dev \
    ca-certificates

RUN git clone --single-branch --depth=1 https://github.com/freswa/dovecot-xaps-plugin.git . && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make install

# ==========================================
# ETAPA 3: Tu contenedor original Dovecot de producción
# ==========================================
FROM debian:11-slim

LABEL org.opencontainers.image.authors="dovecot@dovecot.org"

ENV container=docker \
    LC_ALL=C
ARG DEBIAN_FRONTEND=noninteractive

ADD dovecot.gpg /etc/apt/keyrings/dovecot.gpg
ADD dovecot.list /etc/apt/sources.list.d

RUN apt-get -y update && apt-get -y install \
  tini \
  dovecot-core \
  dovecot-gssapi \
  dovecot-imapd \
  dovecot-ldap \
  dovecot-lmtpd \
  dovecot-lua \
  dovecot-managesieved \
  dovecot-mysql \
  dovecot-pgsql \
  dovecot-pop3d \
  dovecot-sieve \
  dovecot-solr \
  dovecot-sqlite \
  dovecot-submissiond \
  ca-certificates \
  ssl-cert && \
  rm -rf /var/lib/apt/lists && \
  groupadd -g 1000 vmail && \
  useradd -u 1000 -g 1000 vmail -d /var/mail/vmail -m && \
  passwd -l vmail && \
  rm -rf /etc/dovecot && \
  mkdir -p /var/mail && \
  chmod 755 /var/mail && \
  make-ssl-cert generate-default-snakeoil && \
  mkdir /etc/dovecot && \
  ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/dovecot/cert.pem && \
  ln -s /etc/ssl/private/ssl-cert-snakeoil.key /etc/dovecot/key.pem

ADD dovecot.conf /etc/dovecot/dovecot.conf
COPY dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext
COPY start.sh /start.sh
RUN chmod +x /start.sh

RUN mkdir -p /var/mail/vhosts && \
    chown -R vmail:vmail /var/mail && \
    chmod -R 700 /var/mail

# -----------------------------------------------------------------
# INYECCIÓN DE COMPONENTES XAPS (Extracción Multi-Etapa)
# -----------------------------------------------------------------
# 1. Copiar los módulos (.so) del plugin IMAP (Desde c-builder)
COPY --from=c-builder /usr/lib/dovecot/modules/*_xaps_* /usr/lib/dovecot/modules/

# 2. Copiar el archivo de configuración por defecto (Desde c-builder)
COPY --from=c-builder /tmp/dovecot-xaps-plugin/xaps.conf /etc/dovecot/conf.d/95-xaps.conf

# 3. Copiar el binario ejecutable del Demonio XAPS (Desde go-builder)
COPY --from=go-builder /tmp/dovecot-xaps-daemon/xapsd /usr/bin/xapsd

# Crear usuario seguro para el demonio xapsd y sus directorios de estado
RUN adduser --system --group --disabled-password --home /var/mail-state/lib-xapsd --no-create-home xapsd && \
    mkdir -p /var/run/xapsd /etc/xapsd /var/run/dovecot && \
    chown -R xapsd:xapsd /var/run/xapsd /etc/xapsd

# Puertos expuestos originales
EXPOSE 24 110 143 587 990 993 4190

VOLUME ["/etc/dovecot", "/var/mail"]

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/start.sh"]