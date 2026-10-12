#!/bin/sh

USER="vmail"
GROUP="vmail"
MAIL_DIR="/var/mail"
MAILDIR_STRUCTURE="$MAIL_DIR/vhosts/smartquail.io/support/Maildir"

mkdir -p "$MAIL_DIR"

echo "Setting ownership for $MAIL_DIR"
chown -R $USER:$GROUP "$MAIL_DIR"

# Asegurar permisos correctos en la raíz (/var/mail debe permitir atravesarlo con +x)
chmod 755 "$MAIL_DIR"

mkdir -p "$MAILDIR_STRUCTURE/cur" "$MAILDIR_STRUCTURE/new" "$MAILDIR_STRUCTURE/tmp"

echo "Setting permissions and ownership for the Maildir structure: $MAILDIR_STRUCTURE"
chown -R $USER:$GROUP "$MAIL_DIR/vhosts"
chmod 755 "$MAIL_DIR/vhosts"
chmod 755 "$MAIL_DIR/vhosts/smartquail.io"
chmod 755 "$MAIL_DIR/vhosts/smartquail.io/support"

# El Maildir personal debe ser estrictamente privado (700)
chmod 700 "$MAILDIR_STRUCTURE"

echo "Adjusting permissions inside Maildir (cur, new, tmp)"
find "$MAILDIR_STRUCTURE" -type d -exec chmod 700 {} \;
find "$MAILDIR_STRUCTURE" -type f -exec chmod 600 {} \;

# **Garantizar permisos de lectura y ejecución (+rx) en todos los directorios padres para el grupo/propietario**
echo "Ensuring +x permissions on all parent directories under $MAIL_DIR"
find "$MAIL_DIR" -type d -exec chmod u+rwx,g+rx,o-rx {} \;

echo "Verification of permissions and ownership:"
ls -ld "$MAIL_DIR"
ls -ld "$MAILDIR_STRUCTURE"
ls -ld "$MAILDIR_STRUCTURE/cur"
ls -ld "$MAILDIR_STRUCTURE/new"
ls -ld "$MAILDIR_STRUCTURE/tmp"

# Ejecutar Dovecot como proceso principal (PID 1)
exec dovecot -F