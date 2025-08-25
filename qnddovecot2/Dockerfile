FROM debian:12-slim as production

LABEL org.opencontainers.image.authors="dovecot@dovecot.org"

ENV container=docker \
    LC_ALL=C.UTF-8 TZ=UTC
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/dovecot/lib
ENV PATH $PATH:/dovecot/bin:/dovecot/sbin
ARG DEBIAN_FRONTEND=noninteractive
ARG VMAIL_UID=1000
ARG VMAIL_GID=1000

COPY --link --from=build /dovecot /dovecot

RUN apt-get -y update && \
  apt-get -y install --no-install-recommends \
  tini \
  pkg-config \
  ssl-cert \
  ucf \
  libldap-2.5-0 \
  openssl \
  libsodium23 \
  libbz2-1.0 \
  libcrypt1 \
  libexttextcat-2.0-0 \
  libexttextcat-data \
  liblua5.3-0 \
  liblz4-1 \
  liblzma5 \
  libssl3 \
  libstemmer0d \
  libtirpc3 \
  libunwind8 \
  libwrap0 \
  libzstd1 \
  zlib1g \
  libgssapi-krb5-2 \
  libkrb5-3 \
  libxapian30 \
  libmariadb3 \
  libpq5 \
  libexpat1 \
  libsqlite3-0 \
  libicu72 \
  libcap2 \
  libcap2-bin \
  netcat-traditional \
  ca-certificates && \
 rm -rf /etc/dovecot && \
 rm -rf /var/lib/apt/lists && \
 groupadd -g $VMAIL_GID vmail && \
 useradd -u $VMAIL_UID -g vmail -G ssl-cert -d /srv/mail -s /bin/sh vmail && \
 passwd -l vmail && \
 mkdir -p /run && \
 chmod 1777 /run && \
 mkdir -p /tmp && \
 chmod 1777 /tmp && \
 mkdir /etc/dovecot && \
 mkdir /etc/dovecot/conf.d && \
 mkdir /etc/dovecot/ssl && \
 mkdir /srv/vmail -p && \
 mkdir /var/lib/dovecot && \
 chown vmail:vmail /var/lib/dovecot && \
 chown vmail:vmail /srv/vmail && \
 chmod 0770 /var/lib/dovecot && \
 chmod 0700 /srv/vmail && \
 make-ssl-cert generate-default-snakeoil && \
 ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/dovecot/ssl/tls.crt && \
 ln -s /etc/ssl/private/ssl-cert-snakeoil.key /etc/dovecot/ssl/tls.key && \
 chown root:vmail /etc/dovecot/ssl/tls.key && \
 chmod 0440 /etc/dovecot/ssl/tls.key && \
 setcap cap_sys_chroot+ep /dovecot/libexec/dovecot/script-login && \
 setcap cap_sys_chroot+ep /dovecot/libexec/dovecot/imap-urlauth-login && \
 setcap cap_sys_chroot+ep /dovecot/libexec/dovecot/submission-login && \
 setcap cap_sys_chroot+ep /dovecot/libexec/dovecot/managesieve-login && \
 setcap cap_sys_chroot+ep /dovecot/libexec/dovecot/pop3-login && \
 setcap cap_sys_chroot+ep /dovecot/libexec/dovecot/imap-login && \
 setcap cap_sys_chroot+ep /dovecot/libexec/dovecot/lmtp && \
 setcap cap_sys_chroot+ep /dovecot/libexec/dovecot/anvil && \
 setcap cap_sys_chroot+ep /dovecot/libexec/dovecot/managesieve-login && \
 apt remove --allow-remove-essential -yq \
  bash \
  pkg-config \
  util-linux \
  util-linux-extra \
  e2fsprogs \
  perl \
  perl-base \
  libcap2-bin && \
 ln -srf /bin/true /usr/share/debconf/frontend && \
 dpkg --remove --force-remove-essential --force-depends apt dpkg gzip diffutils findutils init-system-helpers sysvinit-utils coreutils mount

COPY dovecot.conf /etc/dovecot/dovecot.conf

EXPOSE 31024
EXPOSE 31110
EXPOSE 31143
EXPOSE 31587
EXPOSE 31990
EXPOSE 31993
EXPOSE 34190
EXPOSE 8080
EXPOSE 9090
USER vmail
VOLUME ["/srv/mail"]
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/dovecot/sbin/dovecot", "-F"]
