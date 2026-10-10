FROM debian:11-slim

LABEL org.opencontainers.image.authors="dovecot@dovecot.org"

ENV container=docker \
    LC_ALL=C
ARG DEBIAN_FRONTEND=noninteractive

# Si necesitas usar los repositorios nativos de Debian (Recomendado):
RUN apt-get update && apt-get install -y --fix-missing \
    -o Acquire::Retries=3 \
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
    rm -rf /var/lib/apt/lists/* && \
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

EXPOSE 24 110 143 587 990 993 4190

VOLUME ["/etc/dovecot", "/var/mail"]

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/start.sh"]