# Dockerfile for Postfix with OpenDKIM
FROM alpine:3.16

LABEL maintainer="your-email@example.com"





ENV container=docker \
    LC_ALL=C \
    TZ=America/Guayaquil


# Install Postfix, OpenDKIM and necessary dependencies
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
    opendkim 


# Create postfix, vmail, and opendkim users and groups if they do not exist
RUN addgroup -g 1001 postfix || true \
    && adduser -D -u 1001 -G postfix -s /sbin/nologin postfix || true \
    && addgroup -g 1002 vmail || true \
    && adduser -D -u 1002 -G vmail -s /sbin/nologin vmail || true \
    && addgroup -g 1003 opendkim || true \
    && adduser -D -u 1003 -G opendkim -s /sbin/nologin opendkim || true

# Create necessary directories and set permissions
RUN mkdir -p /var/run/dovecot/ /var/spool/postfix/private \
    && mkdir -p /etc/opendkim /etc/ssl/certs /etc/ssl/private \
    # Set ownership and permissions for /var/spool/dovecot
    && chown -R postfix:postfix /var/run/dovecot \
    && chmod 750 /var/run/dovecot/ \

    # Set ownership and permissions for /var/spool/postfix
    && chown -R postfix:postfix /var/spool/postfix \
    && chmod 750 /var/spool/postfix/private \
    && chmod 750 /var/spool/postfix \
    # Set ownership and permissions for /var/mail
    && mkdir -p /var/mail \
    && chown -R vmail:vmail /var/mail \
    && chmod 700 /var/mail \
    # Set permissions for SSL certificates
    && chmod 700 /etc/ssl/private \
    && chown root:root /etc/ssl/certs /etc/ssl/private \
    # Set permissions for OpenDKIM
    && chown -R opendkim:opendkim /etc/opendkim

# Copy configuration files
COPY postfix/transport.pcre /etc/postfix/transport.pcre
COPY postfix/virtual /etc/postfix/virtual
COPY postfix/main.cf /etc/postfix/main.cf
COPY postfix/master.cf /etc/postfix/master.cf
COPY postfix/sasl_passwd /etc/postfix/
COPY postfix /etc/postfix
#Copy Opendkim
COPY opendkim/opendkim.conf /etc/opendkim/opendkim.conf 
COPY opendkim/KeyTable /etc/opendkim/KeyTable  
COPY opendkim/SigningTable /etc/opendkim/SigningTable
COPY opendkim/TrustedHosts /etc/opendkim/TrustedHosts  

ENV TZ=America/Guayaquil

RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone




# Expose the necessary ports for SMTP, secure connections and OpenDKIM
EXPOSE 25 465 587 8891

# Define the volume
VOLUME ["/var/mail/"]

# Define entrypoint script to start both OpenDKIM and Postfix
COPY postfix/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

ENTRYPOINT ["/usr/local/bin/start.sh"]
