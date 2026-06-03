# ==========================================
# ETAPA 1: Compilar el Plugin para tu Debian 11
# ==========================================
FROM debian:11-slim AS dovecot-plugin-xaps
ARG DEBIAN_FRONTEND=noninteractive

# Añadir los mismos repositorios de Dovecot que usa tu contenedor final
ADD dovecot.gpg /etc/apt/keyrings/dovecot.gpg
ADD dovecot.list /etc/apt/sources.list.d

WORKDIR /tmp/dovecot-xaps-plugin
RUN apt-get update && apt-get -y --no-install-recommends install \
    git \
    cmake \
    make \
    build-essential \
    dovecot-dev && \
    git clone --single-branch --depth=1 https://github.com/freswa/dovecot-xaps-plugin.git . && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make install

# ==========================================
# ETAPA 2 CORREGIDA: Compilar el Demonio en Go usando Debian
# ==========================================
FROM golang:1.19-bullseye AS dovecot-xaps-daemon
WORKDIR /go/dovecot-xaps-daemon
RUN apt-get update && apt-get install -y git && \
    git clone --single-branch --depth=1 https://github.com/freswa/dovecot-xaps-daemon . && \
    go build ./cmd/xapsd

# ==========================================
# ETAPA 3: Tu contenedor original Dovecot
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

# ------------------------------------------
# INYECCIÓN DEL PLUGIN XAPS (Agregado aquí)
# ------------------------------------------
# Copiar las librerías compiladas en la Etapa 1
COPY --from=dovecot-plugin-xaps /usr/lib/dovecot/modules/*_xaps_* /usr/lib/dovecot/modules/
# Copiar el ejecutable del demonio generado en la Etapa 2
COPY --from=dovecot-xaps-daemon /go/dovecot-xaps-daemon/xapsd /usr/bin/xapsd

# Crear usuario xapsd y sus directorios requeridos
RUN adduser --system --group --disabled-password --home /var/mail-state/lib-xapsd --no-create-home xapsd && \
    mkdir -p /var/run/xapsd /etc/xapsd && \
    chown -R xapsd:xapsd /var/run/xapsd /etc/xapsd

# Puertos originales de tu contenedor
EXPOSE 24 110 143 587 990 993 4190

VOLUME ["/etc/dovecot", "/var/mail"]

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/start.sh"]