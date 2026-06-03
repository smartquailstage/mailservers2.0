# ==========================================
# ETAPA 1: Compilar el Plugin (C) y el Demonio (Go)
# ==========================================
FROM debian:11-slim AS builder
ARG DEBIAN_FRONTEND=noninteractive

# Instalar repositorios de Dovecot correspondientes a tu versión
ADD dovecot.gpg /etc/apt/keyrings/dovecot.gpg
ADD dovecot.list /etc/apt/sources.list.d

# Instalar TODAS las dependencias de compilación exigidas por la documentación
RUN apt-get update && apt-get -y --no-install-recommends install \
    git \
    cmake \
    make \
    build-essential \
    dovecot-dev \
    golang-go \
    ca-certificates

# 1. Clonar y Compilar el PLUGIN de Dovecot (C)
WORKDIR /tmp/dovecot-xaps-plugin
RUN git clone --single-branch --depth=1 https://github.com/freswa/dovecot-xaps-plugin.git . && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make install

# 2. Clonar y Compilar el DAEMON (Go) usando el entorno nativo de compilación de Debian
WORKDIR /tmp/dovecot-xaps-daemon
RUN git clone --single-branch --depth=1 https://github.com/freswa/dovecot-xaps-daemon.git . && \
    go build -v -o xapsd ./cmd/xapsd


# ==========================================
# ETAPA 2: Tu contenedor de producción Dovecot
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
# INYECCIÓN DE COMPONENTES XAPS (Extraídos de la etapa Builder)
# -----------------------------------------------------------------
# Copiar los módulos (.so) del plugin IMAP de XAPS a la ruta de Dovecot
COPY --from=builder /usr/lib/dovecot/modules/*_xaps_* /usr/lib/dovecot/modules/

# Copiar el archivo de configuración por defecto que menciona la documentación
COPY --from=builder /tmp/dovecot-xaps-plugin/xaps.conf /etc/dovecot/conf.d/95-xaps.conf

# Copiar el binario ejecutable del Demonio XAPS
COPY --from=builder /tmp/dovecot-xaps-daemon/xapsd /usr/bin/xapsd

# Crear usuario seguro para el demonio aislado xapsd y sus directorios de estado
RUN adduser --system --group --disabled-password --home /var/mail-state/lib-xapsd --no-create-home xapsd && \
    mkdir -p /var/run/xapsd /etc/xapsd /var/run/dovecot && \
    chown -R xapsd:xapsd /var/run/xapsd /etc/xapsd

# Puertos expuestos originales
EXPOSE 24 110 143 587 990 993 4190

VOLUME ["/etc/dovecot", "/var/mail"]

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/start.sh"]