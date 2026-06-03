FROM mailserver/docker-mailserver:edge AS dovecot-plugin-xaps
WORKDIR /tmp/dovecot-xaps-plugin
RUN <<EOF
    apt-get update
    apt-get -y --no-install-recommends install git cmake make build-essential dovecot-dev
    git clone --single-branch --depth=1 https://github.com/freswa/dovecot-xaps-plugin.git .
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make install
EOF

# Use an older Go version as Go >= 1.20 causes this issue: https://github.com/freswa/dovecot-xaps-daemon/issues/24#issuecomment-1483876081
# Note that the underlying issue are non-standard-compliant Apple http servers which might get fixed at some point
FROM golang:1.19-alpine AS dovecot-xaps-daemon
ENV GOPROXY=https://proxy.golang.org,direct
ENV CGO_ENABLED=0
WORKDIR /go/dovecot-xaps-daemon
RUN <<EOF
    apk add --no-cache --virtual build-dependencies git
    git clone --single-branch --depth=1 https://github.com/freswa/dovecot-xaps-daemon .
    go build ./cmd/xapsd
EOF

FROM mailserver/docker-mailserver:edge
COPY --from=dovecot-plugin-xaps /usr/lib/dovecot/modules/*_xaps_* /usr/lib/dovecot/modules/
COPY --from=dovecot-xaps-daemon /go/dovecot-xaps-daemon/xapsd /usr/bin/xapsd

# create a non-root user for the daemon process as well as configuration and run state directories
RUN <<EOF
    adduser --quiet --system --group --disabled-password --home /var/mail-state/lib-xapsd --no-create-home xapsd
    mkdir -p /var/run/xapsd /etc/xapsd
EOF