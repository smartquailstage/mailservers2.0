# ==========================================
# ETAPA 1: Compilar el demonio con Go 1.19
# ==========================================
FROM golang:1.19-alpine AS go-builder
ENV GOPROXY=https://proxy.golang.org,direct
ENV CGO_ENABLED=0
WORKDIR /go/dovecot-xaps-daemon

RUN apk add --no-cache git && \
    git clone --single-branch --depth=1 https://github.com/freswa/dovecot-xaps-daemon . && \
    go build ./cmd/xapsd

# ==========================================
# ETAPA 2: Imagen final ligera para el Sidecar
# ==========================================
FROM alpine:3.18
COPY --from=go-builder /go/dovecot-xaps-daemon/xapsd /usr/bin/xapsd

# Crear el usuario xapsd y asegurar directorios compartidos
RUN adduser --quiet --system --group --disabled-password --home /var/mail-state/lib-xapsd --no-create-home xapsd && \
    mkdir -p /var/run/xapsd /etc/xapsd /var/run/dovecot && \
    chown -R xapsd:xapsd /var/run/xapsd /etc/xapsd /var/run/dovecot

# Ejecutar como usuario no-root por seguridad
USER xapsd

CMD ["/usr/bin/xapsd", "-config", "/etc/xapsd/xapsd.json"]