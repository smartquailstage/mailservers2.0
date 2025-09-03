#!/bin/sh

USER="vmail"
GROUP="vmail"
MAIL_DIR="/var/mail"
MAILDIR_STRUCTURE="$MAIL_DIR/vhosts/smartquail.io/support/Maildir"

mkdir -p "$MAIL_DIR"

echo "Setting permissions and ownership for $MAIL_DIR"
chown -R $USER:$GROUP "$MAIL_DIR"
chmod 750 "$MAIL_DIR"  # rwxr-x---

mkdir -p "$MAILDIR_STRUCTURE/cur" "$MAILDIR_STRUCTURE/new" "$MAILDIR_STRUCTURE/tmp"

echo "Setting permissions and ownership for the Maildir structure: $MAILDIR_STRUCTURE"
chown -R $USER:$GROUP "$MAILDIR_STRUCTURE"
chmod -R 700 "$MAILDIR_STRUCTURE"

echo "Setting permissions and ownership for all directories under $MAIL_DIR (excluding Maildir)"
find "$MAIL_DIR" -type d ! -path "$MAILDIR_STRUCTURE/*" -exec chown $USER:$GROUP {} \; -exec chmod 750 {} \;
find "$MAIL_DIR" -type f ! -path "$MAILDIR_STRUCTURE/*" -exec chown $USER:$GROUP {} \; -exec chmod 640 {} \;

echo "Adjusting permissions inside Maildir (redundant but safe)"
find "$MAILDIR_STRUCTURE" -type d -exec chmod 700 {} \;
find "$MAILDIR_STRUCTURE" -type f -exec chmod 640 {} \;

# **Nuevo paso para asegurar permisos de ejecución en toda la ruta para el usuario y grupo**
echo "Ensuring +x permissions on all parent directories under $MAIL_DIR"
find "$MAIL_DIR" -type d -exec chmod u+rwx,g+rx,o-rx {} \;

echo "Verification of permissions and ownership:"
ls -ld "$MAIL_DIR"
ls -ld "$MAILDIR_STRUCTURE"
ls -ld "$MAILDIR_STRUCTURE/cur"
ls -ld "$MAILDIR_STRUCTURE/new"
ls -ld "$MAILDIR_STRUCTURE/tmp"

exec dovecot -F
